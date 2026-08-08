# driving-drills

A checkpoint driving drill for BeamNG.drive, built with the tooling in this
repo. One course ships: **Turns Practice** on `west_coast_usa` — 26 gates
mixing left and right turns, ending in a parallel-parking bay between two
parked cars.

It runs through the game's standalone race runtime, not the mission system:
no countdown, no timer app, no end screen. Gates appear, you drive, and when
the last gate is crossed the parking phase starts. Built to rehearse
road-test maneuvers; verified against BeamNG.drive v0.39.4.0.

## Install

Ask your agent — *"sync the driving-drills mod"* — or run, from the repo
root:

```powershell
pwsh -File .claude\skills\sync-mod\sync-mod.ps1 -Mod driving-drills
```

or copy `mods\driving-drills` into
`%LOCALAPPDATA%\BeamNG\BeamNG.drive\current\mods\unpacked\`.

## Use

Load freeroam on West Coast USA. `scripts/modScript.lua` auto-loads the
extension when the mod is mounted; then from the console (or the bridge):

```lua
extensions.drivingDrills_turnsCourse.start()   -- gates appear, drive
extensions.drivingDrills_turnsCourse.stop()
```

Dev helpers:

```lua
extensions.drivingDrills_turnsCourse.skipToParking()  -- jump to the parking phase
extensions.drivingDrills_turnsCourse.debug()          -- race/parking state probe
```

The four prop cars framing the parking bay persist across start/stop (so an
arrangement survives between runs) and are removed on level exit or
extension unload. After rearranging them in the editor,
`capturePropPoses()` returns their poses in `props.cars.json` entry shape
for vendoring back.

## Files

| Path | What it is |
|---|---|
| `drills/turnsCourse/race.race.json` | The route: pathnodes, segments, recovery positions. Same format the game's Race Editor produces. |
| `drills/turnsCourse/props.cars.json` | Poses of the four parked cars; the parking bay derives from entries 3 and 4, so moving those cars moves the bay. |
| `lua/ge/extensions/drivingDrills/turnsCourse.lua` | The drill: drives `gameplay/race/race` + `scenario/race_marker` directly. |
| `lua/ge/extensions/scenario/raceMarkers/cornerGateMarker.lua` | Custom gate style: four corner pieces outlining a rectangle on the road, ray-cast onto the terrain. |

## Make your own course

The `new-mission` skill in this repo covers the whole path (Tier D): record
poses while driving, convert them with `poses-to-race.ps1`, and start from
`race-drill-template.lua` — a verified copy of the pattern this mod uses.
Alternatively author the route in the in-game Race Editor and point
`RACE_FILE` at its output.

Marker tuning lives at the top of `cornerGateMarker.lua`: gate footprint
(`HALF_WIDTH` / `HALF_LENGTH`), colors per mode, and the corner shape
(other shipped shapes are listed in the file's comments).

## Scope

The drill scores route completion, time, and a held parking position. It
does not judge maneuver *quality* — lane position, signalling, steering
smoothness. That needs a telemetry-scoring extension, which this mod does
not include.
