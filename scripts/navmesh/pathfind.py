#!/usr/bin/env python3
"""A* over the trapezoid graph, then string-pulling down to a few waypoints.

Raw A* yields one point per trapezoid, which for a long detour can be a hundred
waypoints. Two things cut that down:

1. The chain of portal midpoints is a guaranteed-walkable baseline. Trapezoids
   are convex, so the straight line between the two portals bounding one is
   always inside it.
2. The funnel ("simple stupid funnel") over inset portals emits a corner only
   where the line genuinely has to bend, and a clearance-aware greedy pass
   shortcuts whatever is left.

Every returned path is re-validated against the mesh before it is handed back,
so a detour is either fully walkable or the call raises.
"""

from __future__ import annotations

import heapq
import math
from dataclasses import dataclass
from typing import Sequence

from .navmesh import NavMesh, Point

# Keep generated waypoints this far from walls. Mirrors the ClearanceWeight
# idea already used in lib/PathRoute.au3.
DEFAULT_CLEARANCE = 60.0

# Extra A* cost applied to narrow portals so wide, safe openings win ties.
NARROW_PORTAL_PENALTY = 12000.0

# Collapse generated waypoints closer together than this, matching
# MapRoute_DedupePath1D's default spacing.
MIN_SPACING = 150.0

# Longest straight hop before runtime PathRoute inserts intermediate anchors.
DEFAULT_MAX_SEGMENT_LENGTH = 1500.0

# Cap recursive midpoint splits when clearance cannot be satisfied otherwise.
MAX_SPLIT_DEPTH = 8


class NoPathError(RuntimeError):
    pass


@dataclass(slots=True)
class Detour:
    """Waypoints to splice strictly between the start and goal of a segment."""

    inserted: list[Point]
    corridor_length: int


def _corridor(mesh: NavMesh, start: int, goal: int) -> list[int]:
    """A* over trapezoids, biased towards wide portals."""
    if start == goal:
        return [start]
    if not mesh.connected(start, goal):
        raise NoPathError("start and goal are in different mesh components")

    goal_centre = mesh.trapezoids[goal].centroid

    def heuristic(i: int) -> float:
        return math.dist(mesh.trapezoids[i].centroid, goal_centre)

    came: dict[int, int | None] = {}
    best = {start: 0.0}
    heap: list[tuple[float, float, int, int | None]] = [(heuristic(start), 0.0, start, None)]

    while heap:
        _f, g, node, parent = heapq.heappop(heap)
        if node in came:
            continue
        came[node] = parent
        if node == goal:
            break
        node_centre = mesh.trapezoids[node].centroid
        for nxt, portal in mesh.neighbours(node):
            if nxt in came:
                continue
            step = math.dist(node_centre, mesh.trapezoids[nxt].centroid)
            step += NARROW_PORTAL_PENALTY / max(portal.width, 1.0)
            cost = g + step
            if cost < best.get(nxt, math.inf):
                best[nxt] = cost
                heapq.heappush(heap, (cost + heuristic(nxt), cost, nxt, node))

    if goal not in came:
        raise NoPathError("no corridor between start and goal")

    path: list[int] = []
    cursor: int | None = goal
    while cursor is not None:
        path.append(cursor)
        cursor = came[cursor]
    path.reverse()
    return path


def _oriented_portals(
    mesh: NavMesh, corridor: Sequence[int], clearance: float
) -> list[tuple[Point, Point]]:
    """Portal endpoints ordered (left, right) relative to the travel direction."""
    portals: list[tuple[Point, Point]] = []
    for a, b in zip(corridor, corridor[1:]):
        portal = mesh.portal_between(a, b)
        if portal is None:
            raise NoPathError(f"missing portal between trapezoids {a} and {b}")
        p, q = portal.inset(clearance)
        ax, ay = mesh.trapezoids[a].centroid
        bx, by = mesh.trapezoids[b].centroid
        mx, my = portal.midpoint
        cross = (bx - ax) * (p[1] - my) - (by - ay) * (p[0] - mx)
        portals.append((p, q) if cross > 0 else (q, p))
    return portals


def _portal_midpoints(mesh: NavMesh, corridor: Sequence[int]) -> list[Point]:
    points: list[Point] = []
    for a, b in zip(corridor, corridor[1:]):
        portal = mesh.portal_between(a, b)
        if portal is None:
            raise NoPathError(f"missing portal between trapezoids {a} and {b}")
        points.append(portal.midpoint)
    return points


def _triarea2(a: Point, b: Point, c: Point) -> float:
    return (b[0] - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (b[1] - a[1])


def _funnel(start: Point, goal: Point, portals: Sequence[tuple[Point, Point]]) -> list[Point]:
    """Simple stupid funnel. Returns the corners between start and goal, plus goal."""
    gates = list(portals) + [(goal, goal)]
    out: list[Point] = []

    apex = left = right = start
    apex_i = left_i = right_i = 0
    i = 0
    guard = 0
    limit = 8 * len(gates) + 32

    while i < len(gates):
        guard += 1
        if guard > limit:
            raise NoPathError("funnel failed to converge")
        gate_left, gate_right = gates[i]

        if _triarea2(apex, right, gate_right) <= 0.0:
            if apex == right or _triarea2(apex, left, gate_right) > 0.0:
                right, right_i = gate_right, i
            else:
                out.append(left)
                apex, apex_i = left, left_i
                left = right = apex
                left_i = right_i = apex_i
                i = apex_i + 1
                continue

        if _triarea2(apex, left, gate_left) >= 0.0:
            if apex == left or _triarea2(apex, right, gate_left) < 0.0:
                left, left_i = gate_left, i
            else:
                out.append(right)
                apex, apex_i = right, right_i
                left = right = apex
                left_i = right_i = apex_i
                i = apex_i + 1
                continue

        i += 1

    if not out or out[-1] != goal:
        out.append(goal)
    return out


def _shortcut(
    mesh: NavMesh, points: Sequence[Point], clearance: float
) -> list[Point]:
    """Greedy line-of-sight pass keeping `clearance` from walls.

    Scans from the far end so long shortcuts win, which keeps the waypoint count
    low without ever emitting a segment the bot cannot walk.
    """
    if len(points) <= 2:
        return list(points)
    out = [points[0]]
    i = 0
    while i < len(points) - 1:
        best = i + 1
        for j in range(len(points) - 1, i + 1, -1):
            if mesh.segment_has_clearance(points[i], points[j], clearance):
                best = j
                break
        out.append(points[best])
        i = best
    return out


def _dedupe(points: Sequence[Point], min_spacing: float) -> list[Point]:
    out: list[Point] = []
    for p in points:
        if not out or math.dist(out[-1], p) >= min_spacing:
            out.append(p)
    return out


def _path_has_clearance(mesh: NavMesh, points: Sequence[Point], clearance: float) -> bool:
    return all(
        mesh.segment_has_clearance(points[i], points[i + 1], clearance)
        for i in range(len(points) - 1)
    )


def _split_for_clearance(
    mesh: NavMesh,
    start: Point,
    goal: Point,
    clearance: float,
    depth: int = 0,
) -> list[Point]:
    """Bisect a segment until every sub-segment keeps wall clearance."""
    if mesh.segment_has_clearance(start, goal, clearance):
        return []
    if depth >= MAX_SPLIT_DEPTH:
        return []

    mid = ((start[0] + goal[0]) / 2.0, (start[1] + goal[1]) / 2.0)
    snapped = mesh.nearest_walkable(mid[0], mid[1], max(math.dist(start, goal), 600.0))
    if snapped is None:
        return []
    if math.dist(snapped, start) < 1.0 or math.dist(snapped, goal) < 1.0:
        return []

    left = _split_for_clearance(mesh, start, snapped, clearance, depth + 1)
    right = _split_for_clearance(mesh, snapped, goal, clearance, depth + 1)
    return left + [snapped] + right


def _interpolate_long_segment(
    mesh: NavMesh,
    start: Point,
    goal: Point,
    max_segment_length: float,
    min_spacing: float,
) -> list[Point]:
    """Evenly spaced anchors along a clearance-safe segment that exceeds the hop limit."""
    dist = math.dist(start, goal)
    count = int(math.floor(dist / max_segment_length))
    if count < 1:
        return []

    inserted: list[Point] = []
    for k in range(1, count + 1):
        t = k / (count + 1)
        x = start[0] + (goal[0] - start[0]) * t
        y = start[1] + (goal[1] - start[1]) * t
        snapped = mesh.nearest_walkable(x, y, max_segment_length)
        if snapped is None:
            continue
        if inserted and math.dist(inserted[-1], snapped) < min_spacing:
            continue
        if math.dist(snapped, start) < min_spacing or math.dist(snapped, goal) < min_spacing:
            continue
        inserted.append(snapped)
    return inserted


def _expand_long_segments(
    mesh: NavMesh,
    path: Sequence[Point],
    max_segment_length: float,
    min_spacing: float,
) -> list[Point]:
    """Split any sub-segment longer than `max_segment_length` with interior anchors."""
    if len(path) < 2:
        return list(path)

    out: list[Point] = [path[0]]
    for i in range(len(path) - 1):
        start, goal = path[i], path[i + 1]
        for x, y in _interpolate_long_segment(mesh, start, goal, max_segment_length, min_spacing):
            out.append((x, y))
        out.append(goal)
    return out


def smooth_segment(
    mesh: NavMesh,
    start: Point,
    goal: Point,
    clearance: float = DEFAULT_CLEARANCE,
    min_spacing: float = MIN_SPACING,
    max_segment_length: float = DEFAULT_MAX_SEGMENT_LENGTH,
) -> list[Point]:
    """Interior anchors to keep a segment off walls and within hop distance."""
    dist = math.dist(start, goal)
    has_clearance = mesh.segment_has_clearance(start, goal, clearance)
    if has_clearance and dist <= max_segment_length:
        return []

    if not mesh.segment_is_walkable(start, goal):
        try:
            return find_detour(mesh, start, goal, clearance=clearance, min_spacing=min_spacing).inserted
        except NoPathError:
            return []

    interior: list[Point] = []
    if not has_clearance:
        try:
            detour = find_detour(mesh, start, goal, clearance=clearance, min_spacing=min_spacing)
            candidate_path = [start] + detour.inserted + [goal]
            if _path_has_clearance(mesh, candidate_path, clearance):
                interior = detour.inserted
            else:
                interior = _split_for_clearance(mesh, start, goal, clearance)
        except NoPathError:
            interior = _split_for_clearance(mesh, start, goal, clearance)

    path = _expand_long_segments(
        mesh, [start] + interior + [goal], max_segment_length, min_spacing
    )
    thinned = _dedupe(path[1:-1], min_spacing)
    thinned = [
        p
        for p in thinned
        if math.dist(p, start) >= min_spacing and math.dist(p, goal) >= min_spacing
    ]
    if not thinned:
        return []
    if not mesh.path_is_walkable([start] + thinned + [goal]):
        return interior
    return thinned


def smooth_path(
    mesh: NavMesh,
    points: Sequence[Point],
    clearance: float = DEFAULT_CLEARANCE,
    min_spacing: float = MIN_SPACING,
    max_segment_length: float = DEFAULT_MAX_SEGMENT_LENGTH,
) -> tuple[list[Point], int]:
    """Return a smoothed copy of `points` and the number of anchors inserted."""
    if len(points) < 2:
        return list(points), 0

    rebuilt: list[Point] = [points[0]]
    inserted = 0
    for i in range(len(points) - 1):
        start, goal = points[i], points[i + 1]
        anchors = smooth_segment(
            mesh,
            start,
            goal,
            clearance=clearance,
            min_spacing=min_spacing,
            max_segment_length=max_segment_length,
        )
        for anchor in anchors:
            rebuilt.append(anchor)
            inserted += 1
        rebuilt.append(goal)
    return rebuilt, inserted


def find_detour(
    mesh: NavMesh,
    start: Point,
    goal: Point,
    clearance: float = DEFAULT_CLEARANCE,
    min_spacing: float = MIN_SPACING,
) -> Detour:
    """Waypoints to insert between `start` and `goal` so the walk stays on the mesh.

    Raises NoPathError when the two ends are not connected on the mesh, or when
    no fully walkable detour could be produced.
    """
    a = mesh.locate(*start)
    b = mesh.locate(*goal)
    if a < 0:
        raise NoPathError(f"start {start} is off the mesh")
    if b < 0:
        raise NoPathError(f"goal {goal} is off the mesh")

    corridor = _corridor(mesh, a, b)
    if len(corridor) < 2:
        return Detour([], len(corridor))

    baseline = [start] + _portal_midpoints(mesh, corridor) + [goal]
    if not mesh.path_is_walkable(baseline):
        raise NoPathError("corridor baseline is not walkable")

    def funnelled() -> list[Point]:
        return [start] + _funnel(start, goal, _oriented_portals(mesh, corridor, clearance))

    # Ordered cheapest-and-fewest-waypoints first; each is validated before use.
    candidates = (
        funnelled,
        lambda: _shortcut(mesh, baseline, clearance),
        lambda: _shortcut(mesh, baseline, 0.0),
        lambda: baseline,
    )

    best: list[Point] | None = None
    best_with_clearance: list[Point] | None = None
    for build in candidates:
        try:
            path = build()
        except NoPathError:
            continue
        if path[0] != start:
            path = [start] + path
        if path[-1] != goal:
            path = path + [goal]
        if not mesh.path_is_walkable(path):
            continue

        interior = path[1:-1]
        thinned = _dedupe(interior, min_spacing)
        thinned = [
            p
            for p in thinned
            if math.dist(p, start) >= min_spacing and math.dist(p, goal) >= min_spacing
        ]
        # Prefer the sparser waypoint set, but never drop so many that the walk
        # stops working; short detours around a small obstacle need every point.
        for inserted in (thinned, interior):
            if not inserted:
                continue
            candidate_path = [start] + inserted + [goal]
            if not mesh.path_is_walkable(candidate_path):
                continue
            if _path_has_clearance(mesh, candidate_path, clearance):
                if best_with_clearance is None or len(inserted) < len(best_with_clearance):
                    best_with_clearance = inserted
            elif best is None or len(inserted) < len(best):
                best = inserted
            break
        # A one- or two-point detour is already as short as it can usefully get;
        # the remaining candidates only cost time.
        chosen = best_with_clearance or best
        if chosen is not None and len(chosen) <= 2:
            break

    if best_with_clearance is not None:
        return Detour(best_with_clearance, len(corridor))
    if best is None:
        raise NoPathError("could not produce a fully walkable detour")
    return Detour(best, len(corridor))
