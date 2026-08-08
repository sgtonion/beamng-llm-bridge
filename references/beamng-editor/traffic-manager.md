# Traffic Manager (placing the parked cars)

> **Provenance:** verified against BeamNG.drive v0.39.4.0. The game updates; where
> this doc and the live engine disagree, the engine wins — correct this doc
> when you find rot.
> **Re-verify:** check `<steam>` for `*_parked.pc` files under
> `/vehicles/simple_traffic/` and confirm none exist under the regular model
> folders (e.g. `/vehicles/bastion/`) — confirms parked configs still live
> only on `simple_traffic`.

Source: `lua\ge\extensions\editor\trafficManager.lua`. Used to place
**parked, AI-disabled** vehicles before packing them into a prefab.

## Open

`F11` → **Window → … → Traffic Manager** (Gameplay group). It manages a
"session" of placed vehicles with per-vehicle type + AI settings.

## Placing a parked car

- Add a vehicle to the session; pick a model/config. **Parked configs use the
  `_parked` suffix** — e.g. `bastion_base_parked` (`trafficManager.lua:845`,
  used as the default when the vehicle type is set to "parked"). Parked configs
  sit with handbrake on / no driver and won't roll.
  > **Correction (2026-07-28, verified in-game 0.38):** ALL `*_parked.pc`
  > configs live under the **`simple_traffic`** model
  > (`/vehicles/simple_traffic/bastion_base_parked.pc` etc.) — regular models
  > (bastion, covet, …) ship NO parked configs. Spawn via
  > `core_vehicles.spawnNewVehicle("simple_traffic", {config="vehicles/simple_traffic/<name>_parked.pc", pos=…, rot=…, autoEnterVehicle=false})`.
  > Stock precisionParking prefabs (`005-limoparking`) confirm this.
- A parked vehicle is **not drivable** (commented in source at `:1035`), which is
  the desired behavior for static obstacles.

## AI mode → set to disabled

Per-vehicle **AI Mode** dropdown (`trafficManager.lua:1150-1172`). Set it to
**`disabled`** so the car never drives off. Values seen in source:
`disabled`, `traffic`, `stop`, `chase`, `follow`, `flee`, etc.
- The data field is `vehData.aiMode` (defaults to `"traffic"`, `:455`).
- Applied at runtime via `veh:queueLuaCommand('ai.setMode("disabled")')`
  (`trafficManager.lua:337`) — i.e. AI mode is a vehicle-Lua call, bridged from
  GE. `createVehicleData(id, {aiMode = "disabled"})` is how the editor seeds it
  (`:1013`).

## Spacing for a parallel-park gap

Place the two cars along the curb leaving ~1.5× a car length between them
(eyeball against a stock sedan ≈ 4.7 m long — half-length
2.34 m). Position with the standard transform gizmo. The gap is where the player
parks; the Sites `0` target spot goes in that gap.

## Then pack them

Once both cars are placed, parked, and AI-disabled: select both in the Scenetree
→ **Put Into New Group** → **Pack Prefab** → `obstacles.prefab.json` in the
mission folder. See [prefab-and-scenetree.md](prefab-and-scenetree.md).

> Note: a packed prefab stores the vehicles' placement + config. Confirm the
> parked config + AI-disabled state are baked in by re-spawning the prefab in a
> fresh session and checking the cars don't move.
