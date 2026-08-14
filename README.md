# GwAu3 Map Coverage Combat Logger

AutoIt bot that travels (Hard Mode) into explorables using LocationsIDS titles / TOA Ascalon Caravan GoOut routes, lawnmower-sweeps each map, fights via GwAu3 Pathfinder, and logs unique combat-entity coordinates to CSV.

**Use at your own risk.** Automation may violate Guild Wars Terms of Service.

## Requirements

| Requirement | Notes |
|-------------|--------|
| **Windows x86 AutoIt** | AutoIt **3.3.16.1+** in **32-bit** mode (x86). GwAu3 will not work with 64-bit AutoIt. |
| **Guild Wars client** | Logged in (outpost or explorable). Party leader required for Hard Mode. |
| **Pathfinder maps** | First `Pathfinder_Initialize` downloads `maps.rar` next to `GWPathfinder.dll` when online. |
| **Linux / Nobara** | Run GW + AutoIt under **Wine** (Windows prefix) or on a Windows machine. |

## Target modes (GUI)

| Target | Behavior |
|--------|----------|
| **Current Map** | Sweep wherever you already are (Hard Mode toggle still applied when possible). |
| **Single title** | LocationsIDS name (e.g. `TravelersVale`, `AscalonFoothills`). TravelTo outpost → Hard Mode → GoOut portal route → coverage sweep. |
| **(Sequence) TOA Ascalon Caravan** | Portal through early maps to **North Kryta Province**, then **vanquish-style waypoint routes** per map (136 waypoints on NKP from your vanquish bot) with SmartCast + combat logging. Other caravan maps fall back to lawnmower until routes are added. |

Caravan order (from `Caravan_AscalonPlan.au3`):

`TheBlackCurtain → CursedLands → NeboTerrace → NorthKrytaProvince → ScoundrelsRise → GriffonsMouth → DeldrimorBowl → AnvilRock → IronHorseMine → TravelersVale → AscalonFoothills → DiessaLowlands → FlameTempleCorridor → DragonsGullet → TheBreach → OldAscalon → RegentValley → PockmarkFlats → EasternFrontier`

## Layout

```
gw-combat-mapper/
  CombatMapper.au3
  config.ini
  lib/
    Coverage.au3
    CombatLogger.au3
    SmartCast.au3           # Cache_SkillBar / UtilityAI combat casting
    MapCatalog.au3          # LocationsIDS title list + caravan selection
    MapTravel.au3           # Hard Mode, TravelTo, GoOut portal runner
    maps/
      LocationsIDS.au3      # from Guild-Wars-Vanquish-Bot
      Caravan_AscalonPlan.au3
      GoOutRoutes.au3       # extracted vanquish outpost/transit portal paths
  vendor/GwAu3/
  logs/
```

## Setup

1. Ensure `vendor/GwAu3` exists (`git clone --depth 1 https://github.com/GwAu3-Projects/GwAu3.git vendor/GwAu3` if missing).
2. Install AutoIt **x86**.
3. Launch Guild Wars; for caravan/single-map start from any district (bot travels to TOA / outpost).
4. Run `CombatMapper.au3` with 32-bit AutoIt.

Optional CLI:

```text
AutoIt3.exe CombatMapper.au3 -character "YourCharName"
```

## Config

```ini
[Coverage]
GridStep=2000
BoundPad=15000
MinX=0
MaxX=0
MinY=0
MaxY=0

[Combat]
AggroRange=1320
FightRangeOut=3500
CombatRadius=500
SmartCast=1
SmartCastWeaponSets=1

[Travel]
HardMode=1
LastTarget=Current Map

[Log]
Directory=logs
CaravanLogStartMap=NorthKrytaProvince
Directory=logs
```

## Recommended first test

1. Select a **single map** with a known outpost (e.g. `TravelersVale`).
2. Set a **tight AABB** (player ±2000) and Step `1500`.
3. Keep **Hard Mode** checked; be party leader in outpost.
4. Start → confirm travel, GoOut, then `Combat START/END @ (x,y)` lines.
5. Then try **(Sequence) TOA Ascalon Caravan** with wider bounds.

## CSV columns

`timestamp,map_id,event,x,y`

- `event` is `combat_start` or `combat_end`
- `x,y` are the **player** coordinates at that moment (not per-enemy)
- A short grace period (`CombatEndGraceMs`, default 1500) avoids splitting one pack into multiple combats
- New CSV file each sweep (`combat_coords_<MapID>_<timestamp>.csv`)

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Hard Mode not set | Be party leader in an outpost before GoOut. |
| GoOut fails | Confirm Pathfinder maps.rar; check console for portal WP lines. |
| Caravan stuck mid-spine | Dynamic portal may fail on some links; Stop and resume from that title as a single map. |
| AutoIt crash | Use **32-bit** AutoIt; run as admin. |
