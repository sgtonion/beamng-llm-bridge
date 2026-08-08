# Precision Parking mission type

> **Provenance:** verified against BeamNG.drive v0.39.4.0. The game updates; where
> this doc and the live engine disagree, the engine wins — correct this doc
> when you find rot.
> **Re-verify:** grep `parking.flow.json` for `parkingbrake`/`handbrake`
> (expect zero hits) — confirms the end condition is still accurate-stop +
> time, not the handbrake.

Source (primary — docs are silent on these specifics):
`<steam>\gameplay\missionTypes\precisionParking\` —
`editor.lua` (editor panel/fields), `constructor.lua` (runtime instance),
`parking.flow.json` (8.7k-line flow graph), `customNodes\parkingPointsNode.lua`
(scoring). This is the built-in type a custom precisionParking mission reuses
instead of scripting one from scratch.

## Files inside a precisionParking mission folder

Declared by `editor.lua` `addFixedFile(...)` — fixed names, dropped inside
`/gameplay/missions/<id>/`:

| File | Purpose | Authored with |
|------|---------|---------------|
| `info.json` | mission definition (all types) | Mission Editor |
| `spots.sites.json` | parking spots incl. the `start` spawn | **Sites Editor** ([sites-editor.md](sites-editor.md)) |
| `obstacles.prefab.json` | the parked-car obstacle set | Scenetree **Pack Prefab** ([prefab-and-scenetree.md](prefab-and-scenetree.md)) |
| `intro.camPath.json` | optional intro camera flythrough | Camera Path editor (optional) |

`constructor.lua:19` hardcodes the spots path as
`gameplay/missions/<id>/spots.sites.json` — so the spots file is **per-mission**,
not shared.

## Editor fields (precisionParking `editor.lua`)

`Available Time` (default 60 s), `Max Points` (~20 × #spots), `Gold/Silver/Bronze
Points` (100/85/50), `Flip Limit`/`Flip Penalty`, plus the provided-vehicle
toggle. These are cosmetic if the built-in score isn't used.

## Parking spots: the `start` convention

From `editor.lua` deco text + `parking.flow.json` (nodes 305/310 use
`gameplay/sites/parkingspotByName` with `spotName="start"`):
- Place spots in the **Sites Editor**, saved to the mission's `spots.sites.json`.
- **One spot must be named `start`** — the vehicle is teleported there and the
  player enters it at mission begin (flow graph "Setup Ui" state).
- **Target spots are numbered from 0**: `0, 1, 2, …` (5 spots → `0..4`).
- Optional per-spot numeric field **`onlyForward = 1`** requires correct
  orientation (not nose-in-backwards). Useful later; for a single parallel-park
  target, one numbered spot is enough.

## The dual-start gotcha

There are **two** independent "start" concepts — do not conflate:
1. `mission.startTrigger.pos` (in `info.json`) = where the **map marker / launch
   trigger** sits. Set via the Mission Editor's edit-location mode.
2. Sites spot named `start` (in `spots.sites.json`) = where the **vehicle
   actually spawns** once the mission begins.

For a parallel-park setup, put the `start` spot behind/alongside the lead parked
car, facing along the curb. The `startTrigger` can sit nearby (it just needs to
be on the map to show the marker).

## End condition (not the handbrake)

**Answered from source — no in-game spike needed.** The
mission does **not** end on handbrake, and there is **no parkingbrake/handbrake
node anywhere** in `parking.flow.json` (grep confirmed). Instead:

- **Start** of the attempt: `gameplay/playerMoves` node = *"Detect Acceleration
  At Start"* — the timer/attempt begins when the vehicle moves >0.1 m from its
  spawn (`playerMoves.lua:54`). It is a **start** trigger, not an end.
- **Scoring**: `parkingPointsNode.lua` grades each spot by **orientation error**
  (`dotAngle`), **lateral offset** (`sideDist`), and **fore/aft offset**
  (`forwardDist`) → 0–20 pts. Good park ≈ side <0.18 m / fwd <0.22 m / angle
  <1.6°; bad ≈ side >0.55 m / fwd >0.75 m / angle >7.5°.
- **End**: the flow is a state machine bounded by `Available Time` and by the
  vehicle settling accurately in the spot(s). It ends on **accurate-stop +
  time**, NOT on the parking brake.

**Implication:** "ends when handbrake is set" is NOT a
built-in behavior. Two options:
- If the accurate-stop end is acceptable → use it as-is, no code.
- If a handbrake-specific end is required → bridge with a small GE-Lua extension
  polling `electrics.values.parkingbrake` (≈1.0) on the player vehicle and ending
  the mission. (That field name is still an in-game console probe — verify before
  coding.)

## Build order

1. Place + park-config two cars → **Pack Prefab** → `obstacles.prefab.json`
   ([traffic-manager.md](traffic-manager.md) + [prefab-and-scenetree.md](prefab-and-scenetree.md)).
2. New `precisionParking` mission, ID `west_coast_usa/precisionParking/001-…`
   ([mission-editor.md](mission-editor.md)).
3. Sites Editor → add spot `start` (behind lead car) + spot `0` (the gap) →
   save to the mission's `spots.sites.json` ([sites-editor.md](sites-editor.md)).
4. Drop `obstacles.prefab.json` into the mission folder (fixed-file pickup).
5. Make startable + visible, close editor, `Ctrl+L`, launch from the marker.
6. Vendor the folder into `mods/<your-mod>/gameplay/missions/west_coast_usa/...`.
