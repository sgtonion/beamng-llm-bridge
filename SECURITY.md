# Security

## Threat model, stated plainly

The bridge (`mods/llm-bridge`) executes **arbitrary GE-Lua with full engine
access** over plain HTTP on `127.0.0.1:23512`. It is a development tool, not
a general-purpose local service. Four constraints limit who can reach it:

1. **Localhost-only binding.** The host is passed straight through to the
   socket `bind()`; nothing on the LAN can reach it.
2. **Never auto-loaded.** The mod has no `scripts/modScript.lua`. The bridge
   runs only after an explicit `extensions.load("llmBridge_server")` in the
   console, and stops on `extensions.unload("llmBridge_server")` or game
   exit.
3. **Session capability.** `/session`, `/ping`, and `/exec` require
   `Authorization: Bearer <token>`. The bundled PowerShell client generates a
   cryptographically random 32-byte token for each loaded extension instance.
   The in-memory server token is cleared on unload, reload, or game exit.
4. **Browser request guards.** The server accepts only the exact
   `Host: 127.0.0.1:23512` value and rejects requests with an `Origin` header.
   A cross-origin page cannot attach the Bearer header without a preflight,
   and the shipped GET-only server does not accept preflight requests.

The client stores the current capability at
`%LOCALAPPDATA%\beamng-llm-bridge\session.json` so separate PowerShell
invocations can share it. A new session atomically overwrites that one file;
there is no token history. A token left after BeamNG closes is inert because
the matching in-memory server session no longer exists.

These controls prevent unauthenticated browser requests and accidental local
calls. They do **not** protect against a hostile process running as the same
Windows user. Such a process can read the token cache, race to initialize a
new session, or otherwise act with that user's permissions.

The operational rule remains: **load the bridge for a session, unload it when
done.** Do not leave it running unattended, bind it to another interface, or
publish a mod that auto-loads it.

## Reporting

If you find a way to reach the bridge from off-machine, bypass its session
capability or browser guards, start it without the explicit console load, or
otherwise break the model above, open a GitHub issue. There is no sensitive
infrastructure behind this project, so public disclosure is fine; an issue is
faster than private mail and helps anyone already running the bridge.
