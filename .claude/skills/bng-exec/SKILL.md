---
name: bng-exec
description: Run GE-Lua inside a live BeamNG.drive session from the shell — inspect game state, drive the world editor, validate mod behavior. Use when a task needs to query or mutate the running game (read scenetree/mission state, place objects, check a value) instead of guessing from static files.
---

# bng-exec

Sends GE-Lua to a running BeamNG.drive instance over a local HTTP bridge and
returns the result, captured print/log output, and any error — without
alt-tabbing into the in-game console.

## Prerequisites

- BeamNG.drive running on Windows, with a map loaded (not paused).
- The bridge extension loaded on demand, from the in-game console (tilde key,
  `~`):
  ```lua
  extensions.load("llmBridge_server")
  ```
  It binds `127.0.0.1:23512` (localhost only). It is dev/authoring tooling —
  not part of any default load list.

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

## Usage

Call the bridge from **native PowerShell**, not a Bash tool — on Windows,
agent Bash sandboxes are typically cut off from `127.0.0.1`, while
PowerShell reaches it. Use the bundled client so session authentication is
handled automatically. Always ping first (see "Why ping first" below), then
send Lua:

```powershell
pwsh -File .claude/skills/bng-exec/bng-exec.ps1 -Ping
pwsh -File .claude/skills/bng-exec/bng-exec.ps1 -Lua "return 1+1"
pwsh -File .claude/skills/bng-exec/bng-exec.ps1 -Lua 'print("hi"); return be:getPlayerVehicleID(0)'
```

The endpoint is intentionally fixed to `127.0.0.1:23512`. The client creates
a 32-byte capability for each loaded bridge session and caches only the
current value at `%LOCALAPPDATA%\beamng-llm-bridge\session.json`. A new
session atomically overwrites the stale value; tokens do not accumulate.
Do not bypass the client with a raw unauthenticated HTTP request.

## Response contract

```jsonc
// success
{"ok":true, "result":"42", "output":"hi\n[I] a log line"}
// compile failure
{"ok":false,"phase":"compile","error":"...unexpected symbol near '<eof>'"}
// runtime failure (output captured up to the error)
{"ok":false,"phase":"runtime","error":"...attempt to index global 'nope'...","output":""}
// authentication failure
{"ok":false,"phase":"auth","error":"invalid or missing Bearer capability","auth":"session-bearer-v1"}
```

- `ok` — boolean, whether the call completed without error.
- `result` — the Lua return value, serialized (numbers, strings, vec3, tables
  all work).
- `output` — everything sent to `print`/`log` during the call, newline-joined.
- `phase` — present only on failure: `"auth"`, `"compile"`, or `"runtime"`.
- `error` — present only on failure: the Lua error message.

## Rules

- **One statement or short script per call.** The server is GET-only (parses
  only `GET … HTTP/x.x`, no POST body), so Lua rides in the URL query string
  and is length-limited. Split a large script across multiple calls, or wrap
  the logic in a function defined in one call and invoked in the next.
- Lua travels URL-encoded in the `lua` query parameter — always encode with
  `EscapeDataString` (or the bundled script, which does this automatically).
- `/session`, `/ping`, and `/exec` require the session's Bearer capability.
  The bundled client initializes and supplies it automatically; never print,
  log, commit, or place it in a URL.
- Use `print(...)` inside the Lua to capture extra diagnostic output beyond
  the return value; it comes back in the `output` field.
- **`log("D", ...)` lines are NOT captured in `output`** (debug level is
  filtered) — VERIFIED v0.39.4.0. Use `log("I", ...)` or `print(...)` for
  anything you need to see through the bridge; an empty `output` after a call
  that logs at "D" proves nothing about whether the code ran.
- Requests are pumped on the game's `onUpdate`, so the game must be running
  (not fully paused) to be served.

## Why ping first

`simpleHttpServer.start()` returns `nil` on both success and bind failure —
the extension cannot tell Lua whether the socket actually bound. The load log
line is not proof. An authenticated `/ping` round-trip is the only reliable
signal the server is up. On the first `-Ping` after a load, the client creates
and initializes a fresh session capability before verifying the round-trip.

## Stuck port ("address already in use")

**Symptom:** `extensions.load(...)` fails with "address already in use" and
`-Ping` gets no answer, typically after a refactor or mod sync touched the
extension's file.

**Principle:** a port orphans when the last Lua reference to its socket dies
without anything closing it. Deleting a loaded extension's file does *not*
cause this by itself — the module keeps running from memory, its `stop()`
still works, and `extensions.unload(...)` still succeeds. What orphans the
socket is unloading (or otherwise dropping) its owner without a close — e.g.
an extension with no `onExtensionUnloaded` cleanup.

**Fix ladder** (in-game console; all recover without restarting the game):

1. Extension still loaded → its own `stop()`, e.g. `llmBridge_server.stop()`.
2. Extension gone, socket was `simpleHttpServer`-based →
   `require('utils/simpleHttpServer').stop()` — the module is a cached
   singleton, so a fresh require reaches the same live socket.
3. Extension gone, raw luasocket → `collectgarbage('collect')` — luasocket's
   finalizer closes collected sockets.

Prevention is still cheaper than recovery: `extensions.unload(...)` before
deleting or renaming an extension's file.

## One `simpleHttpServer` per process

**Symptom:** loading a second extension that uses
`utils/simpleHttpServer` silently kills the first one's server; or one
extension's `stop()` takes down another extension's endpoint.

**Principle:** `require('utils/simpleHttpServer')` returns one cached module
table for the whole process, and its socket, port, and handlers are
module-locals inside it — the second `start()` overwrites the first server's
state, and any caller's `ws.stop()` closes whoever's socket is current.

**Fix pattern:** treat the module as a single shared slot: only one
`simpleHttpServer`-based extension loaded at a time. A second concurrent
server must own its own socket (raw luasocket) instead.

## Editing `server.lua` itself

Dev loop for changing the bridge's own code: `llmBridge_server.stop()` →
sync the mod → `extensions.reload("llmBridge_server")` (reload re-runs
`onExtensionLoaded`, which rebinds the port).

## Security

The bridge executes **arbitrary Lua with full engine access** on a local
port. It binds `127.0.0.1` only and requires a session Bearer capability,
an exact loopback `Host`, and no browser `Origin` header. These checks block
unauthenticated browser requests; they do not protect against a hostile
process running as the same Windows user, which can read the token cache.

- Load it on demand only, never as part of a mod's default/auto load list.
- Unload it when done:
  ```lua
  extensions.unload("llmBridge_server")
  ```
- Never ship a mod with this extension auto-loading.
