# Review checklist (reviewers read this)

You review one builder's files. You report. You fix nothing. Write findings to `reviews/<agent>.md` in the output folder.

For each screen, run these checks. A check you did not run is "not verified". Never report a pass for it.

1. **Coverage.** Does the screen show every item in the inventory's "Wireframe content"? List the missing items.
2. **Links.** Does every entry and exit link in `assets/link-map.json` exist and point at a real file? Does every button that should navigate do so?
3. **Stack.** Basecoat classes used, not hand-rolled equivalents? Unpoly attributes on navigation? Alpine for widgets? Page opens standalone?
4. **CSS rule.** Run `grep -nE '<style|style=' <files>`. Report every hit. Only the data-driven colour binding is allowed. Report any hand-named class.
5. **Detector.** Run `impeccable detect <files>`. Paste the output. Report each finding with its screen ID.
6. **Consistency.** Same shell, data, and names as the reference screen and `data.js`?
7. **Responsive.** Open each page in a headless browser. Sweep the width from about 320 px to 1920 px in steps of about 100 px. Check portrait and landscape phone sizes. Report, with the width where each appears:
   - horizontal page scroll
   - overflow, overlap, squeezed or stretched components
   - tap targets under 44 px
   - fixed bars that ignore safe-area insets
   - hover-only features
   - desktop-first code (max-width overrides that undo a desktop layout)

   If you cannot open a headless browser, write "not verified".
8. **Accessibility.** Contrast (4.5:1 body, 3:1 large), visible focus, labels on inputs, alt text, heading order.
9. **UX.** Answer each for the screen:
   - Is the one primary action obvious in under three seconds?
   - Is it in thumb reach on a phone?
   - Does the screen show system status (progress, saved, offline, limit)?
   - Can the person undo or back out?
   - Does every control name its action? Does every error name the problem and the recovery?
   - Does the screen follow the three design choices and the world in `DESIGN.md`, or does it look generic?
10. **Product rules.** The rules in `PRODUCT-RULES.md` that apply to the screen.
11. **Copy.** No Lorem Ipsum. No placeholder text. No broken sample data.

## Finding format

Screen ID · severity (blocker, major, minor) · what is wrong · the line or element.

A blocker stops a journey or breaks a product rule. A major breaks a responsive, accessibility, or CSS-rule check. A minor is everything else.
