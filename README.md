# beamng-llm-bridge

A small BeamNG.drive mod (~120 lines of Lua) that exposes a localhost HTTP
bridge so an AI coding agent can execute GE-Lua in a live game session —
plus the agent skills, sync tooling, and source-verified knowledge built
around it. Built while using agent-driven mission authoring to practice
driving-exam maneuvers in VR. One of those drills ships here too:
`mods\driving-drills`, a 26-gate turns course ending in a parking bay, as a
worked example of what the tooling produces.

Everything here was verified against BeamNG.drive **v0.39.4.0** — see
"Knowledge freshness" below for how claims are labeled and re-checked.

## Who this is for — and why it exists

I wanted repetitions for driving-test maneuvers, had a VR headset and the
Steam build of BeamNG.drive, and didn't want to learn the whole modding
stack before building the first drill — so a coding agent built the drills,
and this bridge is what let the agent see and drive the live game instead
of guessing from static files.

If eligible for BeamNG.tech, use [BeamNGpy](https://github.com/BeamNG/BeamNGpy)
instead — the official, far more capable path (Python API, sensors, full
control). BeamNG.tech research licenses are free but gated behind registration
with an academic or professional email. Quoting BeamNG directly:

> If you buy BeamNG.drive from Steam you will only have access to the game and
> no access to BeamNG.tech.

This project exists for people who only have the Steam build. It uses only
the consumer game's own Lua extension system and the `simpleHttpServer`
utility the game ships with — nothing patched, nothing circumvented.

## Requirements

**What you need:**

- A Windows PC with BeamNG.drive (Steam).
- An AI coding agent that can read files and run shell commands. Claude
  Code works out of the box — the skills auto-load; any other agent works
  with one extra step (see "Not using Claude Code?" below).
- PowerShell 7 (`pwsh`) — the sync and scaffold scripts are PowerShell.

**What you need to know:** not Lua, not BeamNG's engine, not the modding
APIs — that knowledge is packaged in the skills, and the agent applies it.
What you do need is basic agent literacy: describing what you want, typing
two commands into the in-game console, and reading what the agent proposes
before letting it run. The bridge executes arbitrary code in your game, so
treat agent-written Lua like any code you'd run on your machine.

**What this was built and tested on** — calibration, not hard requirements:
Windows 11, Steam BeamNG.drive v0.39.4.0, PowerShell 7, Claude Code as the
agent, and — for driving the finished drills — PSVR2 and Quest 3 headsets
with a Logitech G923 wheel, pedals, and a handbrake. The peripherals are
all optional: nothing in this repo requires VR or a wheel, and none of it
changes what the tooling does. The tooling is Windows-only as written
(anywhere else is UNCONFIRMED). For the game's own hardware requirements, see the system requirements on
[BeamNG.drive's Steam page](https://store.steampowered.com/app/284160/BeamNGdrive/) —
this repo adds no load beyond running the game plus a coding agent.

## Quick start

The only thing you ever type by hand is two in-game console commands —
everything else is a prompt to your agent.

1. Clone the repo and open it in your agent:

   ```powershell
   git clone https://github.com/sgtonion/beamng-llm-bridge.git
   cd beamng-llm-bridge
   claude   # or your agent of choice
   ```

2. Ask the agent to deploy the bridge — *"sync the llm-bridge mod"*. (It
   runs the `sync-mod` skill; the manual fallback is
   `pwsh -File .claude\skills\sync-mod\sync-mod.ps1`.)

3. Launch BeamNG.drive, load any map, open the console (tilde key, `~`)
   and type:

   ```lua
   extensions.load("llmBridge_server")
   ```

4. Ask the agent to verify — *"ping the bridge and run `return 1+1`"*.
   Expect back `ok: true, result: 2`.

5. Build something — see "Using AI to build mods" below.

6. When done, unload the bridge in the console:

   ```lua
   extensions.unload("llmBridge_server")
   ```

   Make this a habit — see Security.

## Security

The bridge executes **arbitrary Lua with full engine access**. It binds
`127.0.0.1` only, so nothing on the LAN can reach it, and it is **never
auto-loaded** — load it on demand from the BeamNG console and unload it
when finished, as in the quick start above.

Every executable request also requires a session Bearer capability that the
bundled PowerShell client creates automatically. The capability is valid only
for the currently loaded extension instance; the client caches that one value
under `%LOCALAPPDATA%\beamng-llm-bridge\session.json` so separate calls can
share it, then overwrites it for the next session. Exact `Host` validation and
browser `Origin` rejection prevent a web page from using the endpoint as an
unauthenticated cross-origin execution primitive.

The remaining risk is another process running as the same Windows user: it
can read the cached capability or initialize the session before the intended
client. Unload the bridge when done. Never ship a mod with it enabled. Full
threat model in `SECURITY.md`.

## Using AI to build mods

Open the repo in your agent and describe what you want — you don't need to
know which skill applies. In Claude Code the skills are auto-discovered:
each one declares when it should be used, and the agent picks the right one
from your description of the task. You can also invoke one explicitly by
name (`/new-mission`, `/sync-mod`, …) when you already know what you want.
The loop the agent runs: edit the mod in the repo → sync it into
the game (`sync-mod`) → execute and verify against the live session through
the bridge (`bng-exec`) → read `beamng.log` and probe again until the
change is proven. The AI is a build-time collaborator — it writes, deploys,
and verifies the mod; you drive the result.

Prompts that map to real workflows here:

- *"Create a parking drill on West Coast USA"* — the `new-mission` skill
  interviews you about the objective, scaffolds the mission, then places
  start position, spots, and obstacles live through the bridge.
- *"My mission starts on a black screen"* / *"my car is invisible"* — the
  `debug-mission-launch` skill walks the known engine-behavior fixes.
- *"What methods does this vehicle object actually have?"* — the
  `probe-runtime` skill asks the live engine instead of guessing.
- *"Add scripted behavior / a HUD / a detector"* — the `new-ge-extension`
  skill scaffolds a loadable extension in one command.

| Skill | Trigger |
|---|---|
| `sync-mod` | Deploy a mod folder into the game install and hot-reload it. |
| `bng-exec` | Execute Lua in the live game session over the HTTP bridge. |
| `probe-runtime` | Discover undocumented engine APIs by introspecting the live runtime. |
| `new-ge-extension` | Create a new mod (create-mod.ps1 scaffolder) or add a GE-Lua extension to an existing one. |
| `new-mission` | Scaffold a playable mission/scenario and place it live through the bridge. |
| `debug-mission-launch` | Diagnose why a mission fails to start. |

### Not using Claude Code?

This repo was written with Claude Code, but nothing in it is
Claude-specific. The skills live under `.claude\skills\` (where Claude Code
discovers them automatically), and each one is a standalone module — plain
markdown plus the scripts it uses, no external references. Your agent
doesn't need to be told which skill to use, either: every `SKILL.md` opens
with a frontmatter `description` stating exactly when it applies, so a
one-time setup prompt is enough to let it route tasks itself —

> *"Read the `description` at the top of each `.claude/skills/*/SKILL.md`
> and use those skills as your playbooks for BeamNG work."*

From there it can follow a `SKILL.md` directly, migrate the skill files
into its own instruction format, or derive what it needs from the relevant
folders. `AGENTS.md` at the repo root carries the cross-cutting reasoning
rules and sits in the standard location most coding agents already read.

## What kind of mod are you building?

Ordered by how much this repo helps — pick the first row that matches your goal:

1. **GE-Lua extension** — scripted behavior running in the game engine:
   scoring, HUD text, detectors, world logic. Fully scaffolded: the
   `new-ge-extension` skill's `create-mod.ps1` gives you a loadable module in
   one command.
2. **Mission / scenario** — playable objectives on a map (parking drills,
   driving exercises). Interactive: the `new-mission` skill interviews you
   about the objective instead of assuming one. Parking drills are the one
   fully verified worked example — `create-mission.ps1` scaffolds the
   mission folder with the known launch fixes pre-applied, then its snippet
   library walks the in-game live placement (start position, parking spots,
   obstacles) through the bridge. For anything else, the skill enumerates
   the game's actual mission types from the live engine rather than
   guessing, then probes what that type needs before scaffolding it. For the
   underlying editor internals, see `references/beamng-editor/` (start with
   `mission-editor.md`; `precision-parking.md` covers the verified parking
   mission type in full). The mission files land inside your mod at
   `mods/<mod>/gameplay/missions/<level>/<missionType>/<NNN>-<Name>/`, and
   the `debug-mission-launch` skill handles the launch failures you will hit.
3. **Vehicle / part mod** — new vehicles or jbeam parts. Out of scope for
   this repo; see the official BeamNG modding documentation.

## Repo map

| Path | What's there |
|---|---|
| `mods\llm-bridge` | The bridge mod itself. Add other mods as siblings under `mods\` — the sync skill deploys any of them by name. |
| `mods\driving-drills` | A worked example: checkpoint turns course + parking finale on West Coast USA, driven through the standalone race runtime. Has its own README. |
| `.claude\skills` | The agent skills (see the table above). |
| `AGENTS.md` | Always-loaded agent context: facts are cached hypotheses, the verification order, and the engine's recurring gotcha classes. `CLAUDE.md` imports it. |
| `references\beamng-editor` | Source-verified editor internals, for the areas where official docs are thin. |

## Knowledge freshness

Every claim about BeamNG in this repo carries one of three labels, and the
first two are stamped with the game build they were checked against —
verification is an event on a build, not a permanent property:

- **VERIFIED vX.Y.Z** — run against that live build and confirmed to work.
- **SOURCE-READ vX.Y.Z** — read directly from that build's shipped Lua
  source, not yet run.
- **UNCONFIRMED** — plausible (from docs, inference, or memory); probe it
  before trusting it. Carries no version, because nothing was checked.

Unlabeled means UNCONFIRMED. Treat it that way. To keep stamps cheap, each
doc states one baseline in its header ("VERIFIED against v0.39.4.0 unless a
claim carries its own label"); an inline label without a version inherits
that baseline. Stamps are never hand-downgraded — an aging build number is
itself the staleness signal, and judging a claim means weighing its method
*and* its build distance, not the word VERIFIED alone. Re-verifying a claim
updates its stamp.

The game updates and the modding API is unversioned, so nothing here is
permanently true. Where a doc and the live engine disagree, the engine
wins — re-derive the fact and correct the doc, updating its version stamp.
Re-derive in this order: live engine probe first, then the game's own Lua
source under your install (`<steam>\lua\ge\`), then
[documentation.beamng.com](https://documentation.beamng.com) last, since
the official docs can lag behind the shipped engine.

`references/` docs each carry a provenance header with a one-line re-verify
check, and every skill embeds this same rule inline rather than linking out
to it — skills stay standalone. `AGENTS.md` carries the cross-cutting
version: facts are cached hypotheses, and the engine's recurring gotcha
classes. Keep the convention: never add a BeamNG fact without a label and a
way to re-check it.

## Licensing

The repository is under MIT (see `LICENSE`), with one exception: the file
`mods\llm-bridge\lua\ge\extensions\llmBridge\server.lua` is under bCDDL-1.1
because it uses BeamNG's bundled `simpleHttpServer` and follows its patterns
(full text in `bCDDL-1.1.txt`; keep its header intact). bCDDL is file-level
copyleft, so the mix is fine.

## Non-affiliation

This is a fan-made mod built on the game's own extension system. It does not
modify, patch, or circumvent anything, and it provides no access to
BeamNG.tech. Not affiliated with or endorsed by BeamNG GmbH. BeamNG.drive is a
trademark of BeamNG GmbH.
