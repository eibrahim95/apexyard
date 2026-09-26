# /handover step 8.6 — offer the "Governed by ApexYard" badge

Step 8.6 of `.claude/skills/handover/SKILL.md` loads this file. It runs only when document row 9 was selected in step 5.6.

## Selection + preconditions

- **Selection condition**: run this step only when row 9 (`"Governed by ApexYard" badge`) was selected in step 5.6. It is **default-OFF** — the operator must consciously tick it (or name it in the comma-list). If not selected, skip silently and note `Badge: not selected` in the summary.
- **Clone precondition**: a local clone is required to branch + PR. If `$CLONE_STATUS` is `declined` or `failed`, skip with a one-line note: `Badge: skipped (no local clone — re-run with the repo cloned into workspace/<name>/)`. The repo root is `$WORKSPACE_DIR/<name>/` (resolve via `portfolio_workspace_dir`).
- **Confirm before any target-repo write.** Editing a third-party repo's README is externally visible and easy to regret — ask explicitly, every run, default No:

  ```
  Add a "Governed by ApexYard" badge to <name>'s README?

  This inserts one badge line near the top of the README, on a new branch,
  and opens a PR for the repo owner to review. No direct commit.

    [![Governed by ApexYard](https://img.shields.io/badge/governed_by-ApexYard-2F6DF6?style=flat-square)](https://github.com/me2resh/apexyard)

  Add this badge to <name>'s README? [y/N — default N]
  ```

  Default **N**. On anything other than an explicit yes, skip and note `Badge: declined` in the summary.

## Pick the variant (governed_by vs built_with)

On a yes, offer the second badge variant for repos that were built with apexyard from the start rather than adopted into its governance after the fact:

```
Which wording fits <name>?

  [1] Governed by ApexYard   (adopted into apexyard's SDLC — the /handover case)
  [2] Built with ApexYard    (built with apexyard from the start)

[1/2 — default 1]
```

Record the pick as `$BADGE_VARIANT` (`governed_by` or `built_with`). The two canonical badge snippets — use these verbatim, never re-derive the URL by hand:

```markdown
[![Governed by ApexYard](https://img.shields.io/badge/governed_by-ApexYard-2F6DF6?style=flat-square)](https://github.com/me2resh/apexyard)
```

```markdown
[![Built with ApexYard](https://img.shields.io/badge/built_with-ApexYard-2F6DF6?style=flat-square)](https://github.com/me2resh/apexyard)
```

Brand blue `#2F6DF6`, `flat-square` style — keep both fixed; don't invent a third variant or a different color/style on your own initiative.

## Idempotency check (never double-add)

Before writing anything, scan the target repo's README for either badge already present:

```bash
source "$(git rev-parse --show-toplevel)/.claude/hooks/_lib-read-config.sh"
source "$(git rev-parse --show-toplevel)/.claude/hooks/_lib-portfolio-paths.sh"
WORKSPACE_DIR=$(portfolio_workspace_dir)
REPO="$WORKSPACE_DIR/<name>"

README_FILE=$(ls "$REPO"/README.md "$REPO"/README.MD "$REPO"/Readme.md "$REPO"/README 2>/dev/null | head -1)

if [ -z "$README_FILE" ]; then
  BADGE_STATUS="skipped (no README found in target repo)"
elif grep -qiE 'img\.shields\.io/badge/(governed_by|built_with)-apexyard' "$README_FILE"; then
  BADGE_STATUS="skipped (badge already present in README)"
fi
```

- **No README found** → skip; note `Badge: skipped (no README found)`. Don't create one just to hold a badge.
- **Badge already present (either variant)** → skip; note `Badge: skipped (already present)`. Never add a second badge or swap the existing variant — a human who wants to change variants edits the README directly.
- Otherwise, proceed to insertion.

## Insert near the top of the README (idempotent, one line)

Insert the chosen badge markdown directly below the first top-level heading (`# Title`) in the README — the conventional badge position. If the README has no top-level heading, insert as the first line of the file.

```bash
cd "$REPO" || exit 1
awk -v badge="$BADGE_MARKDOWN" '
  NR==1 && /^# / { print; print ""; print badge; inserted=1; next }
  { print }
  END { if (!inserted) print badge }
' "$README_FILE" > "$README_FILE.tmp" && mv "$README_FILE.tmp" "$README_FILE"
```

(`$BADGE_MARKDOWN` is the exact snippet for `$BADGE_VARIANT` chosen above, passed in verbatim — do not reconstruct it inline in the `awk` script.)

## Write, branch, and open the PR

Mirrors step 8.5's delivery mechanics. If step 8.5 already opened (or is about to open) a PR on `docs/agents-md` in this same run, prefer adding the badge commit onto that same branch/PR instead of opening a second trivial PR — ask once: `Add the badge to the same AGENTS.md PR (branch docs/agents-md), or open a separate PR? [same/separate — default same]`. Otherwise (no AGENTS.md PR this run), open a dedicated branch:

```bash
cd "$REPO" || exit 1
DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
DEFAULT_BRANCH=${DEFAULT_BRANCH:-main}
git checkout -b docs/apexyard-badge "origin/$DEFAULT_BRANCH" 2>/dev/null || git checkout -b docs/apexyard-badge

git add "$README_FILE"   # specific file, never -A / -.
git commit -m "docs: add Governed-by-ApexYard badge to README"
git push -u origin docs/apexyard-badge
gh pr create --base "$DEFAULT_BRANCH" --head docs/apexyard-badge \
  --title "docs: add Governed-by-ApexYard badge" \
  --body-file <(cat <<'BODY'
## Summary
- Adds a "Governed by ApexYard" badge near the top of the README, linking back to `https://github.com/me2resh/apexyard` — a visible signal that this repo follows apexyard's SDLC (offered opt-in during `/handover`, not auto-applied).

## Testing
- Confirm the badge renders correctly and the wording (`Governed by` vs `Built with`) matches how this repo actually uses apexyard.

_Generated by apexyard `/handover` — review & refine or close if you'd rather not carry the badge._
BODY
)
```

Notes:

- **Keep the branch name `docs/apexyard-badge` exactly** — same exact-literal exemption in `validate-branch-name.sh` as step 8.5's `docs/agents-md`. A renamed branch re-arms the ticket-ID gate and blocks the push. See me2resh/apexyard#1161 and AgDR-0129.
- **Specific-file staging only** — `git add "$README_FILE"`. Never `git add -A` / `git add .`.
- **Branch + PR, never a direct commit to the default branch.** The repo owner reviews before merge — `/handover` does not merge the PR.
- This PR lives in the **target repo's** tracker/SDLC, not the ops fork's. The ops-fork merge gates (Rex/CEO markers) don't apply.
- On `gh pr create` failure (issues disabled, no push rights, etc.): report the error and the branch name, leave the local branch in place, and continue to step 9. Do not retry.

## Record for the summary

```bash
BADGE_STATUS="PR opened: <url> (<variant>)"   # or "preserved (already present)" | "declined" | "not selected" | "skipped (no clone)" | "skipped (no README)" | "failed: <reason>"
```

