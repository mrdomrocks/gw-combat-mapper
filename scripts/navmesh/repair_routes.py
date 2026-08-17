#!/usr/bin/env python3
"""Detect and repair route segments that cut through unwalkable terrain.

    python3 -m navmesh.repair_routes analyze
    python3 -m navmesh.repair_routes repair
    python3 -m navmesh.repair_routes export AnvilRock

`analyze` only reports. `repair` rewrites the .au3 route files in place,
inserting the waypoints needed to walk around blocked terrain. Repair is
idempotent: previously generated waypoints (marked `; auto`) are discarded and
recomputed on every run.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass, field
from pathlib import Path

from .navmesh import NavMesh
from .pathfind import (
    DEFAULT_CLEARANCE,
    DEFAULT_MAX_SEGMENT_LENGTH,
    MIN_SPACING,
    Detour,
    NoPathError,
    find_detour,
    smooth_path,
)
from .pmap import DEFAULT_VISUALIZER_DIR, MapIndex, PmapError
from .routes import RoutePoint, discover_routes, parse_route, write_route

ROOT = Path(__file__).resolve().parents[2]
ROUTES_DIR = ROOT / "lib/maps/Routes"

# Route title -> in-game map id, mirroring scripts/merge_caravan_routes.py.
ROUTE_MAP_IDS: dict[str, int] = {
    "NorthKrytaProvince": 58,
    "ScoundrelsRise": 54,
    "GriffonsMouth": 27,
    "DeldrimorBowl": 100,
    "AnvilRock": 89,
    "IronHorseMine": 88,
    "TravelersVale": 99,
    "AscalonFoothills": 103,
    "DiessaLowlands": 13,
    "FlameTempleCorridor": 106,
    "DragonsGullet": 105,
    "TheBreach": 102,
    "OldAscalon": 33,
    "RegentValley": 101,
    "PockmarkFlats": 104,
    "EasternFrontier": 107,
}

# How far an off-mesh waypoint may be nudged before we give up and leave it.
MAX_SNAP_DISTANCE = 600.0


def _apply_smoothing(
    rebuilt: list[RoutePoint],
    mesh: NavMesh,
    clearance: float,
    min_spacing: float,
    max_segment_length: float,
) -> tuple[list[RoutePoint], int]:
    smoothed_points, smoothed_count = smooth_path(
        mesh,
        [e.point for e in rebuilt],
        clearance=clearance,
        min_spacing=min_spacing,
        max_segment_length=max_segment_length,
    )
    if smoothed_count == 0:
        return rebuilt, 0

    hand_entries = [e for e in rebuilt if not e.generated]
    hand_idx = 0
    smoothed_entries: list[RoutePoint] = []
    for x, y in smoothed_points:
        point = (x, y)
        if hand_idx < len(hand_entries) and hand_entries[hand_idx].point == point:
            smoothed_entries.append(hand_entries[hand_idx])
            hand_idx += 1
        else:
            smoothed_entries.append(RoutePoint(x=x, y=y, generated=True))
    if hand_idx != len(hand_entries):
        raise RuntimeError("smoothing dropped or reordered original waypoints")
    return smoothed_entries, smoothed_count


@dataclass(slots=True)
class RouteReport:
    title: str
    map_id: int
    waypoints_before: int
    waypoints_after: int = 0
    blocked_before: int = 0
    blocked_after: int = 0
    inserted: int = 0
    smoothed: int = 0
    snapped: int = 0
    malformed_fixed: int = 0
    count_fixed: bool = False
    unreachable: list[tuple[int, str]] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return self.blocked_after == 0


def _load_mesh(index: MapIndex, map_id: int, min_portal_width: float) -> NavMesh:
    return NavMesh(index.load(map_id), min_portal_width=min_portal_width)


def _snap_off_mesh(mesh: NavMesh, entries: list[RoutePoint]) -> int:
    snapped = 0
    for entry in entries:
        if mesh.is_walkable(entry.x, entry.y):
            continue
        nearest = mesh.nearest_walkable(entry.x, entry.y, MAX_SNAP_DISTANCE)
        if nearest is None:
            continue
        entry.x, entry.y = nearest
        entry.raw = None
        snapped += 1
    return snapped


def process_route(
    path: Path,
    index: MapIndex,
    clearance: float,
    min_spacing: float,
    min_portal_width: float,
    apply_changes: bool,
    smooth: bool = True,
    max_segment_length: float = DEFAULT_MAX_SEGMENT_LENGTH,
) -> RouteReport | None:
    route = parse_route(path)
    if route is None:
        return None

    map_id = ROUTE_MAP_IDS.get(route.title)
    if map_id is None:
        entry = index.entry_for_name(route.title)
        if entry is None:
            print(f"  {route.title}: no map id known, skipped", file=sys.stderr)
            return None
        map_id = entry.map_id

    mesh = _load_mesh(index, map_id, min_portal_width)

    entries = route.original_entries
    report = RouteReport(
        title=route.title,
        map_id=map_id,
        waypoints_before=len(route.entries),
        malformed_fixed=route.malformed_count,
        count_fixed=route.declared_count != len(route.entries),
    )

    report.snapped = _snap_off_mesh(mesh, entries)

    points = [e.point for e in entries]
    report.blocked_before = len(mesh.blocked_segments(points))

    rebuilt: list[RoutePoint] = []
    for i, entry in enumerate(entries):
        rebuilt.append(entry)
        if i == len(entries) - 1:
            break
        nxt = entries[i + 1]
        if mesh.segment_is_walkable(entry.point, nxt.point):
            continue
        try:
            detour: Detour = find_detour(
                mesh, entry.point, nxt.point, clearance=clearance, min_spacing=min_spacing
            )
        except NoPathError as exc:
            report.unreachable.append((i, str(exc)))
            continue
        for x, y in detour.inserted:
            rebuilt.append(RoutePoint(x=x, y=y, generated=True))
            report.inserted += 1

    if smooth and len(rebuilt) >= 2:
        rebuilt, report.smoothed = _apply_smoothing(
            rebuilt,
            mesh,
            clearance=clearance,
            min_spacing=min_spacing,
            max_segment_length=max_segment_length,
        )

    report.waypoints_after = len(rebuilt)
    report.blocked_after = len(mesh.blocked_segments([e.point for e in rebuilt]))

    original_kept = [e.point for e in rebuilt if not e.generated]
    expected = [e.point for e in entries]
    if original_kept != expected:
        raise RuntimeError(f"{route.title}: original waypoints were altered or reordered")

    if apply_changes:
        write_route(route, rebuilt)

    return report


def _print_table(reports: list[RouteReport]) -> None:
    header = (
        f"{'route':<22}{'map':>5}{'waypoints':>18}{'blocked':>16}"
        f"{'added':>7}{'smooth':>8}{'snapped':>9}{'unreachable':>13}"
    )
    print(header)
    print("-" * len(header))
    for r in reports:
        waypoints = f"{r.waypoints_before} -> {r.waypoints_after}"
        blocked = f"{r.blocked_before} -> {r.blocked_after}"
        print(
            f"{r.title:<22}{r.map_id:>5}{waypoints:>18}{blocked:>16}"
            f"{r.inserted:>7}{r.smoothed:>8}{r.snapped:>9}{len(r.unreachable):>13}"
        )
    print("-" * len(header))
    waypoints = (
        f"{sum(r.waypoints_before for r in reports)} -> "
        f"{sum(r.waypoints_after for r in reports)}"
    )
    blocked = (
        f"{sum(r.blocked_before for r in reports)} -> "
        f"{sum(r.blocked_after for r in reports)}"
    )
    print(
        f"{'TOTAL':<22}{'':>5}{waypoints:>18}{blocked:>16}"
        f"{sum(r.inserted for r in reports):>7}"
        f"{sum(r.smoothed for r in reports):>8}"
        f"{sum(r.snapped for r in reports):>9}"
        f"{sum(len(r.unreachable) for r in reports):>13}"
    )


def _print_notes(reports: list[RouteReport]) -> None:
    for r in reports:
        notes: list[str] = []
        if r.malformed_fixed:
            notes.append(f"{r.malformed_fixed} malformed coordinate(s) repaired")
        if r.count_fixed:
            notes.append("stale _COUNT constant corrected")
        if notes:
            print(f"  {r.title}: {'; '.join(notes)}")
    unreachable = [(r, seg, why) for r in reports for seg, why in r.unreachable]
    if unreachable:
        print()
        print(f"Unreachable segments left untouched ({len(unreachable)}):")
        for r, seg, why in unreachable:
            print(f"  {r.title} segment {seg}: {why}")


def _export(index: MapIndex, title: str, routes_dir: Path) -> int:
    path = routes_dir / f"CaravanAscalon_{title}.au3"
    if not path.is_file():
        print(f"no route file at {path}", file=sys.stderr)
        return 1
    route = parse_route(path)
    if route is None:
        print(f"{path.name} holds no coordinate array", file=sys.stderr)
        return 1
    points = route.points
    print(f"Global Const $afWAYPOINTS = [[{len(points)}], _")
    for i, (x, y) in enumerate(points):
        end = "]" if i == len(points) - 1 else ", _"
        print(f"[{x:.2f}, {y:.2f}]{end}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=("analyze", "repair", "export"))
    parser.add_argument("title", nargs="?", help="route title, for export")
    parser.add_argument("--routes-dir", type=Path, default=ROUTES_DIR)
    parser.add_argument("--visualizer-dir", type=Path, default=DEFAULT_VISUALIZER_DIR)
    parser.add_argument("--clearance", type=float, default=DEFAULT_CLEARANCE)
    parser.add_argument("--min-spacing", type=float, default=MIN_SPACING)
    parser.add_argument("--min-portal-width", type=float, default=16.0)
    parser.add_argument("--max-segment-length", type=float, default=DEFAULT_MAX_SEGMENT_LENGTH)
    parser.add_argument("--no-smooth", action="store_true", help="skip pass-2 clearance/length smoothing")
    parser.add_argument("--only", action="append", help="limit to these route titles")
    args = parser.parse_args(argv)

    try:
        index = MapIndex(args.visualizer_dir)
    except PmapError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if args.command == "export":
        if not args.title:
            print("export needs a route title", file=sys.stderr)
            return 2
        return _export(index, args.title, args.routes_dir)

    apply_changes = args.command == "repair"
    reports: list[RouteReport] = []
    for path in discover_routes(args.routes_dir):
        title = path.stem.replace("CaravanAscalon_", "")
        if args.only and title not in args.only:
            continue
        try:
            report = process_route(
                path,
                index,
                clearance=args.clearance,
                min_spacing=args.min_spacing,
                min_portal_width=args.min_portal_width,
                apply_changes=apply_changes,
                smooth=not args.no_smooth,
                max_segment_length=args.max_segment_length,
            )
        except (PmapError, RuntimeError) as exc:
            print(f"error: {path.name}: {exc}", file=sys.stderr)
            return 2
        if report is not None:
            reports.append(report)

    if not reports:
        print("no route files matched", file=sys.stderr)
        return 2

    _print_table(reports)
    print()
    _print_notes(reports)

    remaining = sum(r.blocked_after for r in reports)
    print()
    if apply_changes:
        print(f"Rewrote {len(reports)} route files.")
    print(
        f"Blocked segments: {sum(r.blocked_before for r in reports)} before, "
        f"{remaining} after."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
