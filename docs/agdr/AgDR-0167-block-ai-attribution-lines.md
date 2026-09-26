# Block AI attribution lines in commits and PR descriptions

> In the context of agents that write commit messages and PR descriptions, facing AI attribution lines that the repository owner had to remove by rewriting and force-pushing `main`, I decided to turn off harness attribution, strip the lines at the git layer, and block them at the agent-command layer, so that no agent path adds them by default, accepting that the git-layer strip only works in clones with `core.hooksPath=.githooks`.

## Context

- Agents added `Co-Authored-By: Claude …`, `Claude-Session: …` and the `🤖 Generated with Claude Code` footer to commits and PR bodies.
- On a squash merge, GitHub copies each commit message into the squash body. It also appends a `Co-authored-by` line for each co-author trailer it finds.
- On 2026-09-26, three commits on `main` were rewritten and force-pushed to remove these lines. Nothing in the framework prevented them.
- Claude Code has an `attribution` setting. The settings reference documents `commit`, `pr` and `sessionUrl` sub-keys, and marks `includeCoAuthoredBy` as deprecated.
- Other harnesses (Codex, Zed, pi) do not read `.claude/settings.json`. Git runs `.githooks/*` for every author when `core.hooksPath` points at it.
- This change touches the trust chain (`.claude/hooks/**`, `.claude/settings.json`, `.githooks/**`). It is material under `agdr-decisions.md` rail 1.

## Options Considered

| Option | Pros | Cons |
|---|---|---|
| Harness setting only | One line. Stops Claude Code at the source | Covers Claude Code only. A system instruction or another harness can still add lines |
| Harness setting + commit-msg strip + agent-command block | Covers every harness at the git layer and every agent command at the hook layer | Three places to maintain. Needs one shared pattern list |
| Reject in commit-msg instead of strip | The author sees the fault | An agent told by its harness to add a trailer fails and retries the same commit |
| Server-side check (CI on commit messages) | Cannot be skipped locally | Runs after the push. The lines are already public in the branch history |

## Decision

Chosen: **harness setting + commit-msg strip + agent-command block, with one shared pattern list.**

- `.claude/settings.json` sets `attribution` to `{"commit": "", "pr": "", "sessionUrl": false}`. This is the form the settings reference gives for settings files that older Claude Code versions also read.
- `.claude/hooks/_lib-attribution.sh` owns the pattern list and the find and strip functions. `.attribution.blocked_patterns` in the project config overrides the list.
- `.githooks/commit-msg` strips matching lines and prints each removed line. It strips instead of rejecting so that an agent does not loop on a failing commit.
- `block-ai-attribution.sh` blocks `git commit`, `gh pr create`, `gh pr edit` and `gh pr merge` when the command text or a named message or body file carries a matching line. It fires in managed-project clones without `core.hooksPath`, and it still fires for `git commit --no-verify`.
- `/approve-merge` passes an explicit squash subject and body built from the PR's commits with the lines removed.

Each default pattern is anchored to the start of a line. Prose that mentions a trailer mid-sentence passes. A human co-author trailer matches no default pattern.

## Consequences

- New commits and PRs from Claude Code in this fork carry no attribution by default.
- Commits from any harness in a clone with `core.hooksPath=.githooks` lose the lines before Git records them.
- An agent command that carries a line fails with a message that names the line.
- A squash merge through `/approve-merge` uses `<PR title> (#N)` as the subject and a body built from the commits. This replaces GitHub's default body assembly for gh-kind projects.
- Limits:
  - `git commit --no-verify` from a human, or a clone without `core.hooksPath`, skips the git-layer strip.
  - The agent-command block reads command text. A message built at run time, for example from a variable, can pass it.
  - `tracker_pr_merge` honours the subject and body only on gh-kind projects. A glab-kind squash merge keeps the forge default body.
  - A harness can change its attribution text. The pattern list then needs an update.

## Artifacts

- [Issue #12](https://github.com/eibrahim95/apexyard/issues/12)
- [Claude Code settings reference, "Git and attribution"](https://code.claude.com/docs/en/settings-reference)
