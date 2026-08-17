#!/usr/bin/env python3
"""Repair vanquish routes for every map, across all four campaigns.

    python3 -m navmesh.repair_vanquish analyze
    python3 -m navmesh.repair_vanquish repair
    python3 -m navmesh.repair_vanquish repair --campaign Proph_Kryta

`analyze` only reports. `repair` writes tracked, array-only route files to
lib/maps/Vanquish/<Campaign>/<Map>.au3, leaving the gitignored vendor tree
untouched. Output is regenerated from the vendor source every run, so repeated
runs are idempotent.
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

from .locations import DEFAULT_LOCATIONS, LocationIndex
from .navmesh import NavMesh
from .pathfind import (
    DEFAULT_CLEARANCE,
    DEFAULT_MAX_SEGMENT_LENGTH,
    MIN_SPACING,
    NoPathError,
    find_detour,
    smooth_path,
)
from .pmap import DEFAULT_VISUALIZER_DIR, MapIndex, PmapError
from .routes import RoutePoint
from .vanquish import (
    OUTPUT_DIR,
    VENDOR_MAPS,
    RouteArray,
    VanquishSource,
    discover,
    parse_source,
    render,
)

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
class MapReport:
    campaign: str
    map_name: str
    map_id: int
    arrays: int = 0
    waypoints_before: int = 0
    waypoints_after: int = 0
    blocked_before: int = 0
    blocked_after: int = 0
    inserted: int = 0
    smoothed: int = 0
    snapped: int = 0
    malformed: int = 0
    unreachable: Counter = field(default_factory=Counter)


@dataclass(slots=True)
class SkipReport:
    name: str
    reason: str


def _repair_array(
    mesh: NavMesh,
    array: RouteArray,
    clearance: float,
    min_spacing: float,
    report: MapReport,
    smooth: bool = True,
    max_segment_length: float = DEFAULT_MAX_SEGMENT_LENGTH,
) -> RouteArray:
    entries = [e for e in array.entries if not e.generated]

    for entry in entries:
        if mesh.is_walkable(entry.x, entry.y):
            continue
        nearest = mesh.nearest_walkable(entry.x, entry.y, MAX_SNAP_DISTANCE)
        if nearest is None:
            continue
        entry.x, entry.y = nearest
        entry.raw = None
        report.snapped += 1

    report.blocked_before += len(mesh.blocked_segments([e.point for e in entries]))

    rebuilt: list[RoutePoint] = []
    for i, entry in enumerate(entries):
        rebuilt.append(entry)
        if i == len(entries) - 1:
            break
        nxt = entries[i + 1]
        if mesh.segment_is_walkable(entry.point, nxt.point):
            continue
        try:
            detour = find_detour(
                mesh, entry.point, nxt.point, clearance=clearance, min_spacing=min_spacing
            )
        except NoPathError as exc:
            text = str(exc)
            if "different mesh components" in text:
                report.unreachable["disconnected"] += 1
            elif "off the mesh" in text:
                report.unreachable["off-mesh"] += 1
            else:
                report.unreachable["other"] += 1
            continue
        for x, y in detour.inserted:
            rebuilt.append(RoutePoint(x=x, y=y, generated=True))
            report.inserted += 1

    if smooth and len(rebuilt) >= 2:
        rebuilt, smoothed_count = _apply_smoothing(
            rebuilt,
            mesh,
            clearance=clearance,
            min_spacing=min_spacing,
            max_segment_length=max_segment_length,
        )
        report.smoothed += smoothed_count

    kept = [e.point for e in rebuilt if not e.generated]
    if kept != [e.point for e in entries]:
        raise RuntimeError(f"{array.name}: original waypoints were altered or reordered")

    report.blocked_after += len(mesh.blocked_segments([e.point for e in rebuilt]))
    return RouteArray(name=array.name, entries=rebuilt, malformed=array.malformed)


def process(
    source: VanquishSource,
    locations: LocationIndex,
    maps: MapIndex,
    clearance: float,
    min_spacing: float,
    apply_changes: bool,
    smooth: bool = True,
    max_segment_length: float = DEFAULT_MAX_SEGMENT_LENGTH,
) -> MapReport | SkipReport:
    label = f"{source.campaign}/{source.map_name}"
    if not source.arrays:
        return SkipReport(label, "no Route array")

    map_id = locations.map_id(source.map_name)
    if map_id is None:
        return SkipReport(label, "name not in LocationsIDS.au3")

    entry = maps.entry_for_map_id(map_id)
    if entry is None or not maps.pmap_path(entry).is_file():
        return SkipReport(label, f"no pmap shipped for map id {map_id}")

    mesh = NavMesh(maps.load(map_id))
    report = MapReport(
        campaign=source.campaign,
        map_name=source.map_name,
        map_id=map_id,
        arrays=len(source.arrays),
        malformed=sum(a.malformed for a in source.arrays),
    )

    repaired: list[RouteArray] = []
    for array in source.arrays:
        report.waypoints_before += len([e for e in array.entries if not e.generated])
        fixed = _repair_array(
            mesh,
            array,
            clearance,
            min_spacing,
            report,
            smooth=smooth,
            max_segment_length=max_segment_length,
        )
        report.waypoints_after += len(fixed.entries)
        repaired.append(fixed)

    if apply_changes:
        notes = [
            f"Repaired {report.blocked_before - report.blocked_after} of "
            f"{report.blocked_before} blocked segments by inserting {report.inserted} waypoints."
        ]
        if report.smoothed:
            notes.append(
                f"Smoothed {report.smoothed} additional anchor(s) for wall clearance and hop distance."
            )
        if report.blocked_after:
            notes.append(
                f"{report.blocked_after} segment(s) could not be routed and were left as-is."
            )
        if report.snapped:
            notes.append(f"{report.snapped} off-mesh waypoint(s) snapped onto walkable ground.")
        if report.malformed:
            notes.append(f"{report.malformed} malformed coordinate(s) repaired.")
        out = source.output_path
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(
            render(source, repaired, map_id, maps.pmap_path(entry).name, notes), encoding="utf-8"
        )

    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("command", choices=("analyze", "repair"))
    parser.add_argument("--vendor-dir", type=Path, default=VENDOR_MAPS)
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    parser.add_argument("--locations", type=Path, default=DEFAULT_LOCATIONS)
    parser.add_argument("--visualizer-dir", type=Path, default=DEFAULT_VISUALIZER_DIR)
    parser.add_argument("--clearance", type=float, default=DEFAULT_CLEARANCE)
    parser.add_argument("--min-spacing", type=float, default=MIN_SPACING)
    parser.add_argument("--max-segment-length", type=float, default=DEFAULT_MAX_SEGMENT_LENGTH)
    parser.add_argument("--no-smooth", action="store_true", help="skip pass-2 clearance/length smoothing")
    parser.add_argument("--campaign", action="append", help="limit to these campaign folders")
    parser.add_argument("--verbose", action="store_true", help="list every map, not just totals")
    args = parser.parse_args(argv)

    if not args.vendor_dir.is_dir():
        print(f"error: vendor maps not found at {args.vendor_dir}", file=sys.stderr)
        return 2
    try:
        maps = MapIndex(args.visualizer_dir)
        locations = LocationIndex(args.locations)
    except (PmapError, OSError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    apply_changes = args.command == "repair"
    reports: list[MapReport] = []
    skips: list[SkipReport] = []

    for path in discover(args.vendor_dir):
        if args.campaign and path.parent.name not in args.campaign:
            continue
        source = parse_source(path)
        result = process(
            source,
            locations,
            maps,
            args.clearance,
            args.min_spacing,
            apply_changes,
            smooth=not args.no_smooth,
            max_segment_length=args.max_segment_length,
        )
        if isinstance(result, SkipReport):
            skips.append(result)
        else:
            reports.append(result)

    if not reports:
        print("no maps processed", file=sys.stderr)
        return 2

    by_campaign: dict[str, list[MapReport]] = {}
    for r in reports:
        by_campaign.setdefault(r.campaign, []).append(r)

    header = (
        f"{'campaign':<28}{'maps':>6}{'routes':>8}{'waypoints':>18}{'blocked':>16}"
        f"{'added':>8}{'smooth':>8}"
    )
    print(header)
    print("-" * len(header))
    for campaign in sorted(by_campaign):
        group = by_campaign[campaign]
        wp = f"{sum(r.waypoints_before for r in group)} -> {sum(r.waypoints_after for r in group)}"
        bl = f"{sum(r.blocked_before for r in group)} -> {sum(r.blocked_after for r in group)}"
        print(
            f"{campaign:<28}{len(group):>6}{sum(r.arrays for r in group):>8}"
            f"{wp:>18}{bl:>16}{sum(r.inserted for r in group):>8}"
            f"{sum(r.smoothed for r in group):>8}"
        )
    print("-" * len(header))
    wp = f"{sum(r.waypoints_before for r in reports)} -> {sum(r.waypoints_after for r in reports)}"
    bl = f"{sum(r.blocked_before for r in reports)} -> {sum(r.blocked_after for r in reports)}"
    print(
        f"{'TOTAL':<28}{len(reports):>6}{sum(r.arrays for r in reports):>8}"
        f"{wp:>18}{bl:>16}{sum(r.inserted for r in reports):>8}"
        f"{sum(r.smoothed for r in reports):>8}"
    )

    if args.verbose:
        print()
        for r in sorted(reports, key=lambda r: -r.blocked_before):
            print(
                f"  {r.campaign}/{r.map_name} (map {r.map_id}): "
                f"{r.waypoints_before} -> {r.waypoints_after} wp, "
                f"blocked {r.blocked_before} -> {r.blocked_after}, "
                f"+{r.inserted} detour, +{r.smoothed} smooth"
            )

    total_unreachable: Counter = Counter()
    for r in reports:
        total_unreachable.update(r.unreachable)
    snapped = sum(r.snapped for r in reports)
    smoothed = sum(r.smoothed for r in reports)
    malformed = sum(r.malformed for r in reports)

    print()
    if total_unreachable:
        detail = ", ".join(f"{v} {k}" for k, v in total_unreachable.most_common())
        print(f"Segments left unrouted: {sum(total_unreachable.values())} ({detail})")
    if smoothed:
        print(f"Additional smoothing anchors inserted: {smoothed}")
    if snapped:
        print(f"Off-mesh waypoints snapped onto walkable ground: {snapped}")
    if malformed:
        print(f"Malformed coordinates repaired: {malformed}")

    if skips:
        print()
        print(f"Skipped {len(skips)} files:")
        grouped: dict[str, list[str]] = {}
        for s in skips:
            grouped.setdefault(s.reason, []).append(s.name)
        for reason, names in sorted(grouped.items()):
            shown = ", ".join(sorted(names)[:4])
            more = f" (+{len(names) - 4} more)" if len(names) > 4 else ""
            print(f"  {reason}: {len(names)} -- {shown}{more}")

    if apply_changes:
        print()
        print(f"Wrote {len(reports)} route files under {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
