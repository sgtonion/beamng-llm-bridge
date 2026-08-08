# Agent context

This file is for AI agents building BeamNG mods on top of this repo. The
skills under `.claude/skills/` are the task playbooks; this is the reasoning
layer that applies across all of them.

## Facts are cached hypotheses

Every BeamNG claim in this repo is last-known behavior, not permanent truth —
the game updates and the modding API is unversioned. Claims carry labels
stamped with the build they were checked against: **VERIFIED vX.Y.Z** (ran
against that live build), **SOURCE-READ vX.Y.Z** (read in that build's
shipped Lua), **UNCONFIRMED** (plausible; probe before trusting — no
version, nothing was checked). Unlabeled means UNCONFIRMED; an inline label
without a version inherits the doc's baseline stamp. Trust a claim by its
method *and* its build distance — VERIFIED from several builds ago is a
hypothesis again, and can rank below fresh SOURCE-READ. Before building on a
claim, re-verify it cheaply if a probe exists; when a doc here and the live
engine disagree, **the engine wins** — correct the doc and update its stamp.
Stamps are never hand-downgraded; the aging build number is the staleness
signal.

Verification order, most authoritative first:

1. The live engine — probe it through the bridge (`bng-exec` skill).
2. The game's shipped Lua source: `<steam>\lua\ge\`.
3. Official docs (documentation.beamng.com) — can lag the shipped build.

`beamng.log` is the authoritative record of what actually *happened* — diff
its line count around an action. In-memory objects can be stale caches.

## Engine gotcha classes

Recurring failure shapes in this engine. When observed behavior looks
impossible, check these classes before debugging your own logic:

- **Frozen-vs-live data.** Some APIs capture state once (at spawn/init) and
  never update, alongside live twins. Invariants (sizes, shapes) are safe
  from either; anything that moves (position, direction) must come from the
  live object. Classify by probing twice with a state change in between
  (drive away, re-read: a frozen value stays pinned).
- **Immediate-mode rendering.** Debug draws last exactly one frame — issue
  them every frame from a hook (`onPreRender`) or they vanish. A one-shot
  console call that flashes and disappears confirms the class.
- **Silent-nil APIs.** Functions that return `nil` on success *and* failure.
  A clean return proves nothing — verify with a behavioral round-trip (ping
  the server it claimed to start; read back the state it claimed to set).
- **Module-local seams.** Replacing an exported table field is dead code when
  internal callers close over a module-local. Patch the function external
  callers actually reach, and verify by observing changed behavior — never by
  re-reading the export.
- **Stale exports, scans, and caches.** Exported tables rebound internally,
  scene scans that miss live objects, cached mission objects. Verify through
  a held reference or a fresh query by id, never through a snapshot.
- **Convention guessing.** Never infer axis order, index base, or on-disk
  format from one sample or from a runtime object's shape. Classify axes by a
  physical property (most-vertical = height; longer of the rest = length);
  read file formats from a shipped example file.

## Operating rules

- Don't guess API names — ask the live engine (`probe-runtime` skill).
- Verify visual/behavioral changes yourself through the bridge and the log
  before reporting them as working; never use the user as the test harness.
- Never copy shipped game files (Lua, flowgraphs, assets) into a mod or this
  repo — reference them by path. Wholesale copies are a licensing violation.
