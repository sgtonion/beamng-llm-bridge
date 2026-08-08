# Contributing

## The short version

This repo is a finished tool, given as-is: a bridge, the agent skills, and
the verified knowledge to build BeamNG mods with an AI coding agent. The
intended way to build on it is a **fork** — it's MIT-licensed, no
permission needed. The deliverable is the fork, not the PR — that's
freedom, not a wall: you never need my review to use, fix, or extend
this. What does come back upstream gets read — all of it — just on no
promised schedule.

## Mods you build with this tooling

Publish them yourself, under your own name, on the official BeamNG mod
repository (via [beamng.com](https://www.beamng.com)) or the BeamNG
forums — that's where players look for mods, and this repo does not
collect them. The two mods here earn their place structurally:
`llm-bridge` *is* the tool, `driving-drills` is the worked example.

One hard rule for anything you publish: **never ship the bridge inside a
mod** — see `SECURITY.md`.

## What is welcome upstream

The knowledge here rots as the game updates, and that rot is shared by
every fork — so the contributions that help everyone are repairs:

- **Re-verifications.** Run a doc's probe on a newer build and update the
  stamp (`VERIFIED v0.39.4.0` → `VERIFIED v0.4x.y.z`), or correct the
  claim where the engine now disagrees.
- **Corrections and new gotchas.** Written as symptom → principle → probe →
  fix, in the skill where they bite; cross-cutting reasoning rules belong
  in `AGENTS.md`.
- **Skill improvements that add verified capability.** A mission type taken
  end-to-end and written up as a new tier, a new verified snippet, a
  sharper probe — anything that grows what the skills can do, carrying its
  stamps. New skills are welcome on the same terms if they follow the
  conventions below (standalone, freshness rules embedded, claims labeled).
- **Small fixes** to the bridge or the PowerShell scripts.

The test for whether a change belongs upstream: **it can be reviewed from
the PR alone** — stamps, what you ran and on which build, the conventions
below — without re-running your work or arguing taste. Pure rewording or
restructuring of a skill fails that test (there is no CI; a skill's only
quality measure is whether an agent following it succeeds live), so keep it
in your fork — typo and broken-command fixes excepted. Anything else that
fails the test — new mods, ports (Linux, other agent ecosystems),
redesigns — also belongs in your fork.

Review is best-effort — everything gets read, I just can't promise when.
**Issues are welcome as a shared rot-log** — "X broke on v0.41" helps
every user even before any fix lands.

## The process, start to finish

1. **Found rot? File it.** Open an issue with the "Rot report" form: the
   claim, what you expected, what actually happened, on which build.
   Filing is already a contribution — the issue list is a shared rot-log
   that warns every fork before any fix exists. Issues aren't triaged on
   a schedule: I confirm them as I next touch that area, and anyone —
   including you — can pick one up and turn it into a PR.

2. **Fix it in your fork.** You can't create branches on this repo —
   that's how GitHub works for everyone, not a snub. Fork, branch *in
   your fork*, commit there. Label every BeamNG claim per the rule below.

3. **Verify it live** through your agent and the skills (see Testing
   changes) — there is no CI that can run the game for you. Your
   verification is sufficient when the PR can answer four questions:
   *which claim changed, what you ran, on which game build, and what it
   showed*. That's the whole bar — if it's met, I don't re-run your work.

4. **Open the PR** from your fork's branch to this repo's `main`. GitHub
   pre-fills the description with this repo's template, which asks for
   exactly the four answers above.

5. **Review.** Best-effort — everything gets read, no promised timeline.
   What gets checked is public, so you can pass it on the first try:

   - The four verification answers are present and coherent, and stamps
     follow the labeling rule.
   - **Every line of the diff is read as executable.** `.ps1` and Lua
     because they run on users' machines — and `SKILL.md` too, because
     agents execute its instructions as surely as a shell runs a script.

   Hard red lines — declined outright, whatever the intent:

   - **Any executable network destination other than `127.0.0.1:23512`.**
     No downloads, no telemetry, no "fetch the latest X". (Links in prose
     for humans to click are fine.)
   - **Anything unreviewable line-by-line**: binaries, encoded or
     obfuscated blobs, minified content, wholesale rewrites.
   - **Skill or doc text that steers an agent outside the skill's stated
     task** — that's prompt injection; skill files are attack surface.
   - The standing rules below: no copied game files, no auto-load vector
     for the bridge, no secrets or personal paths.

   Expect speed to scale with surface: a stamp bump merges fastest; new
   executable surface (a new script or skill) gets read hardest. This
   list is what makes review possible, not a contract — passing it
   doesn't oblige a merge, and judgment stays human.

6. **Merged = the new baseline.** Your stamp becomes the fact every fork
   builds on, git history carries your credit, and the linked issue
   closes. Then we all move on to the next bit of rot.

## The one rule that matters: label your knowledge

Every claim about BeamNG behavior must carry one of three labels; the first
two include the game build they were checked against — the version is part
of the label, not optional garnish, because without it the claim cannot age
honestly:

- **VERIFIED vX.Y.Z** — you ran it against that live build and it worked.
- **SOURCE-READ vX.Y.Z** — you read it in that build's shipped Lua source
  (`<steam install>\lua\ge\`) but did not run it. Cite the file path.
- **UNCONFIRMED** — plausible, from docs/inference/memory. Fine to record,
  but say so. No version — nothing was checked.

Unlabeled claims are treated as UNCONFIRMED. To keep stamping cheap, docs
state one baseline in their header ("VERIFIED against v0.39.4.0 unless a
claim carries its own label"); an inline label without a version inherits
it. Never hand-downgrade a stamp — an aging build number is itself the
staleness signal. Re-verified a whole doc on a newer build → bump its
baseline; re-verified one claim → give that claim its own inline stamp. When a doc and the live engine disagree, the engine wins:
re-derive the fact (live probe first, shipped Lua source second, official
docs last), correct the doc, and update its stamp.

New docs under `references/` need a provenance header with a one-line
re-verify check — copy the pattern from any existing file there.

## What not to contribute

- **No BeamNG game files.** No copied Lua, flowgraphs, art assets, or JSON
  from the game install — not even "just as a reference". Referencing a
  shipped file by *path*, or quoting a few lines to document behavior, is
  fine; wholesale copies are a licensing violation and will be rejected.
- **No auto-loading the bridge.** `mods/llm-bridge` must never gain a
  `scripts/modScript.lua` or any other auto-run vector. Loading the bridge
  stays a deliberate, manual act. See `SECURITY.md`.
- **No secrets or personal paths.** Use `$env:LOCALAPPDATA` /
  `%LOCALAPPDATA%`, never a literal user path.

## Testing changes

Test the same way the README describes building: through your agent and
the skills — you prompt, the skills drive the scripts.

- Deploy: *"sync the `<name>` mod"* (the `sync-mod` skill).
- Verify live behavior: *"probe X through the bridge"* (the `bng-exec` and
  `probe-runtime` skills), and check `beamng.log` for what actually
  happened.
- For mission/drill work, the `debug-mission-launch` skill documents the
  known failure modes — consult it before filing an issue about a black
  screen or missing gates.

There is no CI that can run the game; the "test suite" is the live engine.
State in your PR what you ran and on which game build — the PR template
asks for exactly this.

## Skills stay standalone

Each skill under `.claude\skills\` is a self-contained module: plain
markdown plus the scripts it uses, no links out to other repo docs for
essential facts. If a fact matters to a skill, embed it in the skill —
duplication between skills is accepted; broken cross-references are not.

## Licensing of contributions

Contributions are accepted under MIT, except changes to
`mods\llm-bridge\lua\ge\extensions\llmBridge\server.lua`, which stays under
bCDDL-1.1 (keep its header intact). See the Licensing section of the README.
