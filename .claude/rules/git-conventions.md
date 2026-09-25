# Git Conventions

## Branch Naming

Format: `{type}/{TICKET-ID}-{description}`

Examples:

- `feature/ABC-123-add-auth`
- `fix/GH-45-login-bug`
- `docs/ENG-99-update-readme`

**Types**: `feature`, `fix`, `refactor`, `chore`, `docs`, `test`, `spike`, `prototype`, `ci`, `build`, `perf`

The `TICKET-ID` should reference an issue in the project's tracker. Default format: `#58` or `GH-58` (GitHub Issues). The validators in `.claude/hooks/` source the regex from `.tracker.id_pattern` in `.claude/project-config.{defaults,}.json` — the default pattern also matches any uppercase tracker prefix (e.g. `ABC-123`) for teams using Linear, Jira, or similar. See `_lib-tracker.sh` and AgDR-0033 for how to swap the active tracker; ApexYard's out-of-the-box default is per-project GitHub Issues, with one repo's issues never crossing into another repo's PRs.

## PR Title Format

Must match: `type(scope): description` or `type(scope)!: description` (breaking change). The scope is a lowercase component name, for example `feat(auth): add session refresh`. See AgDR-0165.

Link the ticket in the PR body with a closing keyword: `Closes #58` (GitHub Issues) or `Closes ABC-123` (Jira / Linear / similar). The validator checks that the ticket exists and is open. Use a bare `#N`; a cross-repo `owner/repo#N` does not count.

- One ticket per PR
- Breaking changes use `!` before the colon: `feat(api)!: remove deprecated v1 endpoints`

## Commit Message Format

```
type: subject
type!: subject (breaking change)
type(scope)!: subject (breaking change with scope)

- Detailed change 1
- Detailed change 2

Closes #123
```

**Types**: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`, `perf`

## File Staging

**NEVER** use `git add -A`, `git add .`, or `git add --all`. Always add specific files:

```bash
git add src/specific-file.ts
```

This is enforced by the `block-git-add-all.sh` hook.

## No Direct Main

Every change must go through a PR. Zero exceptions. No commits directly to `main`/`master`. Enforced at the git layer by `.githooks/pre-push` (terminal `git push`) and `.githooks/pre-commit` (terminal `git commit`) — both read git's own ground-truth ref/branch resolution, no command-text parsing (me2resh/apexyard#1086). `.claude/hooks/block-main-push.sh` is a blocking **backstop** on top: a Claude Code PreToolUse hook, so it stays effective against `--no-verify` (which structurally bypasses the two git-native hooks above) and on managed-project clones that haven't installed `core.hooksPath` (#1088). See [AgDR-0114](../../docs/agdr/AgDR-0114-block-main-push-honest-naming-blocking-backstop.md) for the full control-vs-backstop rationale.

## No Hardcoded Secrets

No API keys, passwords, tokens, or credentials in code. Use environment variables. Patterns to avoid:

- `api_key=`, `password=`, `secret=`, `token=`
- Cloud account IDs and ARNs
- Database connection strings
- Private keys or certificates

Enforced by the `check-secrets.sh` hook.

---

*Part of [ApexYard](https://github.com/me2resh/apexyard) — multi-project SDLC framework for Claude Code · MIT.*
