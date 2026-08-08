# BeamNG World Editor reference

> **Provenance:** verified against BeamNG.drive v0.39.4.0. The game updates; where
> this doc and the live engine disagree, the engine wins — correct this doc
> when you find rot.
> **Re-verify:** this file is an index — re-verify each linked doc via its own
> Re-verify line rather than this one.

Source-verified facts about the BeamNG world editor, scoped to a
parallel-parking mission (3-point-turn / hill-park / route surfaces flagged
for later work). Derived by reading the editor's own Lua under
`<steam>\lua\ge\extensions\editor\` and
`...\gameplay\missionTypes\` — the engine source is the source of truth where the
official docs are thin (and they are thin on the technical specifics here).

Path placeholders used throughout:
- `<steam>` = the BeamNG.drive install folder (Steam → right-click the game →
  Manage → Browse local files). `lua\` is loose on disk under this folder; most
  other engine Lua is also loose, art is in `gameengine.zip`.
- `<uf>` = the userfolder at `%LOCALAPPDATA%\BeamNG\BeamNG.drive\current\`
  (or Launcher → Manage User Folder → Open in Explorer) — where the editor
  *writes* content.

## Authoring style

LLM-driven editor work: **prefer console Lua** (reproducible, version-controllable,
an LLM can emit it directly) and fall back to GUI click-paths only where no Lua
surface exists. Console = `~` key. See [console-quickref.md](console-quickref.md)
for copy-paste snippets.

## Files

| File | Pull it in when… |
|------|------------------|
| [mission-editor.md](mission-editor.md) | Creating/editing any mission: opening the editor, mission ID rules, start trigger, attaching prefabs, save paths, the scriptable `gameplay_missions_missions` API. |
| [precision-parking.md](precision-parking.md) | Building or debugging a **parallel-parking** mission specifically — its fixed files, the dual-start gotcha, and the end-condition behavior. |
| [sites-editor.md](sites-editor.md) | Placing **parking spots** (precisionParking needs these) or **zones** (turn-boundary and trigger-zone use cases). |
| [prefab-and-scenetree.md](prefab-and-scenetree.md) | Packing objects (e.g. two parked cars) into a `.prefab.json` via the Scenetree, or spawning a prefab. |
| [traffic-manager.md](traffic-manager.md) | Placing **parked, AI-disabled** vehicles before packing them into a prefab. |
| [console-quickref.md](console-quickref.md) | You want the Lua to *do* an editor op (create mission, set start pos, pack prefab, place car, set AI off) instead of clicking menus. |

Driving the editor **from outside the game** (the HTTP bridge that runs
GE-Lua remotely) is covered by the `bng-exec` skill at
`.claude/skills/bng-exec/SKILL.md` — the console snippets above are exactly
what gets sent through it.

## Conventions used across these files

- `<steam>` = the BeamNG.drive install folder. `<uf>` = the userfolder root
  (`%LOCALAPPDATA%\BeamNG\BeamNG.drive\current\`).
- Paths starting with `/` are **engine virtual paths** (FS-rooted; they resolve
  across the install + userfolder + mods). The editor reads/writes these.
- "verified" = read from the engine Lua this session. "doc" = from
  documentation.beamng.com. Where they disagree, the disagreement is called out.
