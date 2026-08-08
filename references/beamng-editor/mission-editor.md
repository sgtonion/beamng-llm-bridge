# Mission Editor

> **Provenance:** verified against BeamNG.drive v0.39.4.0. The game updates; where
> this doc and the live engine disagree, the engine wins — correct this doc
> when you find rot.
> **Re-verify:** grep `missionEditor.lua` near `:535` for the auto-ID format
> string (`<level>/<missionType>/<NNN>-<Name>`) — confirms the level-first ID
> rule still holds.

Source: `lua\ge\extensions\editor\missionEditor.lua` (+ `missionEditor\` panels),
`lua\ge\extensions\gameplay\missions\missions.lua`. Cross-checked vs
documentation.beamng.com/modding/gamemodes/missions/missioncreation/.

## What a "mission" is

A mission is a **folder** under `/gameplay/missions/<id>/` containing an
`info.json` (the mission definition) plus type-specific assets. The folder path
mirrors the mission **ID**. The mod userfolder mirrors the game tree, so a
mission the editor writes to `<uf>/gameplay/missions/...` maps 1:1 into the repo
at `mods/<your-mod>/gameplay/missions/...` (note it's
`info.json`, NOT `mission.json`).

## Mission ID rule (critical)

The **first path segment of the ID must be the level identifier**, or the mission
won't show on that map's markers. Verified + doc-confirmed.
Editor auto-ID format (`missionEditor.lua:535`):

```
<level>/<missionType>/<NNN>-<Name>
e.g.  west_coast_usa/precisionParking/001-ParallelPark
→ folder /gameplay/missions/west_coast_usa/precisionParking/001-ParallelPark/info.json
```

## Open + create (GUI)

1. `F11` to open the editor (or console `editor.setEditorActive(true)`).
2. **Window → Missions → Mission Editor**.
3. **File → New Mission…** → set Name, ID (auto-ID respects the format above),
   MissionType (`precisionParking` for a parking mission; `flowgraph` for custom).
4. The new mission's **start trigger** defaults to `coordinates` type at the
   camera position + 15 m forward (`missionEditor.lua:562-584`). Reposition later.

## Two things you toggle to actually launch it

In the editor header (per `missionEditor.lua:176-187`):
- **startable** (`assignment_turned_in` icon) — mission is unlocked.
- **visible** (`visibility` icon) — marker shows on the map.
Both must be on. The **flag icon** teleports you to the start trigger, makes it
startable+visible, closes the editor, and opens the mission popup — the fastest
"test it now" path.

## Start trigger / start position

`mission.startTrigger` = `{ type='coordinates', level=<id>, pos={x,y,z},
rot=quat, radius }`. This is the **map-marker / launch location**.
Edit it via the **edit-location button** (`edit_location` icon) → enters
`missionStartPositionEditMode`: **Ctrl+click** in the viewport sets the position;
drag the sphere to move (`missionStartPositionEditor.lua:130-231`). Or script it:
`mission.startTrigger.pos = pos:toTable(); mission._dirty = true`.

> ⚠️ For **precisionParking** the *vehicle* does NOT spawn at `startTrigger.pos`
> — it spawns at the Sites spot named `start`. `startTrigger` only places the
> map marker / entry trigger. See [precision-parking.md](precision-parking.md).

## Attaching a prefab

Two mechanisms exist:
- **Generic** (`missionEditor\prefabs.lua`): `mission.prefabs` = array of prefab
  paths; the panel's "Add" + file picker, or script `table.insert(mission.prefabs,
  "/path/x.prefab.json"); mission._dirty = true`. Optional
  `mission.prefabsRequireCollisionReload`.
- **Fixed-file** (predefined types): the type's `editor.lua` declares a fixed
  filename via `addFixedFile("Obstacles", {"/obstacles.prefab","/obstacles.prefab.json"})`.
  Drop the file at that name **inside the mission folder** and it's picked up.
  precisionParking uses this for obstacles. (`premadetypes` doc: "add a prefab
  file with the already defined file name inside the mission's folder".)

## Save / reload (scriptable API — prefer this)

From `missions.lua`:
- `gameplay_missions_missions.createMission(id, data)` — creates + saves a new
  mission to `/gameplay/missions/<id>/info.json`.
- `gameplay_missions_missions.saveMission(mission, folder)` — writes `info.json`.
- `gameplay_missions_missions.getMissionById(id)` / `.getFilesData()` — read.
- `editor_missionEditor.reloadMissionSystem()` — re-scan after editing files;
  GUI equivalent **File → Reload Mission System**. (Typical reload loop: edit →
  reload mission system, or close editor + `Ctrl+L`.)

See [console-quickref.md](console-quickref.md) for ready snippets.

## Other editor surfaces (stubs — expand as needed)

- **Flowgraph missions** (custom logic, for cases predefined types don't fit):
  type `flowgraph`; logic authored in the Flowgraph Editor
  (`editor\flowgraphEditor.lua`), saved as `<folder>/*.flow.json`.
- **conditions** panel (`missionEditor\conditions.lua`): start/visibility gating.
- **objectives / progress** panels: scoring metadata (telemetry-based scoring
  can be done in Lua instead — so mostly ignore for a first pass).
