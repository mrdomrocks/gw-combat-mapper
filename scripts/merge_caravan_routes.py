#!/usr/bin/env python3
"""Merge vanquish-bot Route01 + manual CSV coords + GoOut portal tail into CaravanAscalon route files."""

from __future__ import annotations

import csv
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROUTES_DIR = ROOT / "lib/maps/Routes"
VANQUISH_DIR = ROOT / "vendor/vanquish-bot/Maps"
GOOUT = ROOT / "lib/maps/GoOutRoutes.au3"
LOGS = ROOT / "logs"
MIN_SPACING = 150

ROUTES = [
    ("NorthKrytaProvince", 58, "Proph_Kryta/NorthKrytaProvince.au3", "aNorthKrytaToScoundrelsRisePortalPath"),
    ("ScoundrelsRise", 54, "Proph_Kryta/ScoundrelsRise.au3", "aScoundrelsRiseToGriffonsMouthPortalPath"),
    ("GriffonsMouth", 27, "Proph_NorthernShiverpeaks/GriffonsMouth.au3", "aGriffonsMouthToDeldrimorBowlPortalPath"),
    ("DeldrimorBowl", 100, "Proph_NorthernShiverpeaks/DeldrimorBowl.au3", "aDeldrimorBowlToAnvilRockPortalPath"),
    ("AnvilRock", 89, "Proph_NorthernShiverpeaks/AnvilRock.au3", "aAnvilRockToIronHorseMinePortalPath"),
    ("IronHorseMine", 88, "Proph_NorthernShiverpeaks/IronHorseMine.au3", "aIronHorseMineToTravelersValePortalPath"),
    ("TravelersVale", 99, "Proph_NorthernShiverpeaks/TravelersVale.au3", "aTravelersValeToAscalonFoothillsPortalPath"),
    ("AscalonFoothills", 103, "Proph_Ascalon/AscalonFoothills.au3", "aAscalonFoothillsToDiessaLowlandsPortalPath"),
    ("DiessaLowlands", 13, "Proph_Ascalon/DiessaLowlands.au3", "aDiessaLowlandsToFlameTempleCorridorPortalPath"),
    ("FlameTempleCorridor", 106, "Proph_Ascalon/FlameTempleCorridor.au3", "aFlameTempleCorridorToDragonsGulletPortalPath"),
    ("DragonsGullet", 105, "Proph_Ascalon/DragonsGullet.au3", None),
    ("TheBreach", 102, "Proph_Ascalon/TheBreach.au3", "aTheBreachToOldAscalonPortalPath"),
    ("OldAscalon", 33, "Proph_Ascalon/OldAscalon.au3", "aOldAscalonToRegentValleyPortalPath"),
    ("RegentValley", 101, "Proph_Ascalon/RegentValley.au3", "aRegentValleyToPockmarkFlatsPortalPath"),
    ("PockmarkFlats", 104, "Proph_Ascalon/PockmarkFlats.au3", "aPockmarkFlatsToEasternFrontierPortalPath"),
    ("EasternFrontier", 107, "Proph_Ascalon/EasternFrontier.au3", None),
]

SKIP = {"DiessaLowlands", "NorthKrytaProvince", "FlameTempleCorridor", "DragonsGullet"}  # hand-tuned / combined routes


def dist(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def parse_coord_array(text: str, array_name: str) -> list[tuple[float, float]]:
    pattern = rf"Global\s+\${re.escape(array_name)}(?:\[[^\]]*\])*\s*=\s*\[\s*_(.*?)\n\]"
    m = re.search(pattern, text, re.DOTALL)
    if not m:
        raise ValueError(f"Array {array_name} not found")
    body = m.group(1)
    pts: list[tuple[float, float]] = []
    for line in body.splitlines():
        line = line.strip().rstrip(",")
        if not line or line == "_":
            continue
        nums = re.findall(r"-?\d+(?:\.\d+)?", line)
        if len(nums) >= 2:
            pts.append((float(nums[0]), float(nums[1])))
    return pts


def parse_legacy_xy_route(text: str, array_name: str) -> list[tuple[float, float]]:
    pattern = rf"Global\s+\${re.escape(array_name)}(?:\[[^\]]*\])*\s*=\s*\[\s*_(.*?)\n\]"
    m = re.search(pattern, text, re.DOTALL)
    if not m:
        raise ValueError(f"Legacy array {array_name} not found")
    pts: list[tuple[float, float]] = []
    for chunk in re.findall(r"\[(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)", m.group(1)):
        pts.append((float(chunk[0]), float(chunk[1])))
    return pts


def parse_route01(vq_path: Path) -> list[tuple[float, float]]:
    text = vq_path.read_text(encoding="utf-8", errors="replace")
    if "oldAscalon" in text:
        return parse_legacy_xy_route(text, "oldAscalon")
    for name in re.findall(r"Global\s+\$(\w+Route01)\[", text):
        return parse_coord_array(text, name)
    for name in re.findall(r"Global\s+\$(\w+Route)\[", text):
        if "Transit" not in name and "Outpost" not in name:
            return parse_coord_array(text, name)
    raise ValueError(f"No Route01 in {vq_path}")


def load_portal_paths() -> dict[str, list[tuple[float, float]]]:
    text = GOOUT.read_text(encoding="utf-8", errors="replace")
    out: dict[str, list[tuple[float, float]]] = {}
    for name in re.findall(r"Global\s+\$(a\w+PortalPath)\s*=", text):
        out[name] = parse_coord_array(text, name)
    return out


def load_manual_coords(map_id: int) -> list[tuple[float, float]]:
    pts: list[tuple[float, float]] = []
    for path in sorted(LOGS.glob("*.csv")):
        if path.name.startswith("."):
            continue
        with path.open(newline="", encoding="utf-8", errors="replace") as f:
            reader = csv.DictReader(f)
            if not reader.fieldnames or "x" not in reader.fieldnames:
                continue
            for row in reader:
                x, y = row.get("x", ""), row.get("y", "")
                if not x or not y:
                    continue
                row_map = row.get("map_id", "")
                if row_map and row_map.strip() and int(float(row_map)) != map_id:
                    continue
                if not row_map and f"map_waypoints_{map_id}" not in path.name and f"_{map_id}_" not in path.name:
                    if "combat_coords" in path.name:
                        continue
                pts.append((float(x), float(y)))
    return pts


def near_any(p: tuple[float, float], route: list[tuple[float, float]], d: float = MIN_SPACING) -> bool:
    return any(dist(p, q) < d for q in route)


def dedupe_route(route: list[tuple[float, float]], d: float = MIN_SPACING) -> list[tuple[float, float]]:
    """Collapse only consecutive points closer than d (matches MapRoute_DedupePath1D)."""
    if not route:
        return []
    out = [route[0]]
    for p in route[1:]:
        if dist(out[-1], p) >= d:
            out.append(p)
    return out


def insert_extras(route: list[tuple[float, float]], extras: list[tuple[float, float]]) -> list[tuple[float, float]]:
    route = list(route)
    for ex in extras:
        if near_any(ex, route):
            continue
        if len(route) < 2:
            route.append(ex)
            continue
        best_i = 0
        best_cost = float("inf")
        for i in range(len(route) - 1):
            a, b = route[i], route[i + 1]
            cost = dist(a, ex) + dist(ex, b) - dist(a, b)
            if cost < best_cost:
                best_cost = cost
                best_i = i
        route.insert(best_i + 1, ex)
    return route


def append_portal_tail(route: list[tuple[float, float]], portal: list[tuple[float, float]]) -> list[tuple[float, float]]:
    if not portal:
        return route
    route = list(route)
    anchor = route[-1]
    start = 0
    best = float("inf")
    for i, p in enumerate(portal):
        d = dist(anchor, p)
        if d < best:
            best = d
            start = i
    tail = portal[start + 1 :]
    if tail:
        route.extend(tail)
    elif portal:
        last = portal[-1]
        if dist(route[-1], last) >= 1:
            route.append(last)
    out = dedupe_route(route)
    if portal and dist(out[-1], portal[-1]) >= 1:
        out.append(portal[-1])
    return out


def fmt_coord(x: float, y: float) -> str:
    if abs(x - round(x)) < 1e-4 and abs(y - round(y)) < 1e-4:
        return f"    [{int(round(x))}, {int(round(y))}], _"
    xs = f"{x:.4f}".rstrip("0").rstrip(".")
    ys = f"{y:.4f}".rstrip("0").rstrip(".")
    return f"    [{xs}, {ys}], _"


def write_route(title: str, points: list[tuple[float, float]], portal_name: str | None) -> None:
    var = f"$aCaravanAscalon_{title}Path"
    const = f"$GC_I_ROUTE_{title}_COUNT"
    tail = ""
    if portal_name:
        tail = f"; Tail follows recorded GoOut portal path (${portal_name[1:]}).\n"
    content = f"""#include-once

; Caravan vanquish route for {title} (vanquish-bot route + manual coverage coords).
{tail}
Global {var} = [ _
"""
    for x, y in points:
        content += fmt_coord(x, y) + "\n"
    content += f"""]

Global Const {const} = {len(points)}


Func MapRoute_Get{title}(ByRef $a_a_X, ByRef $a_a_Y)
\tReturn MapRoute_CopyPath1D({var}, $a_a_X, $a_a_Y)
EndFunc
"""
    out = ROUTES_DIR / f"CaravanAscalon_{title}.au3"
    out.write_text(content, encoding="utf-8")
    print(f"{title}: {len(points)} waypoints -> {out.name}")


def main() -> None:
    portals = load_portal_paths()
    for title, map_id, vq_rel, portal_name in ROUTES:
        if title in SKIP:
            print(f"{title}: skipped (preserve existing hand merge)")
            continue
        base = parse_route01(VANQUISH_DIR / vq_rel)
        manual = load_manual_coords(map_id)
        route = insert_extras(base, manual)
        if portal_name:
            route = append_portal_tail(route, portals[portal_name])
        else:
            route = dedupe_route(route)
        write_route(title, route, portal_name)


if __name__ == "__main__":
    main()
