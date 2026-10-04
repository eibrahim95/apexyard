# Responsive design: mobile first, fluid

Build the phone layout first. Add complexity as space grows. Do not design for desktop and shrink it. Do not build for a list of device widths.

## Method

1. Write base styles for a narrow screen with no prefix. Add `sm:`, `md:`, `lg:`, `xl:` (min-width) only to add things as space allows. Never use max-width overrides to undo a desktop layout.
2. Put a breakpoint where the content breaks, not where a device starts. Resize. Find where text wraps badly, a card squeezes, or a gap looks empty. Add a change there.
3. Keep breakpoints few. Use Tailwind defaults unless a screen needs another. Say so in an HTML comment.
4. Let layouts flow without breakpoints where possible: CSS Grid `auto-fit` with `minmax()`, flexible `gap`, `max-w` on reading text, `fr` or percent widths. Avoid fixed pixel widths on containers.
5. Use container queries (`@container`) for components that live in different places, such as a book card in a narrow shelf and a wide grid. Use media queries only for page structure: navigation, sidebar, column count.
6. Use fluid type with `clamp()` and a `rem` term. Keep body text at least `1rem`. Do not set a font size per breakpoint.
7. Test from about 320 px to about 1920 px, including in-between widths. No horizontal page scroll at any width. Only a code block or a wide table may scroll sideways, inside its own container.
8. Check portrait and landscape on a phone-sized window.

## Mobile behaviour to design on purpose

- **Navigation.** Bottom bar on small screens. Sidebar when there is room. Pad the bottom bar with `env(safe-area-inset-bottom)`. Use `viewport-fit=cover`.
- **Thumb reach.** Put primary actions (continue, save, upload, pay) in the lower part of the screen. Keep precise actions out of the top corners.
- **Touch targets.** At least 44 × 44 px. Use 48 px or more for primary actions. At least 8 px between targets. Padding may extend the tap area.
- **Edges.** Side gutter of at least 16 px on all content. Controls at least 16 px from the screen edge.
- **Progressive disclosure.** Show the most important content first on small screens. Move the rest into a drawer, sheet, accordion, or tab.
- **Forms.** One column on small screens. Full-width inputs with clear labels. Use the right `type` and `inputmode`.
- **Tables.** On small screens, turn a table into a stack of cards. Do this for every data table and comparison grid.
- **No hover-only features.** Every hover effect needs a touch equivalent. Give pressed and focus states.
- **Content-heavy and canvas screens.** A reading or editing surface fits the screen width and keeps controls out of the way. Touch must work on any drawing or drag surface. Its toolbar stays in thumb reach. A phone shows one pane. A wide screen may add a side panel.
- **Covers.** `max-width: 100%` and `aspect-ratio`, so nothing jumps on load.
- **Preferences.** Respect `prefers-reduced-motion`. Start from `prefers-color-scheme`.

## Document it

In `DESIGN.md`, add a "Responsive behaviour" list. For the app shell, the home screen, and the two most complex screens, write one line on what changes as the screen grows.
