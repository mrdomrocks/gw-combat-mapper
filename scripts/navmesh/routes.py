#!/usr/bin/env python3
"""Read and rewrite the `$aCaravanAscalon_<Name>Path` coordinate arrays.

Rewrites are surgical: only the coordinate lines inside the array literal and
the matching `$GC_I_ROUTE_<Name>_COUNT` value are touched, so the leading
comment block, the `MapRoute_Get*` accessors and any extra helpers in the file
survive untouched. Untouched waypoints are written back with their original
text byte for byte, so a repair diff shows only real changes.

Generated waypoints carry a trailing `; auto` comment. AutoIt allows a comment
after the `_` line-continuation character (GwAu3 relies on this in several
places), and the marker is what makes repeated runs idempotent: a re-run drops
the previously generated points before recomputing.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

Point = tuple[float, float]

AUTO_MARKER = "; auto"

_ARRAY_RE = re.compile(
    r"(?P<head>Global\s+\$(?P<name>aCaravanAscalon_(?P<title>\w+)Path)\s*=\s*\[\s*_\r?\n)"
    r"(?P<body>.*?)"
    r"(?P<tail>\r?\n\])",
    re.DOTALL,
)
_COUNT_RE = re.compile(
    r"(?P<head>Global\s+Const\s+\$GC_I_ROUTE_(?P<title>\w+)_COUNT\s*=\s*)(?P<value>\d+)"
)
# The separator is deliberately loose: one shipped route file uses a tab instead
# of a comma, which AutoIt silently folds into a single subtraction.
_COORD_RE = re.compile(
    r"\[\s*(-?\d+(?:\.\d+)?)\s*(?P<sep>,|\s)\s*(-?\d+(?:\.\d+)?)\s*\]"
)


class RouteError(RuntimeError):
    pass


@dataclass(slots=True)
class RoutePoint:
    x: float
    y: float
    generated: bool = False
    raw: str | None = None
    malformed: bool = False

    @property
    def point(self) -> Point:
        return (self.x, self.y)


@dataclass(slots=True)
class RouteFile:
    path: Path
    title: str
    array_name: str
    entries: list[RoutePoint] = field(default_factory=list)
    indent: str = "\t"
    declared_count: int | None = None

    @property
    def points(self) -> list[Point]:
        return [e.point for e in self.entries]

    @property
    def original_entries(self) -> list[RoutePoint]:
        """Hand-recorded waypoints, with previously generated ones dropped."""
        return [e for e in self.entries if not e.generated]

    @property
    def generated_count(self) -> int:
        return sum(e.generated for e in self.entries)

    @property
    def malformed_count(self) -> int:
        return sum(e.malformed for e in self.entries)


def parse_route(path: str | Path) -> RouteFile | None:
    """Parse a route file, or return None when it holds no coordinate array.

    Returns None when the file holds no coordinate array.
    """
    path = Path(path)
    text = path.read_text(encoding="utf-8", errors="replace")
    match = _ARRAY_RE.search(text)
    if match is None:
        return None

    entries: list[RoutePoint] = []
    indent = "\t"
    for line in match.group("body").splitlines():
        coord = _COORD_RE.search(line)
        if coord is None:
            continue
        malformed = coord.group("sep") != ","
        entries.append(
            RoutePoint(
                x=float(coord.group(1)),
                y=float(coord.group(3)),
                generated=AUTO_MARKER in line,
                raw=None if malformed else coord.group(0),
                malformed=malformed,
            )
        )
        leading = line[: len(line) - len(line.lstrip())]
        if leading:
            indent = leading

    count_match = next(
        (m for m in _COUNT_RE.finditer(text) if m.group("title") == match.group("title")),
        None,
    )

    return RouteFile(
        path=path,
        title=match.group("title"),
        array_name=match.group("name"),
        entries=entries,
        indent=indent,
        declared_count=int(count_match.group("value")) if count_match else None,
    )


def format_number(value: float) -> str:
    if abs(value - round(value)) < 1e-6:
        return str(int(round(value)))
    return f"{value:.4f}".rstrip("0").rstrip(".")


def format_coord(entry: RoutePoint) -> str:
    if entry.raw is not None:
        return entry.raw
    return f"[{format_number(entry.x)}, {format_number(entry.y)}]"


def format_body(entries: list[RoutePoint], indent: str = "\t") -> str:
    if not entries:
        raise RouteError("refusing to write an empty route array")
    lines: list[str] = []
    last = len(entries) - 1
    for i, entry in enumerate(entries):
        line = indent + format_coord(entry)
        line += " _" if i == last else ", _"
        if entry.generated:
            line += f" {AUTO_MARKER}"
        lines.append(line)
    return "\n".join(lines)


def write_route(route: RouteFile, entries: list[RoutePoint]) -> None:
    text = route.path.read_text(encoding="utf-8", errors="replace")
    match = _ARRAY_RE.search(text)
    if match is None:
        raise RouteError(f"{route.path}: coordinate array vanished between read and write")

    body = format_body(entries, route.indent)
    text = text[: match.start("body")] + body + text[match.end("body") :]

    def replace_count(m: re.Match[str]) -> str:
        if m.group("title") != route.title:
            return m.group(0)
        return f"{m.group('head')}{len(entries)}"

    text = _COUNT_RE.sub(replace_count, text)
    route.path.write_text(text, encoding="utf-8")


def discover_routes(routes_dir: str | Path) -> list[Path]:
    return sorted(Path(routes_dir).glob("CaravanAscalon_*.au3"))
