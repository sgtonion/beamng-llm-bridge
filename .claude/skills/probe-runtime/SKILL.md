---
name: probe-runtime
description: Discover real BeamNG API method names and semantics by asking the live engine instead of guessing, for when a BeamNG API or userdata object is undocumented or docs are thin.
---

# Probe the runtime

## Prerequisites

BeamNG.drive running on Windows. The bridge extension loaded on demand via
`extensions.load("llmBridge_server")` in the in-game console (tilde key).
Run live Lua through the authenticated bundled client at
`.claude/skills/bng-exec/bng-exec.ps1`.

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

## When to use this

BeamNG's docs are thin on object methods, especially for userdata objects
returned by vehicle, scenetree, and geometry APIs. When a needed API or
object's real method names and semantics are unknown, do not guess method
names — that burns reload cycles. Ask the live engine directly. The engine
itself is the most reliable documentation available.

## Procedure

Run each Lua snippet below against the live game through the bridge, using
the bundled client (replace `$lua` with the snippet as a string):

```powershell
$lua = 'dump(be:getPlayerVehicle(0))'
pwsh -File .claude/skills/bng-exec/bng-exec.ps1 -Lua $lua
```

### Step 1 — Pretty-print the object

`dump(x)` renders the full structure of a value, similar to
`console.dir(obj, { depth: null })` in JS devtools.

```lua
local veh = be:getPlayerVehicle(0)
dump(veh)
```

### Step 2 — List the real method names

Iterate the metatable's `__index` to list every callable method — the Lua
equivalent of `Object.getOwnPropertyNames(Object.getPrototypeOf(obj))` in JS,
useful when there are no type definitions to read.

```lua
local veh = be:getPlayerVehicle(0)
for k,_ in pairs(getmetatable(veh).__index or {}) do print(k) end
```

### Step 3 — Small value-probe to learn semantics

Method names alone do not reveal meaning (e.g. which return value is width
vs. length vs. height). Print actual values from a live object to see what
each field really holds.

```lua
local veh = be:getPlayerVehicle(0)
local bb = veh:getSpawnWorldOOBB()
print(bb:getHalfExtents())
print(bb:getAxis(0), bb:getAxis(1), bb:getAxis(2))
print(bb:getPoint(0))
```

## Worked example

Discovering the vehicle spawn-OOBB API from scratch, in the in-game console:

```lua
local veh = be:getPlayerVehicle(0)
local bb = veh:getSpawnWorldOOBB()
dump(bb)                                    -- pretty-print the whole object
for k,_ in pairs(getmetatable(bb).__index or {}) do print(k) end  -- list methods
```

This surfaced the real method names (`getHalfExtents`, `getAxis`,
`getCenterHalfExtentAxes`, `getPoint`, ...) in seconds — no doc-hunting, no
guessing. A follow-up value-probe then printed actual half-extents and axis
vectors to determine which component was width vs. length vs. height.

## Gotcha: never assume axis or index order from one sample

A single probed vehicle can have axes in a convention that does not hold for
other vehicles or after an engine update. Do not hardcode "axis 0 is length"
from one observation. Instead classify by a physical property that holds
generally:

- The most-vertical axis (largest absolute Y or Z component, depending on the
  coordinate convention in use) is **height**.
- Of the two remaining axes, the one with the larger half-extent is
  **length**; the other is **width**.

Classifying by geometry rather than by index position means the conclusion
survives version changes and odd vehicle shapes, instead of silently
breaking on the next vehicle tested.

## Gotcha: probe twice — classify frozen vs live

A value probed once reveals its shape, not whether it *updates*. Some engine
APIs capture state at spawn/init and never refresh it, alongside live twins —
mixing the two produces anchors pinned to where the car started or geometry
that is silently wrong.

**Classification probe:** read the value, change the relevant state (e.g.
drive away from spawn), read it again. Frozen values stay pinned; live values
track.

Worked example (VERIFIED, the bug that motivated this rule): everything on
`veh:getSpawnWorldOOBB()` — `getCenter()`, `getAxis()` — is captured at
spawn time and never updates, so anchors built from it stay at the spawn
point. Its `getHalfExtents()` are still safe: sizes are invariant (a car
doesn't change shape). And `veh:getSpawnAABBRadius()` is a bounding-*sphere*
radius (≈ corner-to-corner half-diagonal) — using it as a width puts mirror
anchors metres apart.

**Rule of thumb:** invariants (sizes) from the spawn OOBB; anything that
moves (center, directions) from the live vehicle — `veh:getPosition()`,
`veh.obj:getDirectionVector()`, `veh.obj:getDirectionVectorUp()`; build the
right vector with `right = forward:cross(up):normalized()`.

Re-verify with:

```lua
local veh = be:getPlayerVehicle(0)
print(veh:getSpawnWorldOOBB():getCenter())  -- pinned at spawn after driving away
print(veh:getPosition())                    -- tracks the car
```

## Relate

- `dump(x)` ≈ `console.dir(obj, { depth: null })` in JS devtools.
- `for k in pairs(getmetatable(x).__index)` ≈
  `Object.getOwnPropertyNames(Object.getPrototypeOf(obj))` in JS — listing a
  prototype's methods when there are no type defs.
- This is the modding equivalent of cracking open a library in devtools and
  poking at it because the `@types` package is missing or wrong.
