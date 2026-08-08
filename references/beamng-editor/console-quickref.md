# Console quick-reference (Lua-first editor ops)

> **Provenance:** verified against BeamNG.drive v0.39.4.0. The game updates; where
> this doc and the live engine disagree, the engine wins — correct this doc
> when you find rot.
> **Re-verify:** grep `spawn.lua` for `quat(0,0,1,0)` near the lines cited
> above (`:605`, `:655`) — confirms the pose-flip still applies the same way.

Copy-paste Lua for common editor operations. Console = `~` key.
APIs verified from the editor source; a few (marked 🔍) are
plausible but worth a one-line probe in-game before relying on them — when in
doubt, `dump(x)` it. Prefer these over clicking
menus: they're reproducible and an LLM can emit them directly.

## Editor on/off

```lua
editor.setEditorActive(true)      -- open the world editor (== F11 on)
editor.setEditorActive(false)     -- close it
editor.toggleActive()             -- flip
```

## Show a specific editor window

```lua
editor_sitesEditor.show()         -- Sites editor (parking spots / zones)
editor_missionEditor and editor.showWindow("mission_editor")  -- Mission editor window
-- Traffic Manager window name: open via Window menu; show via its module if loaded.
```

## Teleport / set a vehicle pose (verified in-game 2026-07-30)

Vehicle models are −Y-forward, so every raw pose API wants the **180°-flipped**
("model-frame") quat; higher-level spawn APIs flip internally and want the
natural one. Getting this wrong = car faces backwards (or worse):

```lua
-- Precise pose set (used for placing the player at a captured start pose):
local dir = vec3(0.71, 0.70, 0):normalized()               -- desired forward
local r = quat(0,0,1,0) * quatFromDir(dir, vec3(0,0,1))    -- FLIP required
veh:setPosRot(x, y, z, r.x, r.y, r.z, r.w)

-- core_vehicles.spawnNewVehicle options.rot: pass the NATURAL quat
-- (spawn.lua:605 applies the flip itself).

-- spawn.safeTeleport(veh, pos, rot): takes the natural quat (flips at
-- spawn.lua:655) BUT its setSafePosition pass may override your heading with a
-- road-aligned candidate — unreliable for exact poses; use setPosRot instead.

-- Free camera:
if not commands.isFreeCamera() then commands.setFreeCamera() end
local q = quatFromDir((target - pos):normalized(), vec3(0,0,1))  -- no flip
core_camera.setPosRot(0, pos.x, pos.y, pos.z, q.x, q.y, q.z, q.w)
```

## Create a precisionParking mission (scripted)

```lua
local id = "west_coast_usa/precisionParking/001-ParallelPark"
local cam = core_camera.getPosition()
local fwd = core_camera.getQuat() * vec3(0,15,0)
gameplay_missions_missions.createMission(id, {
  name = "Parallel Park Practice",
  description = "Parallel parking drill.",
  missionType = "precisionParking",
  startTrigger = { type="coordinates", level="west_coast_usa",
                   pos=(cam+fwd):toTable(), rot=quat(0,0,0,1), radius=3 },
  careerSetup = { showInFreeroam = true },
})
editor_missionEditor.reloadMissionSystem()
```

## Read / set a mission's start trigger (map-marker location)

```lua
local m = gameplay_missions_missions.getMissionById(id)
dump(m.startTrigger)                       -- inspect
m.startTrigger.pos = core_camera.getPosition():toTable()   -- set to cam pos
m.startTrigger.rot = core_camera.getQuat()
m._dirty = true
gameplay_missions_missions.saveMission(m, m.missionFolder)
```
> Remember the **dual-start gotcha**: this is the marker/trigger, NOT where the
> car spawns in precisionParking (that's the Sites `start` spot). See
> [precision-parking.md](precision-parking.md).

## Attach a prefab to a mission (generic list)

```lua
local m = gameplay_missions_missions.getMissionById(id)
m.prefabs = m.prefabs or {}
table.insert(m.prefabs, "/gameplay/missions/"..id.."/obstacles.prefab.json")
m._dirty = true
gameplay_missions_missions.saveMission(m, m.missionFolder)
```
> For precisionParking obstacles you can instead just place the file at
> `<missionFolder>/obstacles.prefab.json` (fixed-file pickup) — no list edit.

## Pack selected Scenetree objects into a prefab

```lua
-- After selecting the objects (e.g. two parked cars) in the editor:
local prefab = editor.createPrefabFromObjectSelection(
  "/gameplay/missions/"..id.."/obstacles.prefab.json", "Obstacles")
editor.selectObjectById(prefab:getId())
```

## Spawn an existing prefab

```lua
local p = spawnPrefab(Sim.getUniqueName("obstacles"),
  "/gameplay/missions/"..id.."/obstacles.prefab.json",
  "0 0 0", "0 0 1 0", "1 1 1")     -- name, file, pos, rot(quat as "x y z w"), scale
p.loadMode = 0
scenetree.MissionGroup:addObject(p.obj)
```

## Place a parking spot file (Sites) for the mission

Easiest path is GUI shift-click in the Sites editor then **Save As →
`<missionFolder>/spots.sites.json`**. To save the current sites doc by script
(`saveSites(sites, savePath)` — one combined path, `sitesEditor.lua:25`):
```lua
local s = editor_sitesEditor.getCurrentSites()
editor_sitesEditor.saveSites(s, "/gameplay/missions/"..id.."/spots.sites.json")
```

## Set a vehicle to parked + AI-disabled

```lua
local veh = be:getPlayerVehicle(0)               -- or the placed obstacle veh
veh:queueLuaCommand('ai.setMode("disabled")')    -- stop AI (verified call form)
```
🔍 Parked *config* (`*_parked`) is chosen at spawn/placement time via Traffic
Manager; switching an already-spawned vehicle to a parked config means
respawning it with that config. See [traffic-manager.md](traffic-manager.md).

## Reload loop (no restart)

```lua
editor_missionEditor.reloadMissionSystem()   -- re-scan missions after file edits
-- or close the editor and press Ctrl+L (reload current level/content)
```

## Capture a coordinate while scouting

```lua
core_camera.getPosition()   -- x,y,z of the free cam (F8) — paste into a spawn/spot
core_camera.getQuat()       -- orientation, for heading
```
