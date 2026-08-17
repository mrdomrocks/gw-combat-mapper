#!/usr/bin/env python3
"""Navigation mesh built from .pmap trapezoids.

Trapezoids are horizontal slabs. Two of them are adjacent when one's top edge
sits at the same height as the other's bottom edge, they share the same plane,
and their x ranges overlap. That shared overlap is the "portal" the funnel
algorithm later strings a path through.
"""

from __future__ import annotations

import math
from collections import defaultdict
from dataclasses import dataclass
from typing import Iterable, Iterator, Sequence

from .pmap import PathingMap, Trapezoid

# The shipped geometry is grid aligned, so edges match exactly; a small epsilon
# only guards against float round-tripping.
EDGE_EPSILON = 0.05

# A portal narrower than this is treated as a degenerate corner touch rather
# than a real opening. Raising it fragments the mesh, lowering it admits gaps a
# character cannot physically squeeze through.
MIN_PORTAL_WIDTH = 16.0

# Distance between samples when testing whether a straight segment stays walkable.
SAMPLE_STEP = 100.0

# Tolerance when testing containment. Recorded waypoints sometimes land exactly
# on a trapezoid edge, where an exact comparison reports "off the mesh". One
# game unit is far below anything that matters for movement.
LOCATE_EPSILON = 1.0

Point = tuple[float, float]


@dataclass(frozen=True, slots=True)
class Portal:
    """The shared horizontal opening between two adjacent trapezoids."""

    left: float
    right: float
    y: float

    @property
    def width(self) -> float:
        return self.right - self.left

    @property
    def midpoint(self) -> Point:
        return ((self.left + self.right) / 2.0, self.y)

    def inset(self, margin: float) -> tuple[Point, Point]:
        """Portal endpoints pulled `margin` inwards, never crossing the middle."""
        usable = max(0.0, (self.width - 2.0 * margin) / 2.0)
        mid = (self.left + self.right) / 2.0
        return ((mid - usable, self.y), (mid + usable, self.y))


class NavMesh:
    def __init__(
        self,
        pathing_map: PathingMap,
        bucket_size: float = 512.0,
        min_portal_width: float = MIN_PORTAL_WIDTH,
        require_same_plane: bool = True,
    ) -> None:
        self.map = pathing_map
        self.trapezoids: tuple[Trapezoid, ...] = pathing_map.trapezoids
        self._bucket_size = bucket_size
        self._min_portal_width = min_portal_width
        self._require_same_plane = require_same_plane
        self._buckets: dict[int, list[int]] = defaultdict(list)
        self._neighbours: dict[int, list[tuple[int, Portal]]] = defaultdict(list)
        self._component: list[int] = []
        self._build_spatial_index()
        self._build_adjacency()
        self._build_components()

    # -- spatial index ---------------------------------------------------

    def _bucket(self, y: float) -> int:
        return int(math.floor(y / self._bucket_size))

    def _build_spatial_index(self) -> None:
        for t in self.trapezoids:
            lo = self._bucket(t.yb - LOCATE_EPSILON)
            hi = self._bucket(t.yt + LOCATE_EPSILON)
            for b in range(lo, hi + 1):
                self._buckets[b].append(t.index)

    def locate(self, x: float, y: float, plane: int | None = None) -> int:
        """Index of a trapezoid containing the point, or -1."""
        for i in self._buckets.get(self._bucket(y), ()):
            t = self.trapezoids[i]
            if plane is not None and t.plane != plane:
                continue
            if t.contains(x, y, LOCATE_EPSILON):
                return i
        return -1

    def is_walkable(self, x: float, y: float) -> bool:
        return self.locate(x, y) >= 0

    def nearest_walkable(self, x: float, y: float, max_radius: float = 2000.0) -> Point | None:
        """Closest point on the mesh, searched outward in rings."""
        if self.is_walkable(x, y):
            return (x, y)
        best: Point | None = None
        best_d = float("inf")
        for t in self.trapezoids:
            cx, cy = t.centroid
            if abs(cy - y) > max_radius or abs(cx - x) > max_radius:
                continue
            py = min(max(y, t.yb), t.yt)
            left, right = t.x_span_at(py)
            px = min(max(x, left), right)
            d = math.hypot(px - x, py - y)
            if d < best_d:
                best_d, best = d, (px, py)
        return best if best_d <= max_radius else None

    # -- adjacency -------------------------------------------------------

    def _build_adjacency(self) -> None:
        tops: dict[tuple[int, int], list[int]] = defaultdict(list)
        bottoms: dict[tuple[int, int], list[int]] = defaultdict(list)
        quant = 1.0 / EDGE_EPSILON
        for t in self.trapezoids:
            plane = t.plane if self._require_same_plane else 0
            tops[(plane, round(t.yt * quant))].append(t.index)
            bottoms[(plane, round(t.yb * quant))].append(t.index)

        for key, upper in tops.items():
            lower = bottoms.get(key)
            if not lower:
                continue
            _plane, qy = key
            y = qy / quant
            for i in upper:
                a = self.trapezoids[i]
                for j in lower:
                    if i == j:
                        continue
                    b = self.trapezoids[j]
                    left = max(a.xtl, b.xbl)
                    right = min(a.xtr, b.xbr)
                    if right - left < self._min_portal_width:
                        continue
                    portal = Portal(left, right, y)
                    self._neighbours[i].append((j, portal))
                    self._neighbours[j].append((i, portal))

    def neighbours(self, index: int) -> Sequence[tuple[int, Portal]]:
        return self._neighbours.get(index, ())

    def portal_between(self, a: int, b: int) -> Portal | None:
        for j, portal in self._neighbours.get(a, ()):
            if j == b:
                return portal
        return None

    # -- connectivity ----------------------------------------------------

    def _build_components(self) -> None:
        self._component = [-1] * len(self.trapezoids)
        current = 0
        for start in range(len(self.trapezoids)):
            if self._component[start] != -1:
                continue
            stack = [start]
            self._component[start] = current
            while stack:
                u = stack.pop()
                for v, _portal in self._neighbours.get(u, ()):
                    if self._component[v] == -1:
                        self._component[v] = current
                        stack.append(v)
            current += 1
        self.component_count = current

    def component(self, index: int) -> int:
        return self._component[index]

    def connected(self, a: int, b: int) -> bool:
        return a >= 0 and b >= 0 and self._component[a] == self._component[b]

    # -- segment tests ---------------------------------------------------

    def sample_segment(self, p: Point, q: Point, step: float = SAMPLE_STEP) -> Iterator[Point]:
        d = math.dist(p, q)
        n = max(2, int(math.ceil(d / step)))
        for k in range(n + 1):
            t = k / n
            yield (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)

    def segment_is_walkable(self, p: Point, q: Point, step: float = SAMPLE_STEP) -> bool:
        return all(self.is_walkable(x, y) for x, y in self.sample_segment(p, q, step))

    def segment_has_clearance(
        self, p: Point, q: Point, half_width: float, step: float = SAMPLE_STEP
    ) -> bool:
        """Walkable along the centre line and at +/- half_width either side of it.

        Used when shortcutting a corridor so the shortened line keeps its
        distance from walls instead of shaving corners.
        """
        if half_width <= 0.0:
            return self.segment_is_walkable(p, q, step)
        dx, dy = q[0] - p[0], q[1] - p[1]
        length = math.hypot(dx, dy)
        if length == 0.0:
            return self.is_walkable(*p)
        nx, ny = -dy / length * half_width, dx / length * half_width
        for x, y in self.sample_segment(p, q, step):
            if not self.is_walkable(x, y):
                return False
            if not self.is_walkable(x + nx, y + ny):
                return False
            if not self.is_walkable(x - nx, y - ny):
                return False
        return True

    def path_is_walkable(self, points: Sequence[Point], step: float = SAMPLE_STEP) -> bool:
        return all(
            self.segment_is_walkable(points[i], points[i + 1], step)
            for i in range(len(points) - 1)
        )

    def blocked_segments(
        self, points: Sequence[Point], step: float = SAMPLE_STEP
    ) -> list[int]:
        """Indices `i` where the straight line from points[i] to points[i+1] leaves the mesh."""
        return [
            i
            for i in range(len(points) - 1)
            if not self.segment_is_walkable(points[i], points[i + 1], step)
        ]

    def off_mesh(self, points: Iterable[Point]) -> list[int]:
        return [i for i, (x, y) in enumerate(points) if not self.is_walkable(x, y)]

    # -- diagnostics -----------------------------------------------------

    def stats(self) -> dict[str, int]:
        edges = sum(len(v) for v in self._neighbours.values()) // 2
        sizes: dict[int, int] = defaultdict(int)
        for c in self._component:
            sizes[c] += 1
        return {
            "trapezoids": len(self.trapezoids),
            "portals": edges,
            "components": self.component_count,
            "largest_component": max(sizes.values()) if sizes else 0,
        }
