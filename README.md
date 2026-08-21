# GwAu3 Map Coverage Combat Logger & Vanquish Bot

AutoIt bots for Guild Wars Hard Mode vanquish automation using GwAu3 Pathfinder, shared route data under `lib/maps/`, and SmartCast combat.

**Use at your own risk.** Automation may violate Guild Wars Terms of Service.

## Launchers

| Script | Purpose |
|--------|---------|
| [`CombatMapper.au3`](CombatMapper.au3) | Map coverage sweeps + **combat coordinate CSV logging** (Log XY, Min/Max bounds, grid step) |
| [`VanquishBot.au3`](VanquishBot.au3) | **Vanquish automation** with hero teams (Team 4/6/8), compact GUI, no combat CSV logging |

Both share the same caravan sequences, vanquish routes, travel/GoOut logic, and Pathfinder movement stack in [`lib/`](lib/).

## Requirements

| Requirement | Notes |
|-------------|--------|
| **Windows x86 AutoIt** | AutoIt **3.3.16.1+** in **32-bit** mode (x86). GwAu3 will not work with 64-bit AutoIt. |
| **Guild Wars client** | Logged in (outpost or explorable). Party leader required for Hard Mode. |
| **Pathfinder maps** | First `Pathfinder_Initialize` downloads `maps.rar` next to `GWPathfinder.dll` when online. |
| **Linux / Nobara** | Run GW + AutoIt under **Wine** (Windows prefix) or on a Windows machine. |

## Target modes (both bots)

| Target | Behavior |
|--------|----------|
| **Current Map** | Sweep wherever you already are (Hard Mode toggle still applied when possible). |
| **Single title** | LocationsIDS name (e.g. `TravelersVale`, `NorthKrytaProvince`). TravelTo outpost → Hard Mode → GoOut portal route → vanquish route sweep. |
| **(Sequence) campaign caravan** | Portal through spine maps; **Ctrl+click** maps to vanquish. Unselected maps are portal transit only. Sequences: Ascalon, Maguuma, EOTN, Factions, Nightfall. |

## Layout

```
gw-combat-mapper/
  CombatMapper.au3          # combat CSV logger
  VanquishBot.au3           # vanquish + heroes
  config.ini                # travel, coverage, combat, pathroute
  vanquish_config.ini       # hero teams (Team4/6/8)
  lib/
    BotEngine.au3           # shared run loop
    HeroTeam.au3            # hero setup (Vanquish Bot)
    CaravanGui.au3          # caravan map list helpers
    Coverage.au3
    CombatLogger.au3        # Combat Mapper only
    MapRoute.au3            # generated — all vanquish + caravan routes
    MapCatalog.au3
    MapTravel.au3
    SmartCast.au3
    maps/
      Vanquish/             # 130 navmesh-repaired route arrays
      Routes/               # 16 caravan Ascalon farm routes
      GoOutRoutes.au3
      Caravan_*Plan.au3
  vendor/
    GwAu3/
    vanquish-bot/Maps/      # gitignored route **source** for navmesh repair
  scripts/
    generate_map_route.py   # regenerate lib/MapRoute.au3
    navmesh/repair_vanquish.py
```

## Setup

1. Ensure `vendor/GwAu3` exists (`git clone --depth 1 https://github.com/GwAu3-Projects/GwAu3.git vendor/GwAu3` if missing).
2. Clone or copy [`vendor/vanquish-bot`](vendor/vanquish-bot) route sources if regenerating vanquish arrays.
3. Install AutoIt **x86**.
4. Launch Guild Wars; run **`VanquishBot.au3`** for vanquishing or **`CombatMapper.au3`** for coordinate logging.

Optional CLI:

```text
AutoIt3.exe VanquishBot.au3 -character "YourCharName"
AutoIt3.exe CombatMapper.au3 -character "YourCharName"
```

## Config

**Travel / coverage / combat:** [`config.ini`](config.ini)

**Hero teams (Vanquish Bot):** [`vanquish_config.ini`](vanquish_config.ini)

```ini
[Team4]
Hero1=Norgu
Hero2=Gwen
Hero3=Olias
[Team6]
Hero1=...
[Team8]
Hero1=...
```

Hero teams are applied automatically before each map based on that map's max party size (4, 6, or 8).

## Route maintenance

Regenerate the MapRoute loader after editing route files:

```bash
python3 scripts/generate_map_route.py
python3 scripts/generate_map_route.py --check   # CI staleness check
```

Refresh vanquish coordinate arrays from vendor source:

```bash
python3 -m scripts.navmesh.repair_vanquish repair
python3 scripts/merge_caravan_routes.py
python3 scripts/generate_map_route.py
```

## Recommended first test (Vanquish Bot)

1. Configure heroes for Team 4/6/8 → **Save Heroes**.
2. Select **(Sequence) Ascalon Caravan**; Ctrl+click 1–2 maps (e.g. `NorthKrytaProvince`).
3. Enable **Hard Mode** and **Skip completed**.
4. Start → confirm travel, hero setup, route walk, and vanquish repeat passes.

## Combat Mapper CSV columns

`timestamp,map_id,event,x,y` — see [`CombatMapper.au3`](CombatMapper.au3) console help for Log XY and coverage bounds.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Hard Mode not set | Be party leader in an outpost before GoOut. |
| GoOut fails | Confirm Pathfinder maps.rar; check console for portal WP lines. |
| No route for map | Run `generate_map_route.py`; confirm file exists under `lib/maps/Vanquish/`. |
| Heroes not added | Must be in outpost; configure the matching Team N for map party size. |
| AutoIt crash | Use **32-bit** AutoIt; run as admin. |
