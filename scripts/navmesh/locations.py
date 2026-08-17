#!/usr/bin/env python3
"""Map name -> in-game map id, read from `LocationsIDS.au3`.

The file declares one `Global $<Name>_Map = <id>` per explorable, alongside
`_Transit` and `_Outpost` entries that are deliberately ignored: only `_Map`
names the explorable a vanquish route actually runs on.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_LOCATIONS = ROOT / "lib/maps/LocationsIDS.au3"

_MAP_RE = re.compile(r"^\s*Global\s+\$(\w+)_Map\s*=\s*(\d+)", re.MULTILINE)


def _key(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


class LocationIndex:
    def __init__(self, path: str | Path = DEFAULT_LOCATIONS) -> None:
        self.path = Path(path)
        text = self.path.read_text(encoding="utf-8", errors="replace")
        self._by_key: dict[str, int] = {}
        self.names: dict[str, int] = {}
        for match in _MAP_RE.finditer(text):
            name, map_id = match.group(1), int(match.group(2))
            self.names[name] = map_id
            self._by_key.setdefault(_key(name), map_id)

    def map_id(self, name: str) -> int | None:
        return self._by_key.get(_key(name))

    def __len__(self) -> int:
        return len(self.names)


if __name__ == "__main__":
    index = LocationIndex()
    print(f"{len(index)} map ids from {index.path}")
    for name, map_id in sorted(index.names.items())[:5]:
        print(f"  {name} = {map_id}")
