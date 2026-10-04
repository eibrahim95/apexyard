# Stack and build rules (every agent reads this)

The real product uses Basecoat, Tailwind, Unpoly, Alpine, django-cotton, and Tera or django-unicorn. A browser cannot run the server parts. The prototype uses the front-end layer and fakes the server layer.

| Piece | Real role | Use here |
|-------|-----------|----------|
| Basecoat (shadcn-style CSS) | Component look: buttons, cards, inputs, badges, dialogs, tabs, sidebar | Use directly. Use its class names and tokens. |
| Tailwind CSS v4 | Utilities and tokens | Browser build, vendored. |
| Unpoly v3 | Navigation without reloads, modals, drawers, partial updates | Use directly. Rules below. |
| Alpine.js v3 | Small client state: toggles, tabs, drawers, forms | Use for every interactive widget. |
| django-cotton | Reusable template components | Cannot run. Use the comment convention below. |
| Tera / django-unicorn | Server templates and state | Cannot run. Use `assets/data.js` and the server markers below. |

## Libraries and fonts

Download every library and font once into `assets/vendor/`. Load with relative paths so the prototype works offline.

- Libraries: Tailwind browser build (v4), Basecoat CSS and JS, Unpoly (v3 JS and CSS), Alpine.js (v3).
- Fonts: the families chosen in `DESIGN.md`. Use at most two. Download `woff2` files into `assets/vendor/fonts/`. Declare them with `@font-face` in `assets/app.css`.
- Download each file with a real request. Check that it is not an HTML error page. If a path fails, search for the correct path. Do not invent one.
- Do not load anything from a CDN at run time. Do not use a system display font as the display voice.

## Serving

Unpoly loads pages with `fetch`. Browsers block `fetch` on `file://`. Run:

```bash
cd <output-dir> && python3 -m http.server 8080
```

## CSS rule (strict)

No custom CSS in any screen or fragment.

- Style only with Tailwind utility classes and Basecoat classes.
- Forbidden in `screens/` and `fragments/`: `<style>` blocks, `style="…"` attributes, and hand-named classes.
- One exception: data-driven colours, such as book covers or avatars. Bind them with Alpine, for example `:style="{'--c1': item.c1, '--c2': item.c2}"`. Style them with utilities such as `bg-linear-to-br from-(--c1) to-(--c2)`.
- `assets/app.css` is the only CSS file. It holds design tokens, `@font-face`, Basecoat token overrides, and keyframes declared in the theme. The design-foundation agent writes it once. Nobody else edits it.
- Tailwind's browser build compiles inline `<style type="text/tailwindcss">` blocks. It may not compile a linked file. Verify this against the pinned version. The design-foundation agent records the working token mechanism in `DESIGN.md`.
- Container queries use Tailwind's `@container` and `@md:` variants. Fluid type uses `text-[clamp(…)]` with a `rem` term, or a theme token.
- If you need a style that no utility or Basecoat class gives, report it. Do not write CSS.

## Unpoly rules

- Every page is a full valid HTML document. It also works when opened at its own URL.
- Navigation uses `<a up-follow href="…">`. Use `up-target` so only the main content swaps. The shell stays in place.
- Modals, drawers, sheets, and confirm dialogs use `up-layer="new modal"` or `up-layer="new drawer"`. Point them at a page in `fragments/`.
- Use a modal only for a task that needs interruption or protected focus (confirm, limit reached, payment). Use a sheet, drawer, or inline panel for the rest.
- Use `up-history` so the back button works.
- Do not write a router. Do not use `window.location` for navigation. The sign-in resume demo is the only exception.

## Alpine rules

- Use `x-data` for local state. Use `x-show`, `x-model`, `@click`, `x-for`.
- Fake server state lives in `assets/data.js`. Prototype controls live in the store described in `brief/data-spec.md`.
- Small inline `<script>` blocks for Alpine data are fine. No build step.

## Component convention (replaces django-cotton)

Mark each reusable piece with a comment so a developer can turn it into a Cotton component later:

```html
<!-- c-component: book-card  props: book -->
<article class="card"> … </article>
<!-- /c-component -->
```

Use it for: app shell, book card, progress bar, page header, empty state, banner, plan card, review item. Repeat the markup in each page. Do not build a runtime include system.

## Server markers

Where the real product renders data on the server, add a one-line comment above the block, and render it from `data.js` with `x-for`:

```html
<!-- server: for book in in_progress_books -->
```

## Rules for every agent

1. Edit only the files you own. Do not touch another agent's files.
2. Read `PRODUCT.md`, `DESIGN.md`, `PRODUCT-RULES.md`, and the reference screen before you write.
3. Read the impeccable `reference/craft-floor.md` (your brief gives the path) before you write UI. Follow it. `PRODUCT.md` and `DESIGN.md` win over it.
4. Use the data in `data.js`. Do not invent a second set of entities or names.
5. Follow the CSS rule above.
6. No backend code, API calls, build steps, external images, or external fonts. Use inline SVG and Tailwind gradients.
7. Before you report, run `impeccable detect <your files>`. Fix every error. List each remaining warning in your report.
8. Never claim a check passed unless you ran it. Write "not verified" instead.
9. No AI attribution lines in any file.
10. Report: files written, what you faked, what you skipped and why, detector output.
