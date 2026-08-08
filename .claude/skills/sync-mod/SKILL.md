---
name: sync-mod
description: Sync the repo's mods/<name>/ folder into the BeamNG unpacked-mods install folder so changes are testable in-game. Use when the user says "sync the mod", "deploy the mod", "push to BeamNG", "copy to BeamNG", "install the mod", or after editing files under mods/<name>/ and wanting them live in the game. Runs sync-mod.ps1 (robocopy mirror, excludes *.md).
---

# sync-mod

Mirrors a mod folder from this repo's `mods\<name>\` into the BeamNG userfolder so edits
become testable in-game without manual copying. This is the dev-loop deploy step.

## Prerequisites

BeamNG.drive running on Windows. The target extension is loaded on demand from the
in-game console (`~` key) via `extensions.load("llmBridge_server")`; once loaded it
accepts authenticated live-engine calls through the bundled client at
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

## What it does

Runs `sync-mod.ps1` (in this same folder), which uses `robocopy /MIR` to make the install
folder an **exact** copy of `mods\<name>\` (stale/renamed files are purged) and
**excludes `*.md`** so only real mod content ships (`info.json`, `lua/`, `ui/`).

Default mod name: `llm-bridge`. Default target (the documented BeamNG `current` alias,
version-agnostic):
`%LOCALAPPDATA%\BeamNG\BeamNG.drive\current\mods\unpacked\llm-bridge`

## How to run

From this skill's folder (or pass a full path to `-File`), run with PowerShell:

```powershell
pwsh -File sync-mod.ps1
```

Preview changes without copying (recommended when unsure what will be purged):

```powershell
pwsh -File sync-mod.ps1 -DryRun
```

Sync a different mod folder under `mods\`:

```powershell
pwsh -File sync-mod.ps1 -Mod other-mod-name
```

Override the target folder for a custom BeamNG userfolder. For mirror safety,
the normalized path must end in `mods\unpacked\<mod-name>` and the explicit
`-AllowCustomDest` acknowledgement is required:

```powershell
pwsh -File sync-mod.ps1 -Dest "D:\BeamNG-userfolder\mods\unpacked\llm-bridge" -AllowCustomDest
```

## Module naming rule

A GE-Lua extension's module name is its path under `lua\ge\extensions\` with each
backslash replaced by an underscore. Example: `lua\ge\extensions\llmBridge\server.lua`
loads as module `llmBridge_server`; `lua\ge\extensions\llmBridge\main.lua` loads as
`llmBridge_main`.

## After syncing

Reload in the BeamNG console (open with the `~` key) — no game restart needed for
GE-Lua changes:

```lua
extensions.reload("llmBridge_server")
```

The first time (module not yet loaded this session), use `extensions.load(...)` instead
of `extensions.reload(...)`.

If a different extension module was edited, reload that module instead, using the
naming rule above.

## Caution: extensions that own a socket

If a sync deletes or renames a file belonging to an extension that owns a network
socket (such as the LLM bridge, which listens on port 23512), **unload that extension
first** — e.g. `extensions.unload("llmBridge_server")` — before syncing, then load it
again afterward. Reloading or losing track of a socket-owning extension's files while
it still holds the socket can leave the port orphaned until the game restarts.

## Notes

- The script resolves `mods\<name>\` relative to its own location (repo root, three
  `Split-Path -Parent` hops above this skill folder), so it works regardless of the
  current directory.
- Mod names are restricted to lowercase kebab-case. Before `robocopy` runs, the
  script resolves both paths, confirms the source is inside this repo's `mods`
  folder, requires the target to end in `mods\unpacked\<mod-name>`, requires
  explicit acknowledgement for a custom target, and rejects overlapping
  source/destination trees.
- Mirror mode means anything in the target that isn't in `mods\<name>\` (minus `*.md`)
  gets deleted. That's intentional — it keeps the install clean. Use `-DryRun` first if
  the target might contain files worth keeping.
- robocopy exit codes 0–7 are success; the script only errors on 8+.
