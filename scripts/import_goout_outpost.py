#!/usr/bin/env python3
"""Import vendor OutpostPath arrays into GoOutRoutes and generate outpost lookup."""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VENDOR_MAPS = ROOT / "vendor/vanquish-bot/Maps"
LOCATIONS = ROOT / "lib/maps/LocationsIDS.au3"
GOOUT = ROOT / "lib/maps/GoOutRoutes.au3"
LOOKUP = ROOT / "lib/maps/GoOutOutpostLookup.au3"

GENERATED_MARKER = "; --- Outpost exit paths (generated) ---"

# Vendor filename / target title -> LocationsIDS prefix when they differ.
LOCATIONS_TITLE: dict[str, str] = {
    "IceDome": "Icedome",
}

# LocationsIDS entries with no outpost comment.
OUTPOST_LABEL_FALLBACK: dict[str, str] = {
    "TheBlackCurtain": "Temple of the Ages",
}

# Maps entered via MapTravel_TryGetTOAKrytaSpinePath (multi-hop from TOA).
TOA_KRYTA_SPINE = frozenset({"TalmarkWilderness", "StingrayStrand", "TearsoftheFallen"})
TOA_OUTPOST_ID = 138

# Maps entered via MapTravel_TryGetSouthernShiverpeaksSpinePath (multi-hop from Droknar's Forge).
SOUTHERN_SHIVERPEAKS_SPINE = frozenset({"TalusChute", "SnakeDance", "DreadnoughtsDrift", "LornarsPass"})
DROKNARS_FORGE_OUTPOST_ID = 20

# Maps entered via MapTravel_TryGetIceCavesSpinePath (multi-hop from Ice Caves of Sorrow).
ICE_CAVES_SPINE = frozenset({"IceDome", "FrozenForest", "IceFloe"})
ICE_CAVES_OUTPOST_ID = 23

_OUTPOST_BLOCK_RE = re.compile(
    r"\n;[^\n]*\nGlobal \$aTheBlackCurtainOutpostPath = \[\s*_\r?\n.*?\r?\n\]\r?\n",
    re.DOTALL,
)


@dataclass(slots=True)
class OutpostRoute:
    target_title: str
    locations_title: str
    array_name: str
    points: list[tuple[float, float]]
    outpost_label: str


def parse_coord_array(text: str, array_name: str) -> list[tuple[float, float]]:
    pattern = rf"(?:Global|Local)\s+\${re.escape(array_name)}(?:\[[^\]]*\])*\s*=\s*\[\s*_(.*?)\n\]"
    match = re.search(pattern, text, re.DOTALL)
    if not match:
        raise ValueError(f"Array {array_name} not found")
    points: list[tuple[float, float]] = []
    for line in match.group(1).splitlines():
        line = line.strip().rstrip(",")
        if not line or line == "_":
            continue
        nums = re.findall(r"-?\d+(?:\.\d+)?", line)
        if len(nums) >= 2:
            points.append((float(nums[0]), float(nums[1])))
    return points


def load_outpost_labels() -> dict[str, str]:
    text = LOCATIONS.read_text(encoding="utf-8", errors="replace")
    labels: dict[str, str] = {}
    for match in re.finditer(
        r"Global\s+\$(\w+)_Outpost\s*=[^\n;]*(?:;\s*([^\n]+))?",
        text,
    ):
        title = match.group(1)
        comment = (match.group(2) or "").strip()
        if comment.startswith("—") or comment.startswith("-"):
            comment = comment.lstrip("—- ").strip()
        if comment:
            labels[title] = comment.split("—")[0].split("-")[0].strip()
    return labels


def locations_title_for(target_title: str) -> str:
    return LOCATIONS_TITLE.get(target_title, target_title)


def get_outpost_id(locations_title: str) -> int | None:
    text = LOCATIONS.read_text(encoding="utf-8", errors="replace")
    match = re.search(
        rf"Global\s+\${re.escape(locations_title)}_Outpost\s*=\s*(\d+)",
        text,
    )
    if match:
        return int(match.group(1))
    return None


def has_locations_outpost(locations_title: str) -> bool:
    text = LOCATIONS.read_text(encoding="utf-8", errors="replace")
    return f"${locations_title}_Outpost" in text


def discover_outpost_routes() -> list[OutpostRoute]:
    labels = load_outpost_labels()
    routes: list[OutpostRoute] = []

    for path in sorted(VENDOR_MAPS.glob("*/*.au3")):
        text = path.read_text(encoding="utf-8", errors="replace")
        match = re.search(r"(?:Global|Local)\s+\$(\w+OutpostPath)", text)
        if not match:
            continue

        target_title = path.stem
        locations_title = locations_title_for(target_title)
        if not has_locations_outpost(locations_title):
            print(f"WARNING: skipping {target_title}: no ${locations_title}_Outpost in LocationsIDS", file=sys.stderr)
            continue

        outpost_id = get_outpost_id(locations_title)
        if target_title in TOA_KRYTA_SPINE and outpost_id == TOA_OUTPOST_ID:
            continue
        if target_title in SOUTHERN_SHIVERPEAKS_SPINE and outpost_id == DROKNARS_FORGE_OUTPOST_ID:
            continue
        if target_title in ICE_CAVES_SPINE and outpost_id == ICE_CAVES_OUTPOST_ID:
            continue

        array_name = match.group(1)
        points = parse_coord_array(text, array_name)
        if len(points) < 1:
            print(f"WARNING: skipping {target_title}: empty OutpostPath", file=sys.stderr)
            continue

        outpost_label = labels.get(locations_title) or OUTPOST_LABEL_FALLBACK.get(locations_title, locations_title)
        routes.append(
            OutpostRoute(
                target_title=target_title,
                locations_title=locations_title,
                array_name=array_name,
                points=points,
                outpost_label=outpost_label,
            )
        )

    routes.sort(key=lambda route: route.target_title.lower())
    return routes


def format_array(array_name: str, points: list[tuple[float, float]]) -> str:
    lines = [f"Global ${array_name} = [ _"]
    for x, y in points:
        if float(x).is_integer() and float(y).is_integer():
            lines.append(f"\t[{int(x)}, {int(y)}], _")
        else:
            lines.append(f"\t[{x}, {y}], _")
    if lines:
        lines[-1] = lines[-1].rstrip(", _") + " _"
    lines.append("]")
    return "\n".join(lines)


def render_arrays(routes: list[OutpostRoute]) -> str:
    chunks = [
        GENERATED_MARKER,
        "; Generated by scripts/import_goout_outpost.py — do not edit by hand.",
        "; Outpost interior -> exit portal (vendor vanquish-bot OutpostPath).",
        "",
    ]
    for route in routes:
        chunks.append(f"; {route.outpost_label} outpost -> {route.target_title}")
        chunks.append(format_array(route.array_name, route.points))
        chunks.append("")
    return "\n".join(chunks).rstrip() + "\n"


def render_lookup(routes: list[OutpostRoute]) -> str:
    lines = [
        "#include-once",
        "",
        "; Generated by scripts/import_goout_outpost.py — do not edit by hand.",
        "; Outpost exit lookup for MapTravel_TryGetCaravanPortalPath.",
        "",
        "Func MapTravel_TryGetOutpostPath($a_i_FromMap, $a_s_TargetTitle, ByRef $a_a_Path, ByRef $a_s_Label)",
        "\tSwitch $a_s_TargetTitle",
    ]
    for route in routes:
        var = route.locations_title
        label = f"{route.outpost_label}->{route.target_title} "
        lines.extend(
            [
                f'\t\tCase "{route.target_title}"',
                f"\t\t\tIf $a_i_FromMap = ${var}_Outpost Then",
                f"\t\t\t\t$a_a_Path = ${route.array_name}",
                f'\t\t\t\t$a_s_Label = "{label}"',
                "\t\t\t\tReturn True",
                "\t\t\tEndIf",
            ]
        )
    lines.extend(
        [
            "\tEndSwitch",
            "\tReturn False",
            "EndFunc",
            "",
        ]
    )
    return "\n".join(lines)


def strip_generated_section(text: str) -> str:
    if GENERATED_MARKER in text:
        return text.split(GENERATED_MARKER, 1)[0].rstrip() + "\n"
    return text


def strip_manual_black_curtain(text: str) -> str:
    return _OUTPOST_BLOCK_RE.sub("\n", text)


def update_goout_routes(routes: list[OutpostRoute]) -> None:
    base = strip_generated_section(strip_manual_black_curtain(GOOUT.read_text(encoding="utf-8", errors="replace")))
    if not base.endswith("\n"):
        base += "\n"
    GOOUT.write_text(base + "\n" + render_arrays(routes), encoding="utf-8")


def main() -> int:
    if not VENDOR_MAPS.is_dir():
        print(f"ERROR: vendor maps not found at {VENDOR_MAPS}", file=sys.stderr)
        return 1

    routes = discover_outpost_routes()
    if not routes:
        print("ERROR: no OutpostPath routes found", file=sys.stderr)
        return 1

    update_goout_routes(routes)
    LOOKUP.write_text(render_lookup(routes), encoding="utf-8")

    print(f"Wrote {len(routes)} outpost paths to {GOOUT.name}")
    print(f"Wrote lookup to {LOOKUP.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
