---
name: debug-mission-launch
description: Diagnose a broken BeamNG mission launch (invisible player car, screen stuck on black after the start fade, the wrong default vehicle spawning, or checkpoints/markers never appearing) using log tracing and a live game query, then apply one of five known engine-behavior fixes. Use when a mission "starts" but visibly doesn't work, or when edits to mission files appear to do nothing.
---

# Debug Mission Launch

Diagnoses BeamNG mission launches that appear broken: the mission reports as
started but the player vehicle is invisible, the screen stays black after the
start fade, or a wrong/default vehicle spawns instead of the intended one.
These are caused by specific, reproducible engine behaviors in
`missionManager` and the flow-graph system — not random bugs — and each has a
durable fix.

## Prerequisites

- BeamNG.drive running on Windows.
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

## Section 1 — Diagnose (the recipe)

Run these three steps in order. Steps 1 and 2 identify which of the four
failure modes below is active; step 3 gets the game back into a clean state
so a fix can be re-tested.

1. **Grep `beamng.log`** for the flow-state trace and for file-integrity
   errors:
   - `Starting state|Transition:` — a state that starts and never transitions
     to the next one is the hang point (see Failure Mode 2).
   - `has N issues` — indicates missing declared files (fixed files the
     mission's `editor.lua` requires but that don't exist on disk).

2. **Query the live game** through the embedded HTTP one-liner above. Set
   `$lua` to each of the following in turn:
   - `'return gameplay_missions_missionManager.getForegroundMissionId()'`
     — confirms a mission is actually active.
   - `'local veh = be:getPlayerVehicle(0); return veh and veh:getActive()'`
     — `false` means the vehicle exists but is deactivated (stashed).
   - `'local veh = be:getPlayerVehicle(0); return veh and veh:getPosition()'`
     — confirms whether the vehicle is at the correct spawn spot.
   - Camera position/name (e.g. `'return getCameraPosition()'` or the active
     camera name) — separates "vehicle not spawned" from "vehicle spawned but
     stashed" from "camera is pointed elsewhere while the vehicle is fine".

3. **Unstick remotely** once the cause is known, then re-test:
   - `'gameplay_missions_missionManager.stopForegroundMissionInstantly()'`
     stops the mission and also un-stashes any stashed vehicles.
   - After syncing a fix to disk, run
     `'gameplay_missions_missions.reloadCompleteMissionSystem()'` to pick it
     up without restarting the game.
   - A **brand-new mod folder** is invisible to `reloadCompleteMissionSystem()`
     until `core_modmanager.initDB()` has run once — run that first when the
     mission doesn't appear at all.
   - `getMissionById()` can return a stale cached object — the authoritative
     signal is `beamng.log` (diff its line count before/after an action).

**If edits to a mission file appear to do nothing** (fields read back `nil`
while the file plainly contains them): `saveMission()` writes a shadow copy
to the userfolder at `current/gameplay/missions/<level>/<type>/<id>/` that
**overrides** the mod's copy in the VFS. Delete the shadow folder and re-run
`core_modmanager.initDB()`. Corollary: vendor live-placed data back to the
repo *before* the next repo→userfolder sync, or the sync clobbers it.

## Section 2 — The five known failure modes

### 1. The player-vehicle stash (car invisible at spawn)

At mission start, `missionManager` **stashes every active vehicle** on the
map via `setActive(0)` — the vehicle still exists in telemetry but is
invisible in the world. The vehicle-setup step then exempts the vehicle the
player will drive from this stash — **but only if
`setupModules.vehicles.enabled` is true**. A mission `info.json` that omits
that module entirely skips the exemption: the player's car is placed
correctly at the mission's start spot and then left deactivated. Un-stash
only happens when the mission stops.

**Fix — to use the player's own car** (no separately provided vehicle),
set `info.json`:

```json
"setupModules": {
  "vehicles": {
    "enabled": true,
    "includePlayerVehicle": true,
    "prioritizePlayerVehicle": true,
    "vehicles": []
  }
}
```

An empty `vehicles` list combined with `includePlayerVehicle: true` makes the
player's car the only and default choice, and the stash exemption runs for
it. (Stock missions instead provide a vehicle via a non-empty `vehicles`
list.)

**Debug signature**: mission reports active, `veh:getPosition()` is correct,
`veh:getActive()` is `false`. Calling `setActive(1)` live gets the vehicle
re-stashed by the next setup step — the `info.json` fix above is the only
durable one.

### 2. Declared fixed files are load-bearing (flow hangs on black screen)

A mission's flow graph assumes every fixed file declared in its `editor.lua`
actually exists. If files such as `intro.camPath.json` or
`obstacles.prefab.json` are missing, the state machine enters a "Setup
Vehicle" state and never leaves it — the start fade to black never reverses,
and the game appears frozen. The mission-issues log lines reading
`Fixed File set for X does not exist` are **errors to fix, not warnings to
ignore**.

Minimal valid stand-ins to unblock the flow until real content exists:

- `obstacles.prefab.json` — a single line is sufficient:
  ```json
  {"name":"SimGroup_","class":"SimGroup","groupPosition":"0 0 0"}
  ```
- `intro.camPath.json` — a minimal 2-marker structure:
  ```json
  {
    "looped": false,
    "manualFov": false,
    "markers": [
      {"fov": 60, "pos": {"x":0,"y":0,"z":0}, "rot": {"x":0,"y":0,"z":0,"w":1},
       "time": 0, "trackPosition": 0, "movingStart": false, "movingEnd": false},
      {"fov": 60, "pos": {"x":0,"y":0,"z":0}, "rot": {"x":0,"y":0,"z":0,"w":1},
       "time": 1, "trackPosition": 1, "movingStart": false, "movingEnd": false}
    ]
  }
  ```
  Compute look-at rotations for each marker in-game with
  `quatFromDir((target - campos):normalized(), vec3(0,0,1))` and substitute the
  result into that marker's `rot`.

### 3. Flow-graph variable defaults can force a provided vehicle

A mission's `.flow.json` may declare defaults such as
`useProvidedVehicle = true` together with a specific default model/config —
so even with the stash fix from Failure Mode 1 applied, the flow itself
spawns that default vehicle instead of using the player's car. Any
`missionTypeData` key in `info.json` whose name matches a flow-graph variable
overrides that variable at runtime (`flowMission.lua` → `addOrSetVariable` →
`changeBase`). Fix:

```json
"missionTypeData": { "useProvidedVehicle": false }
```

**Warning — silent-failure signature**: the log line
`Ignoring Mission Variable "X" - The variable does not exist in the FG` means
a `missionTypeData` key silently did nothing, because the name doesn't match
any real flow-graph variable. Editor field names can differ from the
underlying flow-graph variable names — always check the `variables.list`
array inside the mission's `.flow.json` for the real names before setting
`missionTypeData` keys.

### 4. Launching from the main menu spawns the default vehicle

Starting a mission from the **main menu** does a **full level reload**,
which discards the current session's vehicle and spawns the game's default
vehicle instead (`settings/default.pc` in the userfolder; if that's unset,
the factory fallback is the D15 pickup — log signature:
`core_vehicles.main| Loading default vehicle`). Any "use the player's
vehicle" logic then faithfully uses that freshly spawned default, which is
rarely the intended practice vehicle.

Fixes (either one, or both):

- Launch the mission from **inside freeroam** instead of the main menu
  (open the mission menu, pick the mission, start it — this does not reload
  the level).
- Make the intended practice car the default vehicle: enter it in-game and
  call `core_vehicle_partmgmt.savedefault()`, which writes
  `settings/default.pc` in the BeamNG userfolder
  (`$env:LOCALAPPDATA\BeamNG\BeamNG.drive\current\` on Windows).

### 5. Programmatic launch never arms the gameplay flowgraph — VERIFIED

Launching a mission with
`gameplay_missions_missionManager.startWithFade("<id>")` (or similar
programmatic entry) **enters** the mission — checkpoints even detect — but
the Race flowgraph never arms: `raceData` stays `false`, `vehId` is `nil`,
and **zero markers appear**. This reproduces on BeamNG's own shipped
missions (verified on `007-Street`), so it is NOT evidence that an authored
mission is broken. Repeated programmatic launches also stack flowgraph
managers, after which only a full game restart cleans up.

**Fix**: for any gameplay verification, start the mission from the in-game
mission menu (from inside freeroam). Reserve programmatic launches for
nothing — there is currently no known safe use.

**Debug signature**: mission id is foreground, checkpoint triggers fire, but
no gates/markers render and the race flowgraph reports inactive.
