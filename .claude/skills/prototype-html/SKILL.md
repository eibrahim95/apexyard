---
name: prototype-html
description: Build a clickable HTML prototype from a PRD and screen inventory via parallel agents and impeccable. Throwaway.
argument-hint: "<project-name> [prd-path]"
allowed-tools: Bash, Read, Write, Agent, AskUserQuestion
---

# /prototype-html — Build a Clickable HTML Prototype from a PRD

Read `.claude/rules/writing-standard.md`. Use the **controlled technical writing profile** for `README.md`, `NOTES.md`, and every agent brief. Remove empty sections.

This skill builds a static, clickable HTML prototype. It replaces designer work in Figma. A person opens it in a browser and clicks through every screen in the inventory. The look matches the real stack: Basecoat, Tailwind, Unpoly, and Alpine.

It is the build step for a throwaway UX prototype. It files no ticket. Use [`/prototype`](../prototype/SKILL.md) to track the work, and [`/prototype-close`](../prototype-close/SKILL.md) to decide whether to promote or discard it. The skill reads the PRD, the journeys, and the screen inventory. Produce them first with `/write-spec`, `/journey`, and `/wireframes`.

**You write no code.** You plan, spawn sub-agents, send findings back, run commands, and write Markdown. Read this whole file and every file in `${SKILL_DIR}/brief/` before you act.

## Requirements

- The `impeccable` skill must be installed. Find it in this order: `<ops-root>/.claude/skills/impeccable`, `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/impeccable`, `$HOME/.agents/skills/impeccable`. Call the directory found `${IMPECCABLE}`. If none exists, stop and tell the operator to install it. Do not invent an install command.
- `python3` and a headless browser (Playwright or Chrome) for the link check, the screenshots, and the width sweeps. If none exists, stop and say so.
- A screen inventory at `${projects_dir}/<name>/wireframes/screen-inventory.json`. If it is missing, stop and tell the operator to run `/wireframes`.

## Path resolution

Resolve paths with the helpers. Do not hardcode them. Repeat this preamble in every bash block, because each block is a separate shell.

```bash
source "$(git rev-parse --show-toplevel)/.claude/hooks/_lib-read-config.sh"
source "$(git rev-parse --show-toplevel)/.claude/hooks/_lib-portfolio-paths.sh"
projects_dir=$(portfolio_projects_dir)
SKILL_DIR="$(git rev-parse --show-toplevel)/.claude/skills/prototype-html"
```

| Name | Value |
|------|-------|
| `<name>` | The first argument. Use `_inbox` for a project that is not registered yet. |
| `PRD` | The second argument, or the only file in `${projects_dir}/<name>/prds/`. Ask when there are several. |
| `INV` | `${projects_dir}/<name>/wireframes/screen-inventory.{md,json}` |
| `JOURNEYS` | `${projects_dir}/<name>/journeys/` |
| `OUT` | `${projects_dir}/<name>/prototype/<slug>-html/`. Confirm the slug with the operator. |
| `BRIEF` | `${SKILL_DIR}/brief/` |

Pass absolute paths in every sub-agent brief. A sub-agent does not share your shell variables.

## Goal and non-goals

**Goal.** Plain HTML files. A person opens `OUT/index.html` through a local server and clicks through every inventory screen. The UI and UX are good enough that the product owner can judge the product from them.

**Non-goals.** No backend, database, or API calls. No build step. No real file rendering: fake it in HTML and Tailwind. Fake authentication, payment, and AI with convincing screens. Do not copy designs from Figma, Claude Design, or any product.

This is a throwaway. Optimise for speed of learning and for how the product feels, not for reuse.

**Source of truth.** The inventory decides which screens exist and where each links. If a journey file disagrees, follow the inventory and log it in `NOTES.md`. Leave PRD placeholders alone. Show invented values marked "(sample)" and log them.

## Step 1: Setup (before any sub-agent)

1. **Ask the operator for two models.** Do not hardcode names. Ask for the **implementer** model (builds screens) and the **reviewer** model (reviews them). They must be different models. Prefer different families. If the operator picks two from one family, say that the review is less independent, and proceed only on confirmation.
2. **Probe both.** Spawn a one-line probe agent on each model with the Agent tool's `model` parameter. If a model is unavailable, stop and report the exact name that failed. Never substitute another model.
3. **Lead model** is your own model. The design, build, and gate agents run on it. Pass it explicitly in the `model` parameter. Do not leave it to a default.
4. If `OUT` already exists, ask the operator: archive it to `OUT.prev-<date>`, wipe it, or stop.
5. Read the PRD, the inventory (`.md` and `.json`), the journeys, and all of `BRIEF`.

## What you may and may not do

| You may | You may not |
|---------|-------------|
| Spawn and message sub-agents | Create or edit `.html`, `.css`, `.js`, `.json`, `.py`, or `.sh` files |
| Run commands: downloads, `python3 -m http.server`, a headless browser, `impeccable detect`, tools a sub-agent wrote | Fix a sub-agent's code yourself, even a one-line fix |
| Write Markdown: `README.md`, `NOTES.md` | Write a script. Ask a lead-model agent to write it. |
| Send findings back to the agent that owns the file | Reassign a file mid-phase without noting it in `NOTES.md` |

## Agent types

Pick `subagent_type` from the work (see `.claude/rules/agent-role-selection.md`).

| Work | `subagent_type` |
|------|-----------------|
| Foundation build, screens, fixes | `frontend-engineer` |
| Design agent and design gate | `ui-designer` |
| Reviewers | `ux-designer` |

Do not use `code-reviewer` for a reviewer. It writes approval markers and posts to pull requests. No pull request exists here.

`ui-designer` and `ux-designer` run no browser CLI. You run the screenshot script and give them its output.

## Design and UX: use `impeccable`

`impeccable` covers UI and UX: `shape` (task and UX discovery), `critique` (UX review with heuristic scoring), `audit`, `clarify`, `onboard`, `harden`. Run every `impeccable` command with `OUT` as the working directory.

- **Design agents (lead model)** load the skill with the Skill tool. If the tool is missing, they read `${IMPECCABLE}/SKILL.md` and follow it.
- **Builders and reviewers (other models)** do not load the whole skill. They read `PRODUCT.md`, `DESIGN.md`, and `${IMPECCABLE}/reference/craft-floor.md` by path, and run `impeccable detect <files>`. Put the resolved craft-floor path in each brief.
- `PRODUCT.md` and `DESIGN.md` live in `OUT` root. They win over everything in the skill.
- The skill's own rule applies: verify in bounded passes, not a loop. Use the caps below.

**Fixed design pressure.** Read the PRD problem statement and name what the current alternatives get wrong. The prototype must answer that first. It must feel modern, calm, and focused. It must be mobile first and fluid (`BRIEF/responsive.md`). It must meet WCAG AA contrast with visible focus. It must support light and dark mode through Basecoat tokens.

**Free.** Accent colour, font pairing, corner radius, spacing rhythm, the look of the main entity's visual, the product's signature moment, and small delights. Write three choices in `DESIGN.md`: accent colour, font pairing, and the signature element. Real copy only. Do not use a progress ring as the signature: the craft floor lists it as a default to avoid.

## Step 2: Foundation (lead model, three agents in sequence)

**2a. Design agent (`ui-designer`).**

1. Download the vendor libraries and fonts (`BRIEF/stack.md`). Check each file.
2. Run `impeccable init` seeded from the PRD. Write `PRODUCT.md`. Report missing answers to the orchestrator. Ask the operator only for what the PRD cannot answer.
3. Write `PRODUCT-RULES.md`: every testable rule in the PRD user stories and edge cases, one line each, with the story ID. A reviewer checks screens against it.
4. Run `impeccable shape` for the home screen: the task, the one primary action, the first-viewport content.
5. Write `DESIGN.md`: the three choices, tokens, the token mechanism that works with the Tailwind browser build, and the responsive list from `BRIEF/responsive.md`.
6. Write `assets/app.css`: tokens, `@font-face`, Basecoat token overrides, theme keyframes. Nothing else. If the browser build cannot read it, also write `assets/tokens.css` (see `BRIEF/stack.md`). You are the only agent that edits these files.

**2b. Build agent (`frontend-engineer`).**

1. Write `assets/data.js` and `assets/app.js` (Alpine store, prototype-controls drawer) per `BRIEF/data-spec.md`.
2. Build the app shell and one reference screen, the home screen: sidebar on desktop, bottom bar on phone, top bar, content area.
3. Build **every fragment** the inventory implies (modals, drawers, sheets) in `fragments/`. Write `fragments/manifest.json`. Step 3 screens link to these by path.
4. Write `index.html`: all screens grouped by journey, one link each.
5. Write `tools/`: a generator for `assets/link-map.json` from the inventory JSON, a link checker, and a journey walker. Run the generator.
6. Write the screenshot script in `tools/`. It takes a screen list and a width list. Its default mode writes images at 390, 820, and 1440 px. Its sweep mode covers 320 to 1920 px in steps of 100, plus portrait and landscape phone sizes. Sweep mode writes images and `sweep-report.json` into `screenshots/sweep/`. The report lists horizontal overflow and tap targets under 44 px, per screen and width.

**2c. Gate agent (`ui-designer`).** A separate agent from 2a and 2b. It reports and fixes nothing.

1. You run the sweep script on the reference screen first. Give the agent the image folder and `sweep-report.json`. The agent runs no browser. It marks any criterion it could not see as "not browser-verified".
2. The agent runs `impeccable critique` and `impeccable audit` on the reference screen, from the source, the images, and the report.
3. Run one fix round. Send findings on `assets/app.css`, `DESIGN.md`, or `PRODUCT.md` to a new lead-model agent in the 2a role. Send findings on the shell, the reference screen, fragments, or tools to 2b. Then run the sweep and a fresh 2c once more.
4. Do not start Step 3 while a blocker or major remains. A bad foundation is copied into every screen.

## Step 3: Build (implementer model, parallel)

Group the inventory screens by journey. Spawn one `frontend-engineer` per group, up to six. Merge small journeys. Split a journey that holds more than a third of all screens. Each agent owns a disjoint set of files. No agent edits a file it does not own. No one edits the reference screen, `fragments/`, or `assets/`. If an agent needs a change there, it reports to you. You route a change to `assets/` to a lead-model agent in the 2a role. You route a change to the shell, `fragments/`, or `tools/` to 2b.

Check the inventory so every screen ID has exactly one owner. Give an unowned screen to the lightest agent and log it. Put the hardest screen (usually the core work surface) in a group of its own.

**Each brief is short.** It gives paths, not pasted text:

- Read `BRIEF/stack.md`, `BRIEF/responsive.md`, `PRODUCT.md`, `DESIGN.md`, `PRODUCT-RULES.md`, `assets/data.js`, `assets/link-map.json`, `fragments/manifest.json`, the craft-floor path, and the reference screen. Match its shell, spacing, and component use.
- The screen IDs it owns, with the inventory rows pasted in.
- The report format from `BRIEF/stack.md`, rule 10.

## Step 4: Review (reviewer model, parallel)

Before the reviewers start, run the screenshot script in sweep mode over every screen. Reviewers read the images and `sweep-report.json`. They run no browser.

Spawn one `ux-designer` per implementer. Each reads `BRIEF/review-checklist.md` and reviews only that builder's files. Reviewers report and fix nothing. A check not run is "not verified".

## Step 5: Fix (implementer model)

Send each implementer its own review. It fixes all blockers and majors, and minors if cheap. It reports what it fixed and what it left, with the reason. Fix-round cap: this round, plus the one in Step 6, item 6.

## Step 6: Integration

1. Run the link checker over every HTML file. Send broken links to the owning agent.
2. Confirm every inventory ID has a file and the count matches the inventory.
3. Run the journey walker for every journey. Run the screenshot script into `screenshots/`. Name files `<screen-id>-<width>.png`.
4. Spawn a lead-model `ui-designer` as a critic. It runs `impeccable critique` on five screens: home, the core work surface, the main creation flow, the main detail screen, and the main conversion or payment screen. It works from the source, the images, and `sweep-report.json`. It runs no browser. It reports and fixes nothing.
5. Spawn one reviewer-model agent to compare five random screens against the PRD acceptance criteria. It reports and fixes nothing.
6. Run the one extra fix round. Send each finding from items 4 and 5 to the implementer that owns the file. Send a finding on `assets/app.css` to a lead-model agent in the 2a role. Log what remains.
7. Write `README.md` (run command first, what is faked, screen map) and `NOTES.md` (gaps, assumptions, inventory disagreements, sample values, `EXTRA` items, anything not verified).

Stop after Step 7. If a blocker remains, log it in `NOTES.md` and finish.

## Output structure

```
OUT/
  PRODUCT.md  DESIGN.md  PRODUCT-RULES.md      design context (OUT root)
  README.md  NOTES.md  index.html
  assets/   app.css  app.js  data.js  link-map.json  vendor/ (libs, fonts/)
  screens/  one folder per journey, one file per inventory ID, lowercase
  fragments/  manifest.json  …                  built in Step 2
  tools/    link-map generator, link checker, screenshot script, journey walker
  reviews/  screenshots/
```

Name each screen file by its inventory ID. Do not rename IDs.

## Creative latitude

The brief fixes content, links, rules, and stack. It does not fix the design. Where it is silent, decide, and make bold, specific choices. A generic prototype fails its purpose.

Propose one or two extra touches the PRD does not ask for. Mark each `EXTRA` in `NOTES.md`. None may break a rule in `PRODUCT-RULES.md`.

## Definition of done

- [ ] `index.html` lists every inventory screen. Each opens.
- [ ] Every journey clicks through end to end with no dead link.
- [ ] No horizontal page scroll from about 320 px to 1920 px, in portrait and landscape, in light and dark.
- [ ] `grep` finds no `<style` block and no `style=` attribute in `screens/` or `fragments/`, apart from the data-driven colour binding and the marked token block when the fallback is in use.
- [ ] `impeccable detect` reports no errors on `screens/` and `fragments/`.
- [ ] The prototype-controls drawer works and its state survives navigation and reload.
- [ ] Reviews exist in `reviews/`. Every blocker and major is fixed or logged.
- [ ] `screenshots/` holds one image per screen at 390, 820, and 1440 px.
- [ ] `README.md` and `NOTES.md` are written.

## Final report to the operator

In this order:

1. The path to `OUT` and the command to run it: `cd <OUT> && python3 -m http.server 8080`.
2. How many screens work, and which do not.
3. What is faked.
4. Open issues and `EXTRA` items that need a decision.
5. Anything you could not verify, named plainly.

## Rules

1. **No code from the orchestrator.** Delegate every script and every fix.
2. **Models are asked, never hardcoded.** The reviewer model reviews every implementer-model screen. No agent reviews its own output. A critic or gate agent reports. A different agent fixes.
3. **No custom CSS** outside `assets/app.css`. The reviewer greps for it.
4. **No AI attribution lines** in any file.
5. **Never claim a check passed unless it ran.** Write "not verified" instead.
6. **Advisory output.** The prototype gates nothing. It informs the design direction. It does not replace `/design-review` or the design gate on real UI work.
