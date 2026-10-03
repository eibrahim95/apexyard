---
name: prototype-full-ui
description: Build a clickable static-HTML prototype of every screen from a PRD and screen inventory, in parallel and mobile-first.
disable-model-invocation: false
argument-hint: "<IDEA-ID | inbox-path> [--out <dir>] [--impl-model <name>] [--review-model <name>]"
allowed-tools: Bash, Read, Write, Glob, Grep, Agent
effort: high
---

# /prototype-full-ui — Orchestrate a Full Clickable HTML Prototype

Read `.claude/rules/writing-standard.md`. Use the controlled technical writing profile for the files this skill writes (`README.md`, `NOTES.md`, `DESIGN.md`, reviews).

This skill turns a PRD, a screen inventory, and journey files into a folder of plain HTML files. A person opens `index.html` through a local server and clicks through every screen. It replaces designer work in Figma or Claude Design for the question "what should this look and feel like?".

It is the full-product sibling of `/prototype`. `/prototype` files a throwaway-prototype ticket. This skill does the build. The output is **throwaway**: it decides a direction and is never lifted into production code. Same AgDR and coverage exemptions as `/prototype` apply. Rex review, the Glossary in the PR body, and the disposition gate (`/prototype-close`) still apply.

> **You are the orchestrator.** You plan, split, spawn sub-agents in parallel, collect results, and run checks. You do not write most pages yourself. Read this whole file before you act.

## Usage

```
/prototype-full-ui IDEA-001
/prototype-full-ui IDEA-001 --impl-model deepseek-v4.1-flash --review-model glm-5.3-flash
/prototype-full-ui /abs/path/to/projects/_inbox --out /abs/path/to/output
```

| Argument | Meaning | Default |
|----------|---------|---------|
| `<IDEA-ID \| inbox-path>` | The idea to prototype, or a folder that holds its PRD, wireframes, and journeys | required |
| `--out <dir>` | Output folder | `<portfolio projects dir>/_inbox/prototype/<idea-slug>-html/` |
| `--impl-model <name>` | Model for implementer sub-agents | `deepseek-v4.1-flash` |
| `--review-model <name>` | Model for reviewer sub-agents | `glm-5.3-flash` |

Set the model on each sub-agent through the harness. If a named model is not available, stop and report the exact name that failed. Do not silently use another model. The reviewer model must differ from the implementer model. The orchestrator uses its own model.

## Before you start

1. Resolve paths with the portfolio helper. Do not hardcode them.

   ```bash
   source "$(git rev-parse --show-toplevel)/.claude/hooks/_lib-read-config.sh"
   source "$(git rev-parse --show-toplevel)/.claude/hooks/_lib-portfolio-paths.sh"
   projects_dir=$(portfolio_projects_dir)
   ```

2. Locate the source material (section "Source material"). If the PRD or the screen inventory is missing, stop and tell the operator which skill produces it (`/write-spec`, `/journey`, `/wireframes`). Do not guess screens.
3. Check for an active ticket. If a hook blocks writes, ask the operator to run `/prototype` to file the ticket and `/start-ticket` to activate it. Do not work around the hook.

## 1. Goal and non-goals

**Goal.** A folder of plain HTML files. The person opens `index.html` and clicks through **every screen in the inventory**. The look and feel match the real stack (section 3).

**Non-goals.**

- No backend, no database, no API calls.
- No build step, no npm install, no framework compile.
- No real PDF, payment, authentication, or AI. Fake each one with a convincing screen.
- Do not copy designs from Figma, Claude Design, or any other product.

Optimise for speed of learning and for how the product feels. Do not optimise for code quality or reuse.

## 2. Source material

Look in `<projects_dir>/_inbox/` and in `projects/<name>/` for these. Read them in full before you plan.

| Source | What it gives you |
|--------|-------------------|
| PRD (`prds/<IDEA>-*.md`) | The product: user stories, requirements, milestones, edge cases |
| Screen inventory (`wireframes/screen-inventory.md` and `.json`) | The **screen list**: IDs, entry and exit links, wireframe content, variants. This is your build checklist. |
| Journey files (`journeys/*.yaml`, `*.html`) | Flow and steps. Use for flow only. Do not copy their styling. |
| Wireframe image or Excalidraw file | Layout hints only |
| Validation note (`validation/*.md`), if present | Why the product exists and who it is for |

The inventory is the source of truth for **which screens exist** and **where each links to**. If the inventory and a journey file disagree, follow the inventory and record the disagreement in `NOTES.md`.

Placeholders in the PRD stay placeholders. Where the PRD says `TBD` (plan names, prices, limits), show invented sample values marked "(sample)" and list them in `NOTES.md`.

## 3. The stack: match its look and feel

The real product uses the stack below. The prototype uses the front-end layer and fakes the server layer.

| Stack piece | Role in the real product | How you use it here |
|-------------|--------------------------|---------------------|
| **Basecoat** (shadcn-style CSS) | Components: buttons, cards, inputs, badges, dialogs, tabs, sidebar | Use directly. Use its class names and design tokens. |
| **Tailwind CSS** | Utility styling and tokens that Basecoat expects | Use the browser build (v4). |
| **Unpoly** | Navigation without full reloads. Modals, drawers, partial updates. | Use directly. See the rules below. |
| **Alpine.js** | Small client-side state: toggles, tabs, drawers, forms | Use directly for every interactive widget. |
| **django-cotton** | Reusable components written as HTML tags | Cannot run. Copy the idea (component convention below). |
| **Tera or django-unicorn** | Server-side templates and server-driven state | Cannot run. Replace with fake data (section 5). |

### Library loading

Pick one approach for every page.

1. **Preferred.** Download each library once into `assets/vendor/` and load by relative path. The prototype then works offline.
2. **Fallback.** Load from `https://cdn.jsdelivr.net/npm/…` with a pinned version.

Load: Tailwind (browser build, v4), Basecoat CSS and JS, Unpoly (v3, JS and CSS), Alpine.js (v3). **Verify each URL with a real download before you rely on it.** Do not invent a path. If a path fails, search for the correct one.

### Serving

Unpoly loads pages with `fetch`, and browsers block that on `file://`. The prototype must run through a local server. Put this at the top of `README.md`:

```bash
cd <output-dir> && python3 -m http.server 8080
```

### Unpoly rules

- Every page is a **full valid HTML document** and also works when opened at its own URL.
- Use `up-follow` on links. Use `up-target` so only the main content area swaps. The sidebar and bars stay in place.
- Modals, drawers, sheets, and confirm dialogs use `up-layer="new modal"` or `"new drawer"` and point at a small HTML fragment.
- Use `up-history` so the browser back button works.
- Do not write your own router. Do not use `window.location` for navigation, except for the sign-in resume demo.

### Alpine rules

- Use `x-data`, `x-show`, `x-model`, `x-for`, and `@click` for local widget state.
- Keep Alpine state small. Fake server state lives in `assets/data.js`.
- Inline `<script>` is fine for small things.

### Component convention (replaces django-cotton)

Write each reusable piece as a plain HTML snippet with a marker comment so a developer can later turn it into a Cotton component:

```html
<!-- c-component: book-card  props: book -->
<article class="card"> … </article>
<!-- /c-component -->
```

Use consistent snippets for the app shell, cards, progress bars, page headers, empty states, banners, and list items. Repeat the markup in each page. Do not build a runtime include system.

### Server-side markers

Where the real product renders data on the server, add a one-line comment above the block:

```html
<!-- server: for item in in_progress_items -->
```

The block itself renders from fake data with Alpine `x-for`. These comments help the real build team later.

## 4. Design direction

Give the product its own identity inside the Basecoat style. You decide the details.

**Fixed.**

- It must look modern. Read the PRD's problem statement for the specific design pressure (for example, a rejected competitor that "does not feel modern").
- Match the tone the PRD implies (for example, calm and encouraging, not nagging).
- It must be **mobile first and fluid**. See "Responsive design" below.
- It must meet WCAG AA contrast and have visible focus states.
- Support light and dark mode with Basecoat's tokens. A toggle in the shell is enough.

**Free (your creative room).**

- Accent colour, type pairing, corner radius, spacing rhythm.
- The look of any generated imagery. Use CSS gradients, inline SVG, and text. No external images.
- The signature element of the product's key screen (the PRD names the differentiator). Make it the most memorable part of the home screen.
- The chrome of the core task screen.
- Small delights: transitions, empty-state art built from CSS or SVG, progress animation.

Make **three** choices in Phase 0 and write them in `assets/DESIGN.md`: accent colour, font pairing, and the visual form of the product's signature element. Every sub-agent reads that file and follows it.

Do not use Lorem Ipsum. Write real, believable sample copy.

### Responsive design (mobile first, fluid)

Design and build the phone layout first. Then add complexity as space grows. Do not design for desktop and shrink it down. Do not build for a list of device widths.

**Method.**

1. Write base styles for a narrow screen with no media query. Add `sm:`, `md:`, `lg:`, and `xl:` Tailwind prefixes (min-width) only to add things as space allows. Never use max-width overrides to undo a desktop layout.
2. Place a breakpoint where the **content** starts to break, not where a device starts. Resize the page. Find the width where text wraps badly, a card squeezes, or a gap looks empty. Add a change there.
3. Keep the set of layout breakpoints small. Use Tailwind defaults unless a screen clearly needs another. Say which one you added in a comment.
4. Let layouts flow without breakpoints where possible. Use CSS Grid with `auto-fit` and `minmax()`, flexible `gap`, `max-width` on reading text, and percentage or `fr` widths. Avoid fixed pixel widths on containers.
5. Use **container queries** (`@container`) for components that live in different places, such as a card in a narrow shelf and in a wide grid. Use media queries only for page structure: navigation, sidebar, column count.
6. Use **fluid type** with `clamp()`. Include a `rem` term so the user's font setting still works. Keep body text at least `1rem`. Do not write a separate font size per breakpoint.
7. Test at **many widths**, from about 320 px to about 1920 px, and at the in-between widths a tablet or a resized window uses. There must be no horizontal page scroll at any width. Only a code block or a wide table may scroll sideways, inside its own container.
8. Check portrait and landscape on a phone-sized window.

**Mobile behaviour to design on purpose.**

- **Navigation.** Bottom bar on small screens. Sidebar when there is room. The bottom bar pads for the home-indicator area with `env(safe-area-inset-bottom)`. Add `viewport-fit=cover` to the viewport meta tag.
- **Thumb reach.** Put primary actions in the lower part of the screen. Do not put precise actions in the top corners.
- **Touch targets.** At least 44 × 44 px. Use 48 px or more for primary actions. Keep at least 8 px between neighbouring targets. The visible control can be smaller if padding extends the tap area.
- **Edges.** Keep important controls at least 16 px from the screen edge. Keep a side gutter of at least 16 px on all content.
- **Progressive disclosure.** On small screens, show the most important content first. Move secondary content into a drawer, sheet, accordion, or tab. Use Unpoly layers and Alpine.
- **Forms.** One column on small screens. Full-width inputs with clear labels. Use the right `type` and `inputmode` so the phone shows the right keyboard.
- **Tables and lists.** Turn a table into a stack of cards on small screens.
- **No hover-only features.** Every hover effect needs a touch equivalent. Give pressed and focus states.
- **Drawing or canvas screens.** They work with touch. Keep the toolbar inside thumb reach.
- **Images.** `max-width: 100%` and `aspect-ratio` so nothing jumps while loading.
- **Preferences.** Respect `prefers-reduced-motion`. Use `prefers-color-scheme` as the starting theme.

**Document it.** In `assets/DESIGN.md`, add a short "Responsive behaviour" list. For the app shell and each of the three busiest screens, write one line on what changes as the screen grows.

## 5. Fake data

Create **one** file, `assets/data.js`, in Phase 0. It sets `window.APP = { … }`. Every page reads from it, so names, items, and numbers stay identical across all screens.

Derive the data model from the PRD and the inventory. Include at least:

- The current user: name, email, plan, usage against each plan limit.
- 10 to 15 primary items (for a library product, books) with every field the screens show: status, progress, dates, visibility, flags, and one example of each edge case in the PRD's edge-case table.
- Every list and count a screen shows: shelves, categories, goals, schedule, notes, search results, reviews, counts, prices, plans.
- One example of each state the inventory names: sync conflict, limit reached, empty, offline, no results, permission denied.
- Admin values: plan editor fields and any percentage or sample-size settings.

Use believable names. Use only public-domain or invented titles and brands.

**Fake behaviours that need no server:**

- Upload: pick a file, show a progress animation, add the item to the in-memory list.
- AI chat: a canned reply with a typing animation, plus the limit counter.
- Payment: a fake card form that succeeds and adds the item.
- Sign-in: a fake form, then resume at the origin screen.
- Offline: a toggle in the dev panel switches the offline banner and the offline screen.

State resets on reload. Small things may persist in `localStorage`, wrapped in `try/catch`.

**Prototype controls.** A small corner button opens a drawer with: dark mode, offline toggle, jump-to-screen list (every screen), empty-state toggle, and admin toggle. This makes review easy.

## 6. Output structure

Write everything under the output folder:

```
<out>/
  README.md        how to run, what is faked, the screen map
  NOTES.md         gaps, assumptions, disagreements, unresolved TBDs, EXTRA items
  index.html       screen-list page: every screen grouped by journey, each a link
  assets/
    DESIGN.md      the three design choices, tokens, responsive behaviour
    app.css        shared styles on top of Basecoat
    app.js         shared Alpine helpers, prototype-controls drawer
    data.js        window.APP fake data
    link-map.json  allowed entry and exit links per screen (from the inventory)
    vendor/        downloaded libraries
  screens/<group>/ one folder per journey, plus hub/ and cross/ for shared screens
  fragments/       modal, drawer, and sheet fragments loaded by Unpoly
  reviews/         reviewer findings
  screenshots/     per-screen captures
```

**File naming.** One file per screen, named by the screen ID in the inventory, lowercase. Do not rename IDs.

**Variants** (loading, empty, error, offline) are **not** separate files. Show them inside the screen through Alpine state or the prototype-controls drawer. The inventory marks which states earn their own screen.

## 7. Execution plan

Follow the phases in order. Parallelise inside a phase. Do not skip a phase.

### Phase 0: foundation (you, alone, no sub-agents)

1. Read all source files.
2. Create the folder structure.
3. Download the vendor libraries. Verify each loads.
4. Write `DESIGN.md`, `app.css`, `app.js`, and `data.js`.
5. Build **one reference screen**, the most central hub screen (usually the home screen), with the shared app shell: navigation, top bar, content area, and prototype-controls drawer.
6. Open the reference screen in a headless browser. Resize it across about 320 px to 1920 px in steps, plus portrait and landscape phone. Capture the narrowest, the widest, and each width where the layout changes. Fix anything broken. This screen is the **pattern every other screen copies**.
7. Generate `assets/link-map.json` from `screen-inventory.json`.

Do not start Phase 1 until the reference screen looks right. A bad foundation is copied dozens of times.

### Phase 1: build (parallel, implementer model)

**Partition the screens.** Group them by journey. Give shared hub screens and cross-cutting screens to dedicated owners. Use **4 to 8** implementers. Each owns a disjoint set of files. Every screen ID in the inventory has exactly one owner. No agent edits a file it does not own. You own the reference screen.

Use the subagent type from `.claude/rules/agent-role-selection.md` (`frontend-engineer` for page building). Set the model with `--impl-model`. Pass `isolation: "worktree"` only if agents could collide. Disjoint files normally make that unnecessary.

Spawn all implementers **in one message** so they run at the same time.

**Each implementer's brief must contain:**

- The full text of sections 3, 4, 5, and 6 of this file.
- The path to the reference screen: "Match its shell, spacing, and component usage."
- Paths to the PRD, the inventory, `link-map.json`, `data.js`, and `DESIGN.md`.
- The exact list of screen IDs it owns, with the inventory rows pasted in.
- The rules in section 9 and the product rules in section 8.
- The instruction to report back with: files written, anything faked, anything it could not do.

### Phase 2: review (parallel, reviewer model)

Spawn one reviewer per implementer, **in one message**. Each reviews only that implementer's files. A reviewer **reports and fixes nothing**. It writes findings to `reviews/<owner>.md`.

For each screen it owns, the reviewer checks:

1. **Coverage.** Does the screen show every item in the inventory's "Wireframe content"? List missing items.
2. **Links.** Does every entry and exit link in `link-map.json` exist and point at a real file? Does every button that should go somewhere go there?
3. **Stack.** Basecoat classes used, not hand-rolled equivalents? Unpoly on navigation? Alpine for widgets? Page opens standalone?
4. **Consistency.** Same shell, same data, same names as the reference screen and `data.js`?
5. **Responsive.** Open in a headless browser. Sweep the width from about 320 px to 1920 px in steps of about 100 px, then check portrait and landscape phone sizes. Report: horizontal page scroll at any width, overflow, overlap, squeezed or stretched components, tap targets under 44 px, fixed bars that ignore safe-area insets, hover-only features, and desktop-first code (max-width overrides that undo a desktop layout). Name the width where each problem appears.
6. **Accessibility.** Contrast, visible focus, labels on inputs, alt text, heading order.
7. **Product rules.** The rules in section 8 that apply to the screen.
8. **Copy.** No Lorem Ipsum, no placeholder text, no broken sample data.

Each finding has: screen ID, severity (blocker, major, minor), what is wrong, and the line or element. A reviewer must **not** report a pass for a check it did not run. If it cannot open a headless browser, it writes "not verified" for the responsive check.

### Phase 3: fix (parallel, implementer model)

Send each implementer its own review. It fixes all blockers and majors, and minors if cheap. It reports what it fixed and what it left, with the reason.

### Phase 4: integration (you)

1. Run a link check over every HTML file. Every `href`, `up-follow` target, and fragment path must resolve. Fix or report broken ones.
2. Confirm every screen ID in the inventory has a file, and that `index.html` lists all of them.
3. Walk each journey end to end in a headless browser. Take a screenshot per screen at a narrow phone width, a mid width, and a wide desktop width into `screenshots/`. Name each file with the screen ID and the width.
4. Spawn **one** final reviewer (reviewer model) to compare five random screens against the PRD acceptance criteria. Fix what it finds, or log it.
5. Write `README.md` and `NOTES.md`.

Stop after Phase 4. Do not run more than **one** extra fix round. If a blocker remains, log it in `NOTES.md` and finish.

## 8. Product rules the screens must show

Derive these from the PRD. Each acceptance criterion that describes something the user sees or does must appear in the screens that the inventory traces to it. Pull out the rules a screen could easily get wrong and paste them into every implementer brief. Typical classes:

- **Defaults** (for example, "new items are private by default").
- **Two-option decisions** (for example, a sync prompt with "go to" and "stay").
- **Limits and gates** (the screen that states the limit and offers a plan change).
- **Things that must NOT appear** (for example, "no download control on public items", "counts only, never who").
- **Required inputs before an action** (for example, a licence type and a source link before making a book public).
- **Edge-case states** from the PRD's edge-case table. Each one must appear somewhere.

A reviewer checks the applicable rules for each screen. See the worked example at the end.

## 9. Rules for every agent

1. Edit only the files you own.
2. Read `DESIGN.md` and the reference screen before you write.
3. Use the shared data in `data.js`. Do not invent a second set of items or names.
4. Use Basecoat classes. Do not hand-roll something Basecoat provides. Shared custom CSS goes in `app.css` only through the orchestrator. Page-specific CSS goes in a `<style>` block in that page.
5. Every navigation link uses Unpoly. Every modal or drawer uses an Unpoly layer pointing at a fragment.
6. No backend code, no API calls, no build steps.
7. No external images or fonts outside the vendor folder. Use inline SVG and CSS gradients.
8. Never claim a check passed unless you ran it. Say "not verified" instead.
9. No AI attribution lines in any file.
10. Finish with a short report: what you built, what you faked, what you skipped, and why.

## 10. Creative latitude

This file fixes the **content**, the **links**, the **rules**, and the **stack**. It does not fix the **design**. Where it is silent, decide. Make bold, specific choices. A prototype that looks generic fails its purpose.

Propose one or two **extra touches** the PRD does not ask for and that make the product's core idea feel real (for example, a streak strip or an end-of-session summary). Mark each `EXTRA` in `NOTES.md` so the product owner can accept or drop it. Do not add any that break a rule in section 8.

## 11. Definition of done

- [ ] `index.html` lists every screen in the inventory. Each one opens.
- [ ] Every journey can be clicked end to end without a dead link.
- [ ] Every screen is built mobile first. No horizontal page scroll at any width from about 320 px to 1920 px. Layouts hold up at in-between widths, in portrait and landscape, in light and dark mode.
- [ ] The prototype-controls drawer works: dark mode, offline, jump-to-screen, empty state, admin.
- [ ] Reviews exist in `reviews/`. Every blocker and major is fixed or logged.
- [ ] `screenshots/` holds one image per screen at three widths.
- [ ] `README.md` explains how to run it and what is faked.
- [ ] `NOTES.md` lists gaps, TBD values shown as samples, inventory disagreements, and `EXTRA` items.

## 12. Final report to the operator

Write in this order:

1. The path to the folder and the command to run it.
2. How many screens work, and which, if any, do not.
3. What is faked.
4. Open issues and `EXTRA` items that need a decision.
5. Anything you could not verify, named plainly.
6. Next step: review the prototype, then run `/prototype-close --promote` or `--discard`.

Do not report a check as passed unless a tool result showed it. Do not claim a screenshot or a link check ran if it did not.

## Rules

1. **Do not build the pages yourself.** Phase 1 and Phase 3 belong to implementer sub-agents. You build only the foundation in Phase 0 and the checks in Phase 4.
2. **Stop at missing inputs.** No PRD or no screen inventory means stop and name the skill that produces it.
3. **Halt at the human gate.** Never open a PR, merge, or write an approval marker. Hand back to the operator.
4. **Budget.** Cap the run at one build round, one review round, and one fix round, plus one extra fix round at most. Report what remains.
5. **No tracker writes.** This skill creates no tickets. `/prototype` does that.

## Worked example: IDEA-001 (Reading-Continuity PDF Library)

Use this when the argument is `IDEA-001`.

**Sources** (under `<projects_dir>/_inbox/`): `prds/IDEA-001-reading-continuity-pdf-library.md`, `wireframes/screen-inventory.md` and `.json`, `journeys/rc-1…rc-5-*.yaml`, `validation/IDEA-001-validation.md`.

**Scale.** 38 screens: 24 journey-specific, 10 shared hubs, 4 cross-cutting.

**Partition (6 implementers).**

| Agent | Owns | Screens |
|-------|------|---------|
| A | `screens/rc1/*`, `screens/cross/*` | rc1 screens, X-01, X-02, X-04, X-05 |
| B | `screens/rc2/*`, `hub-ann-01`, `hub-bd-01` | rc2 screens, annotations, own-book details |
| C | `screens/rc3/*`, `hub-upl-01` | rc3 screens, upload |
| D | `screens/rc4/*`, `hub-pl-01`, `hub-pbd-01`, `hub-rdr-03` | rc4 screens, public library, public details, public reader |
| E | `screens/rc5/*` | rc5 screens (sales, purchase, admin percentage) |
| F | `hub-rdr-01`, `hub-rdr-02`, `hub-lib-02`, `fragments/*`, `index.html` | reader, sync prompt, empty home, shared fragments, screen list |

The orchestrator owns `hub-lib-01` (Library home) as the reference screen.

**Signature element.** The continuity coach on the home screen. The PRD's differentiator is that readers continue the books they start. Make the coach the most memorable part of the home screen. Keep it encouraging, never nagging.

**Fake data specifics.** Books with title, author, cover colours, page count, current page, last-read date, status, visibility, licence type and source link, shelves, categories, cleared-to-share and cleared-to-sell flags. Include a scan with no text, a purchased annotated copy, one book that advanced on another device, a goal and schedule with one conflict, bookmarks with notes, annotation strokes as SVG paths, a public library of 8 books with counts-only reader numbers, annotated copies for sale, three sample plans, admin values.

**Product rules.**

- A new book is **private by default** (US-1).
- The reader shows the "**advanced on another device**" prompt with two actions: go to the last page, or stay (US-2).
- Library home lists in-progress books with progress and last-read date, and **one** suggested next book (US-3).
- Reminders: one type, "continue this named book". The reader can turn them off. A reminder opens the book at the last-read page (US-4).
- A schedule entry names a time, a book, and minutes. Show cadence against the goal and the goal-and-schedule conflict message (US-5).
- A bookmark is a small save icon on the page with an optional note. A bookmark list per book (US-6).
- Annotations are handwritten, private by default, and visible on every device (US-6).
- Shelves are private. Categories are system-assigned. Search covers title and content and never shows another user's private book (US-7).
- AI chat counts against the plan limit. At the limit, show the limit screen with a plan-change action (US-8, X-05).
- Plans show a private-book limit and an AI limit with usage against both. The admin editor is admin-only (US-9).
- To make a book public, require a **licence type** and a **source link**. Accepted: public domain, CC0, CC BY, CC BY-SA, CC BY-NC. **ND licences are rejected** (US-10).
- Two flags: cleared to share, cleared to sell. CC BY-NC sets only the first (US-10).
- A public book has **no download control and no download route**. The uploader can download a **private** book as a backup (US-10).
- Most-read shows **counts only**, never who reads a book (US-11).
- The "other uploaded versions" check is **advisory**. It never blocks, never counts private uploads, and never names an uploader (US-12).
- An annotated copy includes handwritten annotations only, **not** bookmarks or notes. A buyer sees a sample of annotated pages before paying. The default sample is the first 5 annotated pages (US-13, US-14).
- After payment the copy is in the buyer's library and can be downloaded as a PDF. This is the **only** download of a public book (US-14).
- The sync, offline, empty, scan-without-text, and limit states from the PRD's edge-case table each appear somewhere.

---

*Part of [ApexYard](https://github.com/me2resh/apexyard) — multi-project SDLC framework for Claude Code · MIT.*
