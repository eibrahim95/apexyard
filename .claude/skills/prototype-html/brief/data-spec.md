# Fake data and prototype controls

## `assets/data.js`

One file. It sets `window.APP = { … }`. Every page reads from it. Entities, names, and numbers stay identical across all screens.

Derive the data model from the PRD, the inventory, and `PRODUCT-RULES.md`. Include at least:

- **Current user**: name, email, plan, usage against every plan limit the PRD names.
- **The core entities** the screens list or open. Use 10 to 15 of the main one. Give each every field a screen shows: title, status, dates, progress, visibility, owner, and any flags the product rules name.
- **One example of every state** the inventory or the PRD edge cases name: empty, loading, error, offline, limit reached, conflict, sync, permission denied.
- **Lists the screens render**: recent items, suggestions, search results, notifications, reviews, counts. Write enough rows to look believable.
- **Plans and admin values**, if the PRD has them. Mark every invented value "(sample)".
- **Short-text content**: snippets, notes, comments, reviews. Real sentences only.

Use diverse, believable names. Use only invented or public-domain titles. No Lorem Ipsum.

PRD placeholders (names, prices, limits, percentages) stay TBD in the PRD. Show invented values marked "(sample)". List them in `NOTES.md`.

## Faked behaviours

Fake every server action the inventory implies, with a convincing screen:

- **Upload or create**: pick input, show a progress animation, add the item to the in-memory list.
- **AI or async work**: a canned reply with a typing animation, plus the limit counter if the PRD has a limit.
- **Payment**: a fake form that succeeds and updates the in-memory state.
- **Sign-in**: a fake form, then resume at the origin screen.
- **Offline**: a toggle switches the offline banner and the offline screen.

## Prototype controls

A small "Prototype controls" button in the corner opens a drawer. It holds: dark mode, offline toggle, jump-to-screen list (all screens), empty-state toggle, admin toggle (if the PRD has an admin role).

Controls state must survive navigation and direct page loads. Keep it in one Alpine store backed by `localStorage` under the key `<project>.controls`. Wrap storage access in try/catch and fall back to defaults. Data changes (uploads, purchases) may reset on reload.

Variants (loading, empty, error, offline) are not separate files. Show them inside the screen through the store. The inventory marks which states earn their own screen.
