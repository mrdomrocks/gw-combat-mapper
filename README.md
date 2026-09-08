# GwAu3 Map Coverage Combat Logger & Vanquish Bot

AutoIt bots for Guild Wars Hard Mode vanquish automation using GwAu3 Pathfinder, shared route data under `lib/maps/`, and SmartCast combat.

**Use at your own risk.** Automation may violate Guild Wars Terms of Service.

This project is a **GwAu3 script**, not a standalone wrapper. Clone it into `GwAu3/Scripts/`.

## Launchers

| Script | Purpose |
|--------|---------|
| [`CombatMapper.au3`](CombatMapper.au3) | Map coverage sweeps + **combat coordinate CSV logging** (Log XY, Min/Max bounds, grid step) |
| [`VanquishBot.au3`](VanquishBot.au3) | **Vanquish automation** with hero teams (Team 4/6/8), compact GUI, no combat CSV logging |

Both share the same caravan sequences, vanquish routes, travel/GoOut logic, and Pathfinder movement stack in [`lib/`](lib/).

## Requirements

| Requirement | Notes |
|-------------|--------|
| **GwAu3** | Clone [GwAu3](https://github.com/GwAu3-Projects/GwAu3) first. This folder must live at `GwAu3/Scripts/gw-combat-mapper/`. |
| **Windows x86 AutoIt** | AutoIt **3.3.16.1+** in **32-bit** mode (x86). GwAu3 will not work with 64-bit AutoIt. |
| **Guild Wars client** | Logged in (outpost or explorable). Party leader required for Hard Mode. |
| **Pathfinder maps** | First `Pathfinder_Initialize` downloads `maps.rar` next to `GWPathfinder.dll` when online. |
| **Linux / Wine** | Run GW + AutoIt under **Wine** (Windows prefix) or on a Windows machine. |

## Install

```text
GwAu3/
  API/
    _GwAu3.au3
    Plugins/Pathfinder/GWPathfinder.dll
  Scripts/
    gw-combat-mapper/          <-- clone this repo here
      CombatMapper.au3
      VanquishBot.au3
      lib/
      config.ini.example
      vanquish_config.ini.example
```

1. Install AutoIt **x86** 3.3.16.1+.
2. Clone GwAu3: `git clone --depth 1 https://github.com/GwAu3-Projects/GwAu3.git`
3. Clone this repo into Scripts:

   ```text
   git clone https://github.com/mrdomrocks/gw-combat-mapper.git GwAu3/Scripts/gw-combat-mapper
   ```

4. Copy example configs (or let the launchers copy them on first run):

   ```text
   copy config.ini.example config.ini
   copy vanquish_config.ini.example vanquish_config.ini
   ```

5. Launch Guild Wars, then run **`VanquishBot.au3`** or **`CombatMapper.au3`** as administrator.

Optional CLI:

```text
AutoIt3.exe VanquishBot.au3 -character "YourCharName"
AutoIt3.exe CombatMapper.au3 -character "YourCharName"
```

## Target modes (both bots)

| Target | Behavior |
|--------|----------|
| **Current Map** | Sweep wherever you already are (Hard Mode toggle still applied when possible). |
| **Single title** | LocationsIDS name (e.g. `TravelersVale`, `NorthKrytaProvince`). TravelTo outpost → Hard Mode → GoOut portal route → vanquish route sweep. |
| **(Sequence) campaign caravan** | Portal through spine maps; **Ctrl+click** maps to vanquish. Unselected maps are portal transit only. Sequences: Ascalon, Maguuma, EOTN, Factions, Nightfall. |

## Config

**Travel / coverage / combat:** [`config.ini`](config.ini.example) (copied from `config.ini.example` on first run)

**Hero teams (Vanquish Bot):** [`vanquish_config.ini`](vanquish_config.ini.example)

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

Hero teams are applied automatically before each map based on that map's max party size (4, 6, or 8). Configure Team 4/6/8 in the GUI; selections are saved when you click **Start**.

## Recommended first test (Vanquish Bot)

1. Configure heroes for Team 4/6/8 in the GUI.
2. Select **(Sequence) Ascalon Caravan**; Ctrl+click 1–2 maps (e.g. `NorthKrytaProvince`).
3. Enable **Hard Mode** and **Skip completed**.
4. Start → confirm travel, hero setup, route walk, and vanquish repeat passes.

## Map notes

- **Snake Dance** (from Camp Rankor): early route is tough. A large pack of Stone Summit Dolyak Riders sits near the outpost exit; expect a hard pull before the path opens up.
- **Ice Dome**: map travel to Ice Caves of Sorrow, then Talus Chute to the Ice Dome door.
- **Frozen Forest**: map travel to Iron Mines of Moladune.
- **Ice Floe**: map travel to Thunderhead Keep.

## Combat Mapper CSV columns

`timestamp,map_id,event,x,y` — see [`CombatMapper.au3`](CombatMapper.au3) console help for Log XY and coverage bounds.

## MVR waypoint export

Combat Mapper can convert logged coordinates into Master Vanquisher route snippets:

1. Run a sweep (auto route logging is on by default) or use **Log XY** (F7) for manual points.
2. Click **Export MVR** in the GUI, or run:

   ```text
   python3 scripts/export_waypoints.py <MapID> --title TravelersVale --reverse
   ```

3. Output lands in `exports/<Title>_MVR.au3` with `MoveandAggroVQFullRoute($aWaypoints)` and a reverse pass file.

While the bot runs, player positions append to `logs/map_waypoints_<MapID>.csv` every ~400 units (config `[Log] AutoRouteCoords` / `AutoRouteMinDist`). Use **Export MVR** or splice those points into `lib/maps/Vanquish/` route arrays as needed. Pathfinder handles portal hops on its own — no separate portal walk recording.

## Sweep modes (Combat Mapper)

| Mode | Behavior |
|------|----------|
| **Vanquish Route** | Hand-tuned route from `lib/maps/Vanquish/` with repeat passes until vanquish |
| **Grid Coverage** | Lawnmower grid over Min/Max bounds (or auto-padded player position) |
| **Dynamic Enemy Hunt** | Pathfinder nearest-enemy loop until vanquish or no targets |

## Feature toggles (Combat Mapper GUI)

- **Last Stand (<20)** — wait for manual finish when nearly done after a wipe
- **Consumables** — optional Conset / honeycombs / Bird's Eye Compass at run start
- **Junundu** — auto-mount in Desolation maps
- **Chest log** — append chest spawn coordinates to `logs/chest_spawns_<MapID>.csv`
- **Hero team** — optional hero setup before each map (uses `vanquish_config.ini`)

Per-map coverage bounds are saved to `map_bounds.ini` and auto-loaded when re-entering a zone.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Script cannot find GwAu3 | This folder must be `GwAu3/Scripts/gw-combat-mapper/` (two levels below `API/`). |
| Hard Mode not set | Be party leader in an outpost before GoOut. |
| GoOut fails | Confirm Pathfinder `maps.rar` next to `GWPathfinder.dll`; check console for portal WP lines. |
| No route for map | Confirm the map file exists under `lib/maps/Vanquish/`. |
| Heroes not added | Must be in outpost; configure the matching Team N for map party size. |
| AutoIt crash | Use **32-bit** AutoIt; run as admin. |

## Credits

- [GwAu3](https://github.com/GwAu3-Projects/GwAu3) by JAG-GW (MIT) — game API and Pathfinder.
- Route coordinates were derived from the earlier Guild Wars Vanquish Bot map scripts.
