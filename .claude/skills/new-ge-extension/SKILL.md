---
name: new-ge-extension
description: Create a new BeamNG GE-Lua extension to add scripted behavior (scoring, HUD, detectors) to a mod, using the bundled create-mod.ps1 scaffolder to generate the mod folder, info.json, and extension file. Use when the task is to add new scripted behavior to a BeamNG mod, or to create a new mod.
---

# New GE-Lua extension

## Prerequisites

- BeamNG.drive running on Windows.
- The bridge extension loaded on demand via `extensions.load("llmBridge_server")`
  in the in-game console (tilde key). Run live Lua through the authenticated
  bundled client at `.claude/skills/bng-exec/bng-exec.ps1`.

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

## What a GE-Lua extension is

A Lua module: a file that builds a local table `M`, attaches functions to it,
and `return M` at the end. The engine calls specific functions on `M` by name
if they exist (lifecycle hooks); any other function attached to `M` is a
public function callable from the console or another extension.

## Steps

1. **Scaffold the mod.** Run the bundled scaffolder from this skill folder:

   ```powershell
   pwsh -File create-mod.ps1 -Mod <name> [-Ns <namespace>] [-Name <file>] [-Title <display>] [-Author <name>]
   ```

   Only `-Mod` is required, and it must be lowercase kebab-case (e.g.
   `hello-hud`). Defaults: `-Ns` is the camelCase form of `-Mod` (split on
   `-`, first segment unchanged, later segments capitalized — e.g.
   `hello-hud` -> `helloHud`); `-Name` defaults to `main`; `-Title` is the
   title-case form of `-Mod` with spaces (e.g. `hello-hud` -> `Hello Hud`);
   `-Author` defaults to `TODO`.

   Example: `-Mod hello-hud` creates `mods\hello-hud\info.json` and
   `lua\ge\extensions\helloHud\main.lua`, giving the module `helloHud_main`.

   The script refuses to overwrite an existing mod folder — it errors out
   rather than touching anything if `mods\<mod>` already exists.

   Under the hood, this creates `mods\<mod>\info.json` so BeamNG's mod
   manager registers it:

   ```json
   {
     "title": "<Display Name>",
     "description": "<one line>",
     "author": "<name>",
     "version": "0.1.0",
     "type": "mod"
   }
   ```

   and copies `template.lua` (in this same skill folder) to
   `mods\<mod>\lua\ge\extensions\<ns>\<name>.lua`, where `<ns>` is the
   namespace folder. Rename functions and edit the body to implement the new
   behavior.

   The module name equals the file path under `lua\ge\extensions\` with path
   separators replaced by underscores. Example: `llmBridge\main.lua` ->
   `llmBridge_main`.

   If the script can't be run, do this by hand following the same
   info.json shape and naming rule above.

2. **Deploy to the game's userfolder.** Mirror the mod's content folders from
   the repo into the unpacked-mods install location:

   ```powershell
   robocopy "<repo>\mods\<mod>" "$env:LOCALAPPDATA\BeamNG\BeamNG.drive\current\mods\unpacked\<mod>" /MIR
   ```

   `unpacked\<mod>` holds loose files for development (fast iteration, no
   zip). For shipping a mod, zip the content folders themselves (e.g. `lua`,
   `ui`) — not the mod folder that contains them.

3. **First load.** In the in-game console (tilde key), run:

   ```
   extensions.load("<ns>_<name>")
   ```

   This triggers `onExtensionLoaded` for the first time.

4. **Iterate with hot-reload.** After editing and re-deploying (step 2), run:

   ```
   extensions.reload("<ns>_<name>")
   ```

   `onExtensionLoaded` fires on load AND on every reload — a change is live
   with no game restart. Use it to confirm a reload actually happened (e.g.
   watch the console for the log line).

5. **Verify by calling a function.** Use the authenticated bundled client to
   call a public function on the module through the bridge and confirm the
   result:

   ```powershell
   $lua = '<ns>_<name>.hello()'
   pwsh -File .claude/skills/bng-exec/bng-exec.ps1 -Lua $lua
   ```

## Auto-loading on mod mount (optional)

To load the extension automatically whenever the mod is mounted (no console
step each session), add `scripts/modScript.lua` to the mod:

```lua
extensions.load("<ns>_<name>")
```

`core_modmanager.initDB()` scans mounted mods for `scripts/modScript.lua` and
runs it; the mod manager's wrapper sets unload mode so the extension survives.
Inside the extension, call `setExtensionUnloadMode(M, "manual")` in
`onExtensionLoaded` if it must survive level loads when loaded by hand too.
Note: engine hooks (`onUpdate`, `onPreRender`, …) only fire for extensions
loaded from a file via `extensions.load`/`reload` — a table hand-built in the
console never receives them.

## World-space text via debugDrawer

To draw text at a 3D world position (a floating HUD near the dashboard — the
VR-correct alternative to a flat 2D overlay, which fights stereo rendering):

```lua
debugDrawer:drawTextAdvanced(worldPos, String("text"), ColorF(1,1,1,1), ColorI(0,0,0,255), ...)
```

- **Immediate-mode**: the draw lasts one frame — issue it from `onPreRender`
  every frame or it vanishes. Confirm the class (and that the call still
  works) with a one-shot console call: the text should flash for a single
  frame.
- Color types are engine classes: `ColorF(r,g,b,a)` 0–1 floats for text,
  `ColorI(r,g,b,a)` 0–255 ints for background — VERIFIED.
- Keep the text ASCII — glyph coverage for em-dashes/non-ASCII is not
  guaranteed.
- Last verified it renders *without* the F11 debug-render toggle; if text
  never appears, re-check that assumption first, then probe the full
  signature (`probe-runtime` skill) rather than guessing extra arguments.

## Lifecycle hooks the engine calls by name (if present on `M`)

- `onExtensionLoaded` — fires on load and on every `extensions.reload(...)`.
- `onPreRender` — fires every frame; used for per-frame drawing or polling.
  Any world-space debug draw issued here is immediate-mode: re-issue it every
  frame or it vanishes the next frame.
- `onUpdate` — simulation update tick.
- `onVehicleSpawned` — fires when a vehicle is spawned.
- More hooks exist beyond this list — discover them as needed (e.g. by
  searching the engine's own Lua for `hook.call` / `extensions.hook` usage,
  or by checking what other extensions in the codebase implement).
