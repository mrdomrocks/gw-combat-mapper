#!/usr/bin/env python3
"""Generate lib/MapRoute.au3 from lib/maps/Vanquish and lib/maps/Routes."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VANQUISH_DIR = ROOT / "lib/maps/Vanquish"
ROUTES_DIR = ROOT / "lib/maps/Routes"
OUTPUT = ROOT / "lib/MapRoute.au3"

ROUTE_ARRAY_RE = re.compile(
    r"^Global\s+(\$a\w+Route\d+)\[", re.MULTILINE
)
GETTER_RE = re.compile(r"^Func\s+(MapRoute_Get\w+)\(", re.MULTILINE)


def title_from_vanquish(path: Path) -> str:
    return path.stem


def title_from_caravan(path: Path) -> str:
    name = path.stem
    if name.startswith("CaravanAscalon_"):
        return name[len("CaravanAscalon_") :]
    return name


def discover_vanquish() -> list[tuple[str, Path, str]]:
    entries: list[tuple[str, Path, str]] = []
    for path in sorted(VANQUISH_DIR.rglob("*.au3")):
        text = path.read_text(encoding="utf-8", errors="replace")
        match = ROUTE_ARRAY_RE.search(text)
        if not match:
            print(f"warning: no route array in {path}", file=sys.stderr)
            continue
        title = title_from_vanquish(path)
        rel = path.relative_to(ROOT / "lib").as_posix().replace("/", "\\")
        entries.append((title, path, match.group(1)))
    return entries


def discover_caravan() -> list[tuple[str, Path, str]]:
    entries: list[tuple[str, Path, str]] = []
    for path in sorted(ROUTES_DIR.glob("CaravanAscalon_*.au3")):
        text = path.read_text(encoding="utf-8", errors="replace")
        match = GETTER_RE.search(text)
        if not match:
            print(f"warning: no MapRoute_Get* in {path}", file=sys.stderr)
            continue
        title = title_from_caravan(path)
        entries.append((title, path, match.group(1)))
    return entries


def render(vanquish: list[tuple[str, Path, str]], caravan: list[tuple[str, Path, str]]) -> str:
    caravan_titles = {title for title, _, _ in caravan}
    includes: list[str] = []
    cases: list[str] = []

    for _title, path, getter in caravan:
        rel = path.relative_to(ROOT / "lib").as_posix().replace("/", "\\")
        includes.append(f'#include "maps\\Routes\\{path.name}"')

    for _title, path, array_name in vanquish:
        rel = path.relative_to(ROOT / "lib/maps").as_posix().replace("/", "\\")
        folder = path.parent.name
        includes.append(f'#include "maps\\Vanquish\\{folder}\\{path.name}"')

    includes = sorted(set(includes))

    for title, _path, getter in sorted(caravan, key=lambda e: e[0]):
        cases.append(f'\t\tCase "{title}"')
        cases.append(f"\t\t\tReturn {getter}($a_a_X, $a_a_Y)")

    for title, _path, array_name in sorted(vanquish, key=lambda e: e[0]):
        if title in caravan_titles:
            continue
        cases.append(f'\t\tCase "{title}"')
        cases.append(f"\t\t\tReturn MapRoute_CopyPath1D({array_name}, $a_a_X, $a_a_Y)")

    body = "\n".join(
        [
            "#include-once",
            "",
            *includes,
            "",
            "Func _MapRoute_Distance($a_f_X1, $a_f_Y1, $a_f_X2, $a_f_Y2)",
            '\tReturn Sqrt(($a_f_X2 - $a_f_X1) ^ 2 + ($a_f_Y2 - $a_f_Y1) ^ 2)',
            "EndFunc",
            "",
            "Func MapRoute_DedupePath1D(ByRef $a_a_X, ByRef $a_a_Y, $a_i_Count, $a_f_MinSpacing = 150)",
            "\tIf $a_i_Count < 2 Then Return $a_i_Count",
            "",
            "\tLocal $l_a_TempX[$a_i_Count]",
            "\tLocal $l_a_TempY[$a_i_Count]",
            "\t$l_a_TempX[0] = $a_a_X[0]",
            "\t$l_a_TempY[0] = $a_a_Y[0]",
            "\tLocal $l_i_Out = 1",
            "",
            "\tFor $i = 1 To $a_i_Count - 1",
            "\t\tLocal $l_f_D = _MapRoute_Distance($l_a_TempX[$l_i_Out - 1], $l_a_TempY[$l_i_Out - 1], $a_a_X[$i], $a_a_Y[$i])",
            "\t\tIf $l_f_D < $a_f_MinSpacing Then ContinueLoop",
            "\t\t$l_a_TempX[$l_i_Out] = $a_a_X[$i]",
            "\t\t$l_a_TempY[$l_i_Out] = $a_a_Y[$i]",
            "\t\t$l_i_Out += 1",
            "\tNext",
            "",
            "\tReDim $a_a_X[$l_i_Out]",
            "\tReDim $a_a_Y[$l_i_Out]",
            "\tFor $i = 0 To $l_i_Out - 1",
            "\t\t$a_a_X[$i] = $l_a_TempX[$i]",
            "\t\t$a_a_Y[$i] = $l_a_TempY[$i]",
            "\tNext",
            "\tReturn $l_i_Out",
            "EndFunc",
            "",
            "Func MapRoute_CopyPath1D(ByRef $a_a_Source, ByRef $a_a_X, ByRef $a_a_Y)",
            "\tIf Not IsArray($a_a_Source) Then Return 0",
            "",
            "\tLocal $l_i_Count = 0",
            "\tIf UBound($a_a_Source, 0) = 2 Then",
            "\t\t$l_i_Count = UBound($a_a_Source, 1)",
            "\tElse",
            "\t\t$l_i_Count = UBound($a_a_Source)",
            "\tEndIf",
            "\tIf $l_i_Count < 1 Then Return 0",
            "",
            "\tLocal $l_a_X[$l_i_Count]",
            "\tLocal $l_a_Y[$l_i_Count]",
            "\tFor $i = 0 To $l_i_Count - 1",
            "\t\t$l_a_X[$i] = $a_a_Source[$i][0]",
            "\t\t$l_a_Y[$i] = $a_a_Source[$i][1]",
            "\tNext",
            "",
            "\tLocal $l_i_Out = MapRoute_DedupePath1D($l_a_X, $l_a_Y, $l_i_Count)",
            "\tIf $l_i_Out < 1 Then Return 0",
            "\t$a_a_X = $l_a_X",
            "\t$a_a_Y = $l_a_Y",
            "\tReturn $l_i_Out",
            "EndFunc",
            "",
            "Func MapRoute_TryLoadForTitle($a_s_Title, ByRef $a_a_X, ByRef $a_a_Y)",
            "\tSwitch $a_s_Title",
            *cases,
            "\tEndSwitch",
            "\tReturn 0",
            "EndFunc",
            "",
            "Func MapRoute_HasRoute($a_s_Title)",
            "\tLocal $l_a_X, $l_a_Y",
            "\tReturn MapRoute_TryLoadForTitle($a_s_Title, $l_a_X, $l_a_Y) > 0",
            "EndFunc",
            "",
        ]
    )
    header = (
        "; Generated by scripts/generate_map_route.py — do not edit by hand.\n"
        f"; Caravan routes: {len(caravan)} | Vanquish arrays: {len(vanquish)} | Switch cases: {len(cases)//2}\n"
    )
    return header + body + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Exit 1 if MapRoute.au3 is stale")
    args = parser.parse_args()

    vanquish = discover_vanquish()
    caravan = discover_caravan()
    content = render(vanquish, caravan)

    if args.check:
        if not OUTPUT.exists():
            print("MapRoute.au3 missing", file=sys.stderr)
            return 1
        if OUTPUT.read_text(encoding="utf-8") != content:
            print("MapRoute.au3 is stale — run scripts/generate_map_route.py", file=sys.stderr)
            return 1
        print(f"MapRoute.au3 up to date ({len(vanquish)} vanquish, {len(caravan)} caravan)")
        return 0

    OUTPUT.write_text(content, encoding="utf-8")
    print(f"Wrote {OUTPUT} ({len(vanquish)} vanquish, {len(caravan)} caravan)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
