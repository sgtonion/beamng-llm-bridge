# Sites Editor (parking spots + zones + locations)

> **Provenance:** verified against BeamNG.drive v0.39.4.0. The game updates; where
> this doc and the live engine disagree, the engine wins — correct this doc
> when you find rot.
> **Re-verify:** grep `sitesEditor.lua` near `:13,94` for the default save
> dir (`/gameplay/sites/`) and the `.sites.json` suffix — confirms the Sites
> save location/naming hasn't moved.

Source: `lua\ge\extensions\editor\sitesEditor.lua`,
`...\editor\sitesEditor\parkingSpots.lua`,
`...\gameplay\sites\sites.lua`. Doc: documentation.beamng.com/world_editor/windows/sites_editor/.

The Sites system stores three kinds of map annotations in one `.sites.json`:
**parkingSpots**, **zones** (polygons), **locations** (points). A
parallel-parking mission needs parking spots; a 3-point-turn or trigger-zone
mission needs zones.

## Open

`F11` → **Window → Gameplay → Sites Editor** (registered as
`addWindowMenuItem("Sites Editor", …, {groupMenuName="Gameplay"})`,
`sitesEditor.lua:303`). Or console: `editor_sitesEditor.show()`.
Tabs: Locations · Zones · Parking Spots · (+ Tag tabs).

## Save location

Default save dir is `/gameplay/sites/` and file suffix is **`.sites.json`**
(`sitesEditor.lua:13,94`). **For a precisionParking mission, Save As → the
mission folder, filename `spots.sites.json`** (the type expects exactly that
path). API: `editor_sitesEditor.saveSites(sites, dir..name)` /
`editor_sitesEditor.loadSites(path)`.

## Parking spots (the common path)

From `parkingSpots.lua`:
- **Create**: switch to the Parking Spots tab, **shift-click** in the viewport to
  drop a spot at the ray hit. A new spot gets the **`Car`** scale preset
  `vec3(2.5, 6, 3)` (W×L×H) and a transform gizmo for position/rotation.
- **Scale presets**: `Car (2.5×6×3)`, `LargeCar (3.25×8×4)`, `Bus (4×14×8)`, or
  Custom. The spot's box is what the scorer measures the vehicle against.
- **Name / fields**: edit the spot **name** in the sorted-list panel. For
  precisionParking, name one spot `start` and the targets `0,1,2,…`. Add the
  numeric field **`onlyForward = 1`** on a spot to require correct orientation.
- **MultiSpot**: one spot can fan out into a row (Amount 1–25, Direction
  Left/Right/Front/Back, Offset, per-spot Rotation) — handy for a row of bays,
  not needed for a single parallel-park target.

### Useful Tools-menu helpers (`sitesEditor.lua:117-186`)

- **Enumerate Parking Spots** — auto-renumbers same-named spots `name01, name02…`
  (zero-padded). Fast way to number target spots.
- **Sort Parking Spots by Name**, **Sort Zones/Locations by Name**.
- **Parkingspot Names by Zone Containment** — names spots after the zone they sit
  inside (bulk-tagging).

## Zones (stub — expand when needed)

Zones are named polygons with `containsPoint2D(pos)` / `containsPoint(pos)`
tests (`sitesEditor.lua:180`). They are the natural fit for:
- A **3-point-turn** mission **boundary** (penalize out-of-zone exits).
- **Trigger zones** (stop-sign zones, speed-band zones).
Authored on the Zones tab; same `.sites.json` file. Expand this section as
those mission types get built.

## Runtime flow-node access (how missions read sites)

Built-in flow nodes (used by precisionParking) read sites at runtime:
`gameplay/sites/fileSites` (load file), `gameplay/sites/parkingspotByName`
(lookup, e.g. `start`), `gameplay/sites/parkingspot` (read pos/rot/scale). Listed
here so the names are recognizable when scripting against sites in GE-Lua.
