# Prefabs + Scenetree

> **Provenance:** verified against BeamNG.drive v0.39.4.0. The game updates; where
> this doc and the live engine disagree, the engine wins — correct this doc
> when you find rot.
> **Re-verify:** grep `sceneTree.lua` for `PrefabV2():pack` — confirms Pack
> Prefab still emits `.prefab.json`, not the doc-recommended legacy `.prefab`.

Source: `lua\ge\extensions\editor\sceneTree.lua`,
`...\editor\missionEditor\prefabs.lua`. Doc:
documentation.beamng.com/world_editor/tools/prefabs/ +
.../windows/scenetree/.

A **prefab** bundles a set of placed objects (e.g. two parked cars) into one
reusable, re-spawnable asset. For a precisionParking mission the parked-car set is
packed into `obstacles.prefab.json` inside the mission folder.

## File format: `.prefab.json` (what the editor actually writes)

Two formats exist: `.prefab` (legacy/TorqueScript) and `.prefab.json` (current
JSON). **Doc says `.prefab` is "currently recommended."** **But the current
editor source emits `.prefab.json`**: `sceneTree.lua` packs via
`PrefabV2():pack(objects):save(path)` and the legacy path
`editor.createPrefabFromObjectSelection(...)` also offers only
`{"Prefab Files (JSON)",".prefab.json"}`. A real shipped example found in the
source comments: `/gameplay/missions/west_coast_usa/precisionParking/005-limoparking/obstacles.prefab.json`.

→ **Use `.prefab.json`** (it's what Pack Prefab produces and what gets vendored).
precisionParking's `editor.lua` accepts *either* name (`obstacles.prefab` OR
`obstacles.prefab.json`), so `.prefab.json` works. Footnote: if a future BeamNG
version flips the default, re-check — docs prefer `.prefab`.

## Packed vs unpacked

- **Packed** = compiled, game-ready, a single Scenetree node with a package icon.
- **Unpacked** = editable; its child objects are exposed in the Scenetree.
- **Repacking an unpacked prefab auto-saves the file.** (doc)

## Pack workflow (GUI — Scenetree right-click)

1. Place the objects (two cars — see [traffic-manager.md](traffic-manager.md)).
2. Select them in the Scenetree (or viewport).
3. Right-click → **Put Into New Group** (`sceneTree.lua:1496`) to group them.
4. Right-click the group → **Pack Prefab** (`sceneTree.lua:1648`) → file dialog →
   save as `obstacles.prefab.json` in the mission folder.
   - This replaces the group with a packed prefab instance node.

## Spawn / re-spawn a prefab

- GUI: Asset Browser → locate the `.prefab.json` → spawn at intended position; or
  the mission Prefabs panel's **Spawn** button (`prefabs.lua:58`).
- Script (`prefabs.lua:60-65`):
  ```lua
  local p = spawnPrefab(Sim.getUniqueName("myPrefab"), "/path/obstacles.prefab.json",
                        "0 0 0", "0 0 1 0", "1 1 1")  -- name, file, pos, rot, scale
  p.loadMode = 0
  scenetree.MissionGroup:addObject(p.obj)
  editor.selectObjectById(p.obj:getId())
  ```
  > **Correction (2026-07-30, verified in-game):** for legacy JSON-lines prefabs
  > the `rot` arg is a Torque **axis-angle string `"x y z angle-degrees"`, NOT a
  > quat** (`ge_utils.lua:735` sets the C++ `rotation` field). `"0 0 1 0"` =
  > identity (z-axis, 0°). Passing a quat-style `"0 0 0 1"` (degenerate axis,
  > 1°) silently scrambled every child transform (~10 m offset + ~90° yaw).

### Hand-baking `rotationMatrix` (verified in-game 2026-07-30)

The 9 numbers of a prefab entry's `rotationMatrix` are **column-major**: the
listing is `[right; forward; up]` — first triple = the object's right axis in
world coords, second = forward, third = up. (Reading them row-major spawns each
object with the inverse rotation ≈ ±90° wrong yaw for street-diagonal poses.)
To bake a live vehicle pose (`f = getDirectionVector()`, `u =
getDirectionVectorUp()`, `r = f:cross(u)`), remember the vehicle model's
forward is −Y, so flip right/forward (`prefabModule.lua:254` pattern):

```
rotationMatrix = [-r.x, -r.y, r.z,  -f.x, -f.y, f.z,  u.x, u.y, u.z]
position       = veh:getPosition()   -- ref node, works as-is
```
- At mission runtime the flow graph spawns the obstacles prefab itself via the
  `scene/spawnPrefab` node — no manual wiring needed; attaching the file is enough.

## Scenetree basics

`scenetree.MissionGroup` is the level's root object group; placed objects live
under it. `editor.selectObjectById(id)` / `editor.clearObjectSelection()` drive
selection. Objects expose `:getId()`, `:getName()`, `:getField(name, default)`,
`:getOrCreateField/​setField`. Useful for scripting placement and verifying a
vehicle's config field before packing.
