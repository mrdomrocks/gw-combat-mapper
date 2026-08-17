#!/usr/bin/env python3
"""Reader for GWVisualizer .pmap files (Guild Wars pathing/walkable geometry).

Format, reverse engineered and validated against recorded in-game coordinates:

    offset  type      field
    0x00    char[4]   "PAMP"
    0x04    uint32    pmap file id
    0x08    uint32    trapezoid_count
    0x0C    uint32    trapezoid_offset (40)
    0x10    uint32    edge_count
    0x14    uint32    edge_offset
    0x18    float[4]  minX, minY, maxX, maxY
    0x28    trapezoid[trapezoid_count]
            edge[edge_count]

Each trapezoid is 34 bytes:

    uint32 reserved, uint32 reserved, uint16 plane,
    float YT, YB, XTL, XTR, XBL, XBR

Each edge is 20 bytes (`uint32 id, float x1, y1, x2, y2`) describing a
horizontal boundary segment. Many maps, including every Ascalon caravan map,
carry `edge_count == 0`, so adjacency has to be derived geometrically.

Both invariants hold exactly across all 1027 shipped files, which is what pins
the record sizes down:

    trapezoid_offset + 34 * trapezoid_count == edge_offset
    edge_offset      + 20 * edge_count      == file_size
"""

from __future__ import annotations

import csv
import os
import re
import struct
from dataclasses import dataclass
from pathlib import Path

MAGIC = b"PAMP"
_HEADER = struct.Struct("<4sIIIII")
_BOUNDS = struct.Struct("<4f")
_FLOATS = struct.Struct("<6f")
_EDGE = struct.Struct("<I4f")

RECORD_SIZE = 34
EDGE_SIZE = 20
PLANE_OFFSET = 8
FLOAT_OFFSET = 10

DEFAULT_VISUALIZER_DIR = Path(
    os.environ.get(
        "GW_VISUALIZER_DIR",
        "/home/mrdomrocks/.wine/drive_c/Program Files (x86)/Guild Wars/GwAu3-main/GWVisualizer",
    )
)


class PmapError(RuntimeError):
    pass


@dataclass(frozen=True, slots=True)
class Trapezoid:
    """A horizontal walkable slab: top edge at `yt`, bottom edge at `yb`.

    Stored normalised so that `yt >= yb` and each edge's left x is <= its right x.
    """

    index: int
    plane: int
    yt: float
    yb: float
    xtl: float
    xtr: float
    xbl: float
    xbr: float

    @property
    def height(self) -> float:
        return self.yt - self.yb

    @property
    def centroid(self) -> tuple[float, float]:
        return ((self.xtl + self.xtr + self.xbl + self.xbr) / 4.0, (self.yt + self.yb) / 2.0)

    def x_span_at(self, y: float) -> tuple[float, float]:
        """Left and right x of the slab at height `y` (clamped to the slab)."""
        h = self.height
        if h <= 0.0:
            return (min(self.xtl, self.xbl), max(self.xtr, self.xbr))
        t = (y - self.yb) / h
        t = 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)
        return (self.xbl + (self.xtl - self.xbl) * t, self.xbr + (self.xtr - self.xbr) * t)

    def contains(self, x: float, y: float, eps: float = 0.0) -> bool:
        if not (self.yb - eps <= y <= self.yt + eps):
            return False
        left, right = self.x_span_at(y)
        return left - eps <= x <= right + eps


@dataclass(frozen=True, slots=True)
class PathingMap:
    file_id: int
    bounds: tuple[float, float, float, float]
    trapezoids: tuple[Trapezoid, ...]
    edges: tuple[tuple[int, float, float, float, float], ...]

    @property
    def planes(self) -> set[int]:
        return {t.plane for t in self.trapezoids}


def parse_pmap(path: str | Path) -> PathingMap:
    data = Path(path).read_bytes()
    if len(data) < _HEADER.size + _BOUNDS.size:
        raise PmapError(f"{path}: too small to be a pmap")

    magic, file_id, count, trap_offset, edge_count, edge_offset = _HEADER.unpack_from(data, 0)
    if magic != MAGIC:
        raise PmapError(f"{path}: bad magic {magic!r}, expected {MAGIC!r}")
    if trap_offset + RECORD_SIZE * count != edge_offset:
        raise PmapError(
            f"{path}: {trap_offset} + {RECORD_SIZE} * {count} != {edge_offset}; unexpected layout"
        )
    if edge_offset + EDGE_SIZE * edge_count != len(data):
        raise PmapError(
            f"{path}: {edge_offset} + {EDGE_SIZE} * {edge_count} != {len(data)}; unexpected layout"
        )

    bounds = _BOUNDS.unpack_from(data, _HEADER.size)

    traps: list[Trapezoid] = []
    for i in range(count):
        base = trap_offset + RECORD_SIZE * i
        plane = data[base + PLANE_OFFSET] | (data[base + PLANE_OFFSET + 1] << 8)
        yt, yb, xtl, xtr, xbl, xbr = _FLOATS.unpack_from(data, base + FLOAT_OFFSET)
        if yt < yb:
            yt, yb = yb, yt
            xtl, xtr, xbl, xbr = xbl, xbr, xtl, xtr
        if xtl > xtr:
            xtl, xtr = xtr, xtl
        if xbl > xbr:
            xbl, xbr = xbr, xbl
        traps.append(Trapezoid(i, plane, yt, yb, xtl, xtr, xbl, xbr))

    edges = tuple(
        _EDGE.unpack_from(data, edge_offset + EDGE_SIZE * i) for i in range(edge_count)
    )
    return PathingMap(file_id, bounds, tuple(traps), edges)


@dataclass(frozen=True, slots=True)
class MapEntry:
    map_id: int
    name: str
    pmap_file_id: int


def _normalise(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


class MapIndex:
    """`mapinfo.csv` lookup: map id / display name -> pmap file id."""

    def __init__(self, visualizer_dir: str | Path = DEFAULT_VISUALIZER_DIR) -> None:
        self.visualizer_dir = Path(visualizer_dir)
        self.pmaps_dir = self.visualizer_dir / "PMAPs"
        csv_path = self.visualizer_dir / "mapinfo.csv"
        if not csv_path.is_file():
            raise PmapError(f"mapinfo.csv not found at {csv_path}")

        self._by_id: dict[int, MapEntry] = {}
        self._by_name: dict[str, MapEntry] = {}
        with csv_path.open(newline="", encoding="utf-8", errors="replace") as f:
            for row in csv.reader(f):
                if len(row) < 3 or not row[0].strip().isdigit() or not row[2].strip().isdigit():
                    continue
                entry = MapEntry(int(row[0]), row[1].strip(), int(row[2]))
                if entry.pmap_file_id <= 0:
                    continue
                self._by_id[entry.map_id] = entry
                self._by_name.setdefault(_normalise(entry.name), entry)

    def entry_for_map_id(self, map_id: int) -> MapEntry | None:
        return self._by_id.get(map_id)

    def entry_for_name(self, name: str) -> MapEntry | None:
        return self._by_name.get(_normalise(name))

    def pmap_path(self, entry: MapEntry) -> Path:
        return self.pmaps_dir / f"MAP {entry.pmap_file_id:010d}.pmap"

    def load(self, map_id: int) -> PathingMap:
        entry = self.entry_for_map_id(map_id)
        if entry is None:
            raise PmapError(f"map id {map_id} not present in mapinfo.csv")
        path = self.pmap_path(entry)
        if not path.is_file():
            raise PmapError(f"no pmap file for map {map_id} ({entry.name}) at {path}")
        return parse_pmap(path)


if __name__ == "__main__":
    import sys

    index = MapIndex()
    for arg in sys.argv[1:] or ["89"]:
        pm = index.load(int(arg))
        entry = index.entry_for_map_id(int(arg))
        assert entry is not None
        print(
            f"map {entry.map_id} {entry.name}: {len(pm.trapezoids)} trapezoids, "
            f"{len(pm.planes)} planes, bounds {tuple(round(b, 1) for b in pm.bounds)}"
        )
