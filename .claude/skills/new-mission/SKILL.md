---
name: new-mission
description: Create a playable BeamNG mission/scenario in a mod — parking drill, driving exercise, or other mission type — scaffold it offline, then place its start position, spots, and obstacles live through the bridge. Use when asked to "create a mission", "add a scenario", or "build a driving/parking drill".
---

# New Mission

## Prerequisites

- BeamNG.drive running, in **freeroam** on the target level (not the main menu).
- The bridge extension loaded on demand via `extensions.load("llmBridge_server")`
  in the in-game console (tilde key).
- To run Lua against the game from PowerShell, use the authenticated bundled
  client (fill in `$lua`):

  ```powershell
  pwsh -File .claude/skills/bng-exec/bng-exec.ps1 -Lua $lua
  ```

## Knowledge freshness

Baseline: facts here are VERIFIED against BeamNG.drive v0.39.4.0 unless
a claim carries its own label.
Labels used in this repo: **VERIFIED vX.Y.Z** (ran against that live
build), **SOURCE-READ vX.Y.Z** (read in that build's shipped Lua source),
**UNCONFIRMED** (plausible — probe before trusting; no version, because
nothing was checked). Unlabeled claims are UNCONFIRMED; an inline label
without a version inherits the baseline stamp. Stamps are never
hand-downgraded — an aging build number is itself the staleness signal;
re-verifying a claim updates its stamp.

The game updates and its modding API is unversioned. Where this document and
the live engine disagree, **the engine wins** — re-derive the fact, correct
this file, and update the version stamp. Re-derivation hierarchy, most
authoritative first:

1. The live engine itself — probe it:
   `dump(x)` and `for k,_ in pairs(getmetatable(x).__index or {}) do print(k) end`
2. The game's own Lua source shipped with the install — grep under
   `<steam>\lua\ge\` (your Steam BeamNG install root).
3. Official docs at https://documentation.beamng.com — may lag the shipped build.

## Interview — ask, don't guess

Before scaffolding or touching anything live, resolve these with the user.
Do not assume defaults for any of them:

1. **What maneuver/objective is being practiced?** e.g. reverse parking,
   parallel parking, a slalom, a braking drill, staying in lane through a
   corner — get the actual thing being trained, not just "a mission".
2. **Which level?** The BeamNG level id the mission will live on (e.g.
   `west_coast_usa`).
3. **Is the game running with the bridge loaded?** Live placement (start
   position, spots, obstacles) needs a live game session with
   `llmBridge_server` loaded — confirm before promising anything that depends
   on it. Scaffolding alone can happen offline.
4. **Where should it take place?** Either drive to the spot in-game and park
   there so the live steps can read the pose directly (snippet a), or
   describe the location/landmarks well enough to navigate to it together.
5. **Does the objective fit a known mission type, or does it need custom
   scoring/logic?** This determines which tier below applies. Be honest with
   the user about which path they're on:
   - Fits a mission type this skill has already validated, or one discovered
     live that scaffolds and behaves as expected → **doable in this repo
     now**.
   - Needs scoring or logic no built-in type provides (e.g. grading steering
     smoothness or lane position over time) → **needs a separate spike**,
     out of this skill's scope. Say so up front rather than partially
     building something that can't finish.
6. **How should it start, and how much UI is wanted?** From the mission menu
   with the type's stock flow (countdown/timer/end screen), or on demand with
   just the checkpoint gates and nothing else? This routes between the
   mission tiers (A/B) and the standalone runtime (Tier D) in the capability
   map below.

## Capability map

Route the objective from the interview into one of the tiers below. Be upfront
with the user about which tier applies before scaffolding.

The mission system provides: a mission-menu entry, progress/save files,
medals/stars, and the mission type's stock flow (countdown, timer, end
screen). Pick the tier by what the objective actually needs:

- Wants the menu entry / medals / stock flow → a mission type: Tier A
  (parking, verified) or Tier B (any other type, discovery-driven).
- Wants only "gates appear, drive through them", no stock UI → Tier D
  (standalone race runtime, verified) — a mission is optional there, and the
  two paths can coexist on the same `race.race.json`.
- Wants custom scoring/judgment no built-in provides → Tier C.

### Tier A — verified playbook: precisionParking

The one mission type this skill has been validated against end-to-end, used
here as a **worked example** of the full flow — not the default path for
every request. If the objective is a parking drill, this is well-trodden
ground; see the Tier A section under Live placement below for the
type-specific pieces (spots file, `start`/`0`/`1`/`2` naming).

### Tier B — other built-in mission types (discovery-driven)

For an objective that doesn't fit parking but plausibly fits some other
built-in BeamNG mission type. Nothing below is a known list of type names —
find out live, every time:

1. Enumerate the mission types the running engine actually knows about by
   probing the mission-system table live (the same `dump(x)` /
   `pairs(getmetatable(x).__index or {})` idiom from Knowledge freshness,
   pointed at the mission-system object and whatever type registry it
   exposes). Do not assume a getter name in advance — read what the dump
   gives you.
2. From the enumerated names, pick the candidate whose name/description best
   matches the objective from the interview.
3. Scaffold with that type via `-Type <discovered-name>` (see Scaffold,
   below).
4. Before trusting anything about it, probe what data/files that type
   expects — its fixed files, its editor fields, any per-type file it reads
   (the same way Tier A's snippet c probes `spots.sites.json`'s shape before
   writing to it). Everything on this path is **UNCONFIRMED** until you've
   probed it against the live engine; do not carry Tier A's specifics
   (spots file, `start` naming) over to a Tier B type without separately
   confirming that type works the same way.

#### timeTrial specifics — VERIFIED (v0.39.4.0, 2026-08)

A second type has been taken end-to-end since Tier A was written. Facts that
cost real time, all confirmed live:

- `missionTypeData.defaultLaps` is **required** or the mission fails to
  construct (`gameplay/missionTypes/timeTrial/constructor.lua:42`) and never
  appears in the mission list. The scaffolder does not add it.
- The route lives in `race.race.json` next to `info.json`. On disk,
  `pathnodes` / `segments` / `startPositions` are **plain arrays** — never
  copy the runtime object's shape (it exposes `.sorted`, and a file in that
  shape parses as zero pathnodes with no error and no gates). Read a shipped
  mission's file for the format.
- Segments chain the route: `{name, from = <oldId>, to = <oldId>,
  mode = "waypoint", capsules = {}, oldId}` — node references are pathnode
  **`oldId`**, not indices. Shipped files use `endNode = -1`.
- Every pathnode needs its own forward/reverse entries in `startPositions`,
  with `recovery`/`reverseRecovery` pointing at them. With `recovery = -1`
  the engine places that gate's columns exactly **10 m underground**.
- The validator's `has N issues:` lines in `beamng.log` are the authoritative
  list of missing **and extra** `missionTypeData` keys — the flowgraph's
  `variables.list` is incomplete, so don't derive keys from it. (timeTrial
  rejects `useProvidedVehicle`, which the scaffolder adds for parking.)
- Marker style cannot be chosen from the mission JSON — the timeTrial
  flowgraph calls `setupMarkers(wps)` with no style argument. To force a
  custom style during a mission, wrap the function from an extension while
  the mission runs (apply on mission start, revert on mission end). Patch
  `setupMarkers`, **not** `createRaceMarker` — `setupMarkers` calls a
  module-*local* `createRaceMarker`, so replacing the exported field is dead
  code:

  ```lua
  local rm = require("scenario/race_marker")
  local orig = rm.setupMarkers
  rm.setupMarkers = function(wps, style) return orig(wps, style or "myMarker") end
  -- on mission end: rm.setupMarkers = orig
  ```

  A custom style is a module at `scenario/raceMarkers/<name>.lua` (place it
  under the mod's `lua/ge/extensions/`) returning a factory function whose
  instances implement: `createMarkers()` (**idempotent** — setupMarkers
  calls it twice), `clearMarkers()`, `setToCheckpoint(wp)`, `setMode(mode)`,
  `show()`, `hide()`, `update(dt, dtSim)`, optional `drawOnMinimap(td)`.
  (Tier D callers never need this patch — when you call `setupMarkers`
  yourself, pass the style name as the second argument.)

### Tier C — custom behavior

An objective whose scoring or logic isn't something a built-in mission type
provides (e.g. grading steering smoothness, lane position, or any other
telemetry-based judgment over time) needs a custom GE-Lua extension watching
the vehicle and computing that judgment itself — that's out of this skill's
scope. Say so plainly to the user and stop cleanly rather than force-fitting
a built-in type that can't actually score the thing being asked for.

### Tier D — checkpoint drill via the standalone race runtime — VERIFIED

For "gates appear, drive through them" with none of the mission system's
stock UI (no countdown, timer, or end screen). The mission/flowgraph layer is
a thin wrapper over two plain classes that any GE extension can drive
directly (this is exactly what the flowgraph nodes `filePath` / `fileRace` /
`raceMarkers` do internally):

```lua
local path = require('/lua/ge/extensions/gameplay/race/path')("name")
path:onDeserialized(jsonReadFile(raceFile)); path:autoConfig()
local race = require('/lua/ge/extensions/gameplay/race/race')()
race:setPath(path); race.useHotlappingApp = false
race:setVehicleIds({vehId}); race:startRace()
-- per frame: race:onUpdate(dtSim) in onUpdate;
--            race_marker.render(dt, dtSim) in onPreRender
```

A complete working extension implementing this pattern is bundled in this
skill folder: **`race-drill-template.lua`** (verified live end-to-end). Copy
it to `mods/<mod>/lua/ge/extensions/<ns>/<name>.lua`, set `RACE_FILE` to the
route file (authored via the mark-loop + `poses-to-race.ps1`, snippet h, or
the in-game Race Editor), optionally set `MARKER_STYLE`, deploy, and load.
It includes start/stop, marker-mode updates, completion detection, and a
`debug()` probe for bridge-side verification.

Facts that matter on this path:

- The route file is the same `race.race.json` as timeTrial (see the timeTrial
  specifics under Tier B for its on-disk format) — one route file can serve
  both a Tier B mission and a Tier D starter.
- `race_marker.setupMarkers(wps, styleName)` takes a marker style name
  directly when you are the caller — no patching needed (the patch is only
  required when the mission flowgraph calls it, since it passes no style).
- `race.useHotlappingApp = false` removes the last piece of stock UI.
- Traps: `race_marker.idToMarker` is a stale export (reads empty while
  markers render — never probe it); `scenetree.ScenarioObjectsGroup` doesn't
  exist in freeroam; a freshly armed race hides pathnode 1 (it's the start
  line — gate 2 being the first visible target is correct).

## Scaffold

Run the bundled scaffolder from this skill folder:

```powershell
pwsh -File create-mission.ps1 -Mod <mod> -Level <level> -Name <name> -Type <type> [-Title <display>]
```

- `-Mod`, `-Level`, `-Name`, `-Type` are all required. `-Mod`/`-Name` are
  lowercase kebab-case (e.g. `reverse-park`); `-Level` is a BeamNG level id,
  lowercase with underscores (e.g. `west_coast_usa`); `-Type` comes out of
  the interview above — `precisionParking` for the Tier A worked example, or
  the type name discovered live for Tier B.
- `-Title` defaults to the title-case form of `-Name` (e.g. `reverse-park` ->
  `Reverse Park`).
- If `mods\<mod>` doesn't exist yet, the script creates it with a minimal
  `info.json` so BeamNG's mod manager registers it.
- The mission gets a zero-padded three-digit number, auto-incremented per
  `<level>/<type>/` folder (`001`, `002`, …).
- **Fail-safe**: if the target mission folder already exists, the script
  errors out and exits 1 rather than overwriting anything.

The scaffold pre-applies two known launch fixes and two stand-in files so a
freshly created mission is close to launchable, not just present on disk:
`setupModules.vehicles` (with `enabled`, `includePlayerVehicle`, and
`prioritizePlayerVehicle` all true) exempts the player's car from the
mission-start vehicle stash that would otherwise leave it invisible;
`missionTypeData.useProvidedVehicle = false` stops the mission's internal
logic from forcing a different default vehicle; and placeholder
`obstacles.prefab.json` / `intro.camPath.json` files satisfy fixed-file checks
that would otherwise hang the mission on a black screen. These two fixes are
verified for `precisionParking`; treat them as a starting point rather than a
guarantee for a Tier B type until you've confirmed that type reads the same
fixed files. What the scaffold cannot pre-create is a type's own extra
per-type file (Tier A's **spots file** — see below — or whatever a Tier B
type turns out to need) or a real start position — those need a live game
session and are done in Live placement, below.

## Deploy + register

```powershell
robocopy "<repo>\mods\<mod>" "$env:LOCALAPPDATA\BeamNG\BeamNG.drive\current\mods\unpacked\<mod>" /MIR
```

Then in the in-game console:

```
extensions.load("llmBridge_server")
```

and to make the game pick up the new mission files:

```lua
gameplay_missions_missions.reloadCompleteMissionSystem()
```

## Live placement

The snippets below (a, b, d, e, f, g) are verified against the live engine
and are type-agnostic — they apply regardless of which tier the mission came
from. Parameterize and compose these, then send each through the embedded
one-liner — one statement or a short script per call, so you can check the
result before the next step. `<id>` below always means the mission id, e.g.
`west_coast_usa/precisionParking/001-ReversePark`.

### a. Read the live vehicle pose — VERIFIED

```lua
local veh = be:getPlayerVehicle(0)
return { pos = veh:getPosition():toTable(),
         fwd = veh:getDirectionVector():toTable(),
         up  = veh:getDirectionVectorUp():toTable() }
```

Gotcha: never take pose from `veh:getSpawnWorldOOBB()` — its center/axes are
frozen at spawn time and go stale the moment the car moves. Only its sizes
(`getHalfExtents`) stay valid.

### h. Capture an ordered pose list by driving — the mark-loop — VERIFIED

For content that is a *sequence* of placements (checkpoint gates, slalom
cones, spot rows), let the user author it by driving: they drive the course
and stop at each point; each time they say "mark" in chat, run:

```lua
local veh = be:getPlayerVehicle(0)
local p, d = veh:getPosition(), veh:getDirectionVector():normalized()
local q = quatFromDir(d, vec3(0,0,1))
return { pos = p:toTable(), normal = d:toTable(), rot = {q.x, q.y, q.z, q.w} }
```

Append each result to an ordered JSON array in a working file (add a `name`
per entry when useful), and read back confirmation the user can act on
("gate 4 captured, 32 m from gate 3") so mistakes surface immediately —
re-capture by replacing the last entry. When the drive is done, feed the
list to the writer for whatever the content is:

- **Checkpoint route** (a timeTrial mission or a Tier D drill) →
  `poses-to-race.ps1`, bundled in this skill folder, turns the list into a
  `race.race.json`:

  ```powershell
  pwsh -File poses-to-race.ps1 -Poses poses.json -Out race.race.json -Name "My Drill" [-Closed]
  ```

  It encodes the verified format traps (plain arrays, `oldId` chaining,
  per-node recovery entries) and was validated by regenerating a
  live-verified route file identically. `-Closed` adds the last→first
  segment for lap courses.
- **Parking spots** (Tier A) → the sites file, snippet c (its spot-naming
  rules apply).
- **Obstacles** → spawn a vehicle at each captured pose (snippet e), then
  pack the selection (snippet f).
- **A mission type with its own placement file** → probe its format first
  (Tier B rules), then add a writer for it beside `poses-to-race.ps1` once
  verified.

#### Manual alternative — the in-game Race Editor — SOURCE-READ

If the user prefers placing gates by hand over the chat mark-loop, the world
editor (F11) ships a native Race Editor for exactly these `.race.json` files
(`editor/raceEditor.lua`; edit mode "Edit Races"). Open the world editor,
then find the Race Editor in the editor's window/tools menus — or run
`editor_raceEditor.show()` in the console once the editor is open
(`editor_raceEditor` is nil until the editor has initialized). It offers
viewport pathnode placement plus dedicated windows for pathnodes, segments,
and start positions, and its tools menu automates the format traps:
**"Add Missing Recovery Positions"** (the recovery trap), "Recalculate
Segments", "Organize Pathnode and Segment Names". File → Save as writes the
same on-disk format the writers above produce; consumers (a timeTrial
mission or a Tier D drill) read the file identically regardless of which
path authored it.

Caveat: like all in-game editors it saves to the BeamNG **userfolder**, not
the repo — vendor the saved file back into `mods\<mod>\...` before the next
repo→userfolder sync clobbers it (and remember the userfolder copy shadows
the mod's copy in the VFS until deleted).

### b. Set the mission startTrigger from that pose — VERIFIED

```lua
local m = gameplay_missions_missions.getMissionById("<id>")
local veh = be:getPlayerVehicle(0)
m.startTrigger.pos = veh:getPosition():toTable()
m.startTrigger.rot = quatFromDir(veh:getDirectionVector(), vec3(0,0,1))
m._dirty = true
gameplay_missions_missions.saveMission(m, m.missionFolder)
```

Gotcha: `startTrigger` is only where the map marker / entry trigger appears
— true for every mission type. For the Tier A precisionParking worked
example specifically, the actual **driving start** is the Sites spot named
`start` (see Tier A, below) — two different concepts, do not conflate them;
for a Tier B type, confirm live whether it has an equivalent split before
assuming `startTrigger` alone places the vehicle. No 180-degree flip is
needed here: `startTrigger.rot` and camera/trigger quats use the natural
(unflipped) orientation; the flip in vehicle placement only applies to
`veh:setPosRot`, not to triggers.

### d. quatFromDir for look-at rotations — VERIFIED

```lua
local q = quatFromDir((target_pos - from_pos):normalized(), vec3(0,0,1))
```

Use this to orient a target parking spot, a camera marker, or a startTrigger
toward a point of interest — pass the normalized direction vector and the
world-up axis.

### e. Spawn a parked, AI-disabled obstacle vehicle — VERIFIED

```lua
local v = core_vehicles.spawnNewVehicle("simple_traffic", {
  config = "vehicles/simple_traffic/bastion_base_parked.pc",
  pos = <pos_vec3>, rot = <natural_quat>, autoEnterVehicle = false,
})
v:queueLuaCommand('ai.setMode("disabled")')
```

Gotcha: parked `*_parked.pc` configs all live under the `simple_traffic`
model (not under `bastion`, `covet`, etc. directly) — spawn the
`simple_traffic` model with the parked config path, not the base vehicle
model. A parked vehicle is not drivable, which is exactly what's wanted for a
static obstacle car. If `spawnNewVehicle` doesn't hand back a usable vehicle
object in `v`, look it up before the `queueLuaCommand` call (e.g. by scanning
`getAllVehicles()` for the one just placed) rather than assuming the return
value.

### f. Pack selected objects into obstacles.prefab.json — VERIFIED

```lua
local prefab = editor.createPrefabFromObjectSelection(
  "/gameplay/missions/<id>/obstacles.prefab.json", "Obstacles")
editor.selectObjectById(prefab:getId())
```

Select the placed obstacle vehicles (and any other scenery) in the Scenetree
first, then run this. It overwrites the scaffold's placeholder
`obstacles.prefab.json` with the real packed content — same filename, so no
other reference needs to change.

### g. Read-back verification — VERIFIED

```lua
return dumps(gameplay_missions_missions.getMissionById("<id>").startTrigger)
```

Compare the dumped `pos`/`rot`/`level` against what you intended to set in
step b before moving on. Do the same for any type-specific file (e.g. the
Tier A sites file) by re-loading it if in doubt.

For anything not covered above, probe the live engine instead of guessing
method names:

```lua
dump(x)
for k,_ in pairs(getmetatable(x).__index or {}) do print(k) end
```

### Tier A worked example — precisionParking

This is the one mission type this skill has been validated against; treat it
as a concrete example of how a type-specific step works, not as what every
mission type does.

#### c. Create the mission's sites file (start spot + target spot)

The save/load pair is verified; the exact per-spot field layout is not, so
probe it live once before scripting spot creation:

```lua
-- 1) In the Sites Editor (Parking Spots tab), shift-click in the viewport
--    once to drop a single spot, then inspect its real fields:
dump(editor_sitesEditor.getCurrentSites())
```

Use the dumped shape to see the actual field names (position, rotation,
scale, name) before writing more spots by hand or by script. Then save with
the verified call:

```lua
local sites = editor_sitesEditor.getCurrentSites()
-- add/edit spots on `sites` here, matching the shape you just dumped
editor_sitesEditor.saveSites(sites, "/gameplay/missions/<id>/spots.sites.json")
```

Labeling: `getCurrentSites()`/`saveSites()` themselves — **VERIFIED**. The
per-spot field layout you get back from the dump — **UNCONFIRMED**, probe
first.

Gotcha: `precisionParking` expects exact naming — one spot literally named
`start` (where the vehicle is teleported and the player begins), and target
spots numbered from `0` upward (`0`, `1`, `2`, …). The file must be saved at
`<missionFolder>/spots.sites.json` — that exact filename is hardcoded by the
mission type, so any other name is silently ignored. The Parking Spots tab's
default scale preset for a new spot is sized for a car (roughly 2.5 x 6 x 3
in width/length/height) — fine as-is for a single vehicle spot.

## Vendor back

The in-game Mission Editor, Sites Editor, and Scenetree all write to the
BeamNG **userfolder**, never to the repo. After any live placement above
(startTrigger, type-specific files, packed prefab), run:

```powershell
pwsh -File vendor-mission.ps1 -Mod <mod> -MissionId <level>/<type>/<NNN>-<Name>
```

This mirrors the userfolder's copy of the mission folder into
`mods\<mod>\gameplay\missions\...` in the repo so the authored content is
actually saved. Use `-DryRun` to preview first. If the source folder isn't
found, the in-game editor hasn't saved the mission yet (File -> Save Mission).

## Launch + verify

Launch the mission from **inside freeroam** (open the mission menu, pick it,
start it) — never from the main menu. A main-menu launch does a full level
reload, which discards the current vehicle and spawns the game's default one
instead, defeating the "use the player's own car" setup.

| Symptom | Check |
|---|---|
| Car invisible after mission start | Is the `setupModules.vehicles` block in `info.json` intact (`enabled`, `includePlayerVehicle`, `prioritizePlayerVehicle` all true)? |
| Black screen, mission never starts | Are both fixed files present — `obstacles.prefab.json` and `intro.camPath.json` (and, for a Tier A precisionParking mission, `spots.sites.json`)? For a Tier B type, confirm which files it actually fixed-checks before assuming these two are enough. |
| Wrong vehicle spawns | Is `missionTypeData.useProvidedVehicle = false` present? Was the mission launched from freeroam, not the main menu? |
| Log line `Ignoring Mission Variable "X"` | The `missionTypeData` key name doesn't match a real flow-graph variable — check the `variables.list` array inside the mission's `.flow.json` for the actual name and correct the key. |
