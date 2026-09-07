#!/usr/bin/env python3
"""Run the navmesh coordinate generator from this folder.

    python3 generate_navmesh_coords.py --list
    python3 generate_navmesh_coords.py --map TalusChute
    python3 generate_navmesh_coords.py --all
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.navmesh.generate_from_maps import main

if __name__ == "__main__":
    raise SystemExit(main())
