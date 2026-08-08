<!-- The review test (CONTRIBUTING.md): this PR should be reviewable from
     what's written below alone — no re-running your work, no taste debates. -->

## What this changes

<!-- One or two sentences. -->

## Verification

- **Game build tested on:** v0.
- **What I ran** (probes, drives, log checks):
- **Stamps:**
  - [ ] Baseline bumped (whole doc re-verified on the build above)
  - [ ] Inline stamp(s) added/updated for the changed claims
  - [ ] N/A — no BeamNG behavior claims changed

## Checklist

- [ ] No copied BeamNG game files (paths and short quotes only)
- [ ] No secrets or literal user paths (`$env:LOCALAPPDATA`, not `C:\Users\...`)
- [ ] Touched skills remain standalone (no cross-doc links for essential facts)
- [ ] `mods/llm-bridge` still has no auto-load vector
- [ ] No executable network destination other than `127.0.0.1:23512` in any script, Lua, or skill
