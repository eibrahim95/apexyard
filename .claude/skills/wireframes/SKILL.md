---
name: wireframes
description: Break user journeys into screens, then wireframe them. Excalidraw when the MCP exists, otherwise Mermaid in .md files.
disable-model-invocation: false
argument-hint: "[<project>] [--journeys <dir|yaml...>] [--prd <path>] [--renderer excalidraw|mermaid] [--inventory-only] [--update]"
allowed-tools: Bash, Read, Grep, Glob, Write, Agent, ToolSearch, mcp__excalidraw__describe_scene, mcp__excalidraw__snapshot_scene, mcp__excalidraw__import_scene, mcp__excalidraw__get_canvas_screenshot, mcp__excalidraw__set_viewport
effort: high
---

## Writing rule

When this skill writes a durable artifact, read .claude/rules/writing-standard.md. Use the controlled technical writing profile.

# /wireframes — Screen inventory and wireframes from user journeys

`/journey` maps pages and transitions. `/wireframes` goes one level down. It splits each page into the screens a designer must draw, then wireframes every screen. A page with several big states yields several screens. A button that flips from disabled to enabled does not.

## When to use

| Trigger | Use `/wireframes`? |
|---------|-----------------|
| Journeys exist (`/journey`) or a PRD has flows, and design or build is next | Yes |
| You need a count of what must be designed before sizing a milestone | Yes. Use `--inventory-only` |
| High-fidelity mockups, visual design, design tokens | No. That is UI Designer work |
| A flow with no screens yet (still deciding pages) | No. Run `/journey` first |

## Activated role

Activate the **[UX Designer](../../../roles/design/ux-designer.md)** (Iman). She owns flows and information architecture. This is in-flow work, so adopt the persona in-thread. When the source has more than about 30 journey pages, delegate the inventory to the `ux-designer` sub-agent. Have it write to a scratch path, not the repo. Read the result before you draw. See [`.claude/rules/role-triggers.md`](../../rules/role-triggers.md).

## Path resolution

Resolve the docs dir from the portfolio helper. In split-portfolio mode it points at the sibling portfolio repo, so never build the path from the current repo.

```bash
source "$(git rev-parse --show-toplevel)/.claude/hooks/_lib-read-config.sh"
source "$(git rev-parse --show-toplevel)/.claude/hooks/_lib-portfolio-paths.sh"
projects_dir=$(portfolio_projects_dir)
```

Repeat that preamble in every bash block that writes under `${projects_dir}`. Each block is a separate shell. Outputs go to `${projects_dir}/<name>/wireframes/`. For a project not yet registered, use `_inbox` as the name, next to its `journeys/`.

## Usage

```
/wireframes                                   # ask for project and source
/wireframes _inbox --journeys journeys/       # all journey YAML files in a folder
/wireframes checkout --prd prds/checkout.md   # derive pages from a PRD
/wireframes checkout --inventory-only         # stop after the inventory
/wireframes checkout --renderer mermaid       # force the Mermaid fallback
/wireframes checkout --update                 # re-render from the saved screen-inventory.json
```

## Process

### 1. Resolve project and sources

Use the same project resolution as `/journey`. Read every journey YAML (`pages`, `transitions`, `personas`, `notes`) or the PRD. Read the PRD even when journeys exist. The PRD is the authority for scope and `TBD` values.

### 2. Split pages into screens

A state is its own **screen** when most of these hold:

| Rule | Test |
|------|------|
| R1 | The user's goal or task changes |
| R2 | The primary action or option set changes |
| R3 | It has its own navigation: back target, deep link, interruption, resume |
| R4 | The layout is substantially different |
| R5 | It is a decision or commitment point: confirm, payment, permission, limit reached |

A state is a **variant** of its screen, not a screen, when content and actions stay the same and only data or status change. Examples: loading, skeleton, empty with the same actions, inline validation, selected, toast, dropdown, tooltip. A modal is a screen only when it has its own flow or decision. When a split is close, keep one screen and list the variant. Flag the close calls with `"debatable": true`.

### 3. Dedupe hubs and find cross-cutting screens

- Pages that repeat across journeys (home, reader, details) get **one** screen with a stable ID. Other journeys reference the ID. Use `hub-<area>-NN`.
- Journey-only screens use `<journey>-sNN`. Screens that interrupt any journey (offline, sign-in, limit reached) use `X-NN` and are listed once.
- Write a dedupe map from each YAML page id to its stable screen ID(s).

### 4. Define each screen

For every screen record: ID, name, parent page, which rule(s) made it a screen, entry from, exit to, platform, kind (`primary` or `state-screen`), 3 to 8 wireframe regions, and its variants.

- Ground regions **only** in the PRD and journey text. Do not invent features.
- Keep `TBD` as `TBD`. Keep uncertainty words such as "may".
- Mark a screen the source never defines as `"grounded": "no"`. It renders as a gap-derived proposal.
- List every place the journeys imply a screen the source does not define. These are the flagged gaps.

### 5. Write the inventory

Write `screen-inventory.md` for people and `screen-inventory.json` for the renderers. The Markdown opens with the outcome: counts per journey, unique total after dedupe, and the five most debatable split calls with a fallback for each. JSON schema:

```json
{"title": "...", "sections": [{"key": "rc1", "title": "...", "subtitle": "...", "color": "#d3f9d8", "ids": ["rc1-s01"]}],
 "screens": [{"id": "rc1-s01", "journey": "rc1", "name": "...", "parent_page": "...", "kind": "primary",
   "platform": "both", "regions": ["..."], "variants": ["..."], "entry_from": ["..."], "exit_to": ["..."],
   "debatable": false, "grounded": "yes"}]}
```

`sections` is optional. Without it the scripts group hubs, cross-cutting screens, then one section per `journey`. Stop here for `--inventory-only`.

### 6. Pick the renderer

Default to Excalidraw when its MCP exists. Check with `ToolSearch` for `excalidraw`. If tools named `mcp__excalidraw__*` come back, use Excalidraw. Otherwise use Mermaid. `--renderer` overrides the check. State the choice and the reason in one line before drawing.

### 7a. Excalidraw path

1. Run `describe_scene`. **Never clear a canvas that has content.** It may hold someone else's diagram.
2. Run `snapshot_scene` as a restore point when the canvas is not empty.
3. Generate the scene. Set `--origin-x` past the right edge of any existing content, with a gap of at least 400. Use `0` for an empty canvas.

   ```bash
   python3 .claude/skills/wireframes/scripts/gen_excalidraw.py \
     --inventory "${projects_dir}/<name>/wireframes/screen-inventory.json" \
     --out "${projects_dir}/<name>/wireframes/wireframes.excalidraw" \
     --title "<feature> screen wireframes" --origin-x <x> --origin-y <y>
   ```

4. Merge it with `import_scene` (`mode: merge`, `filePath`). The server reads only inside its allowed directory, which is the ops root unless `EXCALIDRAW_EXPORT_DIR` says otherwise. In split-portfolio mode, copy the file to a scratch path under the ops root, import it, then delete the copy. Do not pass hundreds of elements inline as `data`.
5. Run `get_canvas_screenshot`. Save the PNG as `overview.png` next to the scene. Check a full-size crop: text fits its box, tags show, nothing overlaps.

Cards show regions in reading order, grouped per screen. This is structural wireframing, not page layout. Say so in the report.

### 7b. Mermaid path

```bash
python3 .claude/skills/wireframes/scripts/gen_mermaid.py \
  --inventory "${projects_dir}/<name>/wireframes/screen-inventory.json" \
  --out-dir "${projects_dir}/<name>/wireframes/mermaid" --title "<feature> screen wireframes"
```

It writes `index.md` and one `.md` per section. Each file has a flow diagram and one wireframe diagram per screen. GitHub and most Markdown viewers render the blocks natively.

### 8. Verify

- The rendered screen count equals the inventory count.
- Every screen shows its regions, its variants, and its From and To IDs.
- Every `TBD` from the source is still `TBD`.

If you could not view the render, say so. Do not call it checked.

### 9. Report

Open with the outcome: unique screen count, per-journey counts, renderer used. Then give the debatable calls, the flagged gaps, and where the files live. Do not commit unless asked. The output sits in a repo that may have its own uncommitted work.

## Rules

1. **No invention.** A screen or region without a source line is a flagged proposal, never a quiet addition.
2. **Count honestly.** The count changes with the split rule. Report the rule and the close calls.
3. **Shared canvas is not yours.** Snapshot, offset, merge. Never clear.
4. **Screen IDs are not tickets.** `rc1-s01` names a screen. Do not write it as `#N` or as a blocked-by link. See [`ticket-vocabulary.md`](../../rules/ticket-vocabulary.md).
5. **Advisory output.** This skill gates nothing. Wireframes inform design. They do not replace the design review.

## Method sources

- Screen-inventory practice: one row per screen with purpose, entries, exits and a state checklist. Loading, empty, error and success are variants unless the task changes.
- Excalidraw wireframing: grayscale shapes, left-to-right frames, state notes on the canvas, SVG or PNG export.
- Existing Claude skills for the same job: `ThomasPraun/ux-flow-designer` (flows, state diagrams, HTML wireframes) and `crit-screen-inventory` (screen extraction and state enumeration).

Scripts and a smoke test live in `scripts/` and `tests/`. The fixture is `fixtures/sample-inventory.json`.
