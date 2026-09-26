# Harness support — Zed

**Status:** ⚠️ **Degraded tier (verified 2026-09-26, Zed v1.21.0)** — the native Zed agent has no lifecycle hooks, so the framework's bash gates cannot block a tool call inside it. The adapter ships the skills Zed loads and installs the tool-permission rules Zed can enforce. Every other gate is advisory. Zed's second path — Claude Code as an ACP External Agent — keeps the full `.claude/` layer.

There is no live end-to-end conformance proof for the native agent, because there is no blocking gate to prove. Do not read this page as an enforcement claim.

## Two Zed paths

| Path | What runs | Enforcement |
|------|-----------|-------------|
| **Claude Agent over ACP** | Claude Code runs as an External Agent in the Agent Panel. It owns its own auth and reads `CLAUDE.md` and `.claude/` itself. | **Full.** The `.claude/` layer is unchanged, so hooks, skills, agents and markers behave exactly as they do outside Zed. Zed Skills do not apply in External Agent threads. |
| **Native Zed agent** | Zed's built-in agent, using `AGENTS.md` and `.agents/skills/`. | **Degraded.** Generated skills plus user-level tool-permission rules. Everything else is advisory. |

Under the native agent, Zed reads `AGENTS.md` first. The **Zed overlay** section of `AGENTS.md` points the agent at `CLAUDE.md` and at the rules it should load on demand.

## Gate status under the native agent

| Gate | Status | Mechanism |
|------|--------|-----------|
| `git add -A`, `git add --all`, `git add .` | **denied** | Installer rule on the `terminal` tool. |
| `gh pr merge`, `gh api .../merge` | **denied** | Installer rule on the `terminal` tool. |
| `gh pr create`, `gh issue create` | **confirm** | Installer rule on the `terminal` tool. |
| Ticket-first (`require-active-ticket.sh`) | advisory | No hook fires. The agent must follow `CLAUDE.md` on its own. |
| Merge gate — Rex marker plus the per-PR human nod (`block-unreviewed-merge.sh`) | advisory | Denied command patterns cover the direct `gh` merge commands; the marker check itself does not run. |
| Red-CI merge block (`block-merge-on-red-ci.sh`) | advisory | Same. |
| Reviewer read-only (`block-reviewer-repo-mutation.sh`) | advisory | `spawn_agent` gives the subagent the parent's tools. The spawn prompt must instruct the reviewer not to modify the repository. |
| Secrets scan (`check-secrets.sh`, `check-private-refs-*.sh`) | advisory | No hook fires on a Zed edit or commit. |
| AgDR required for architecture changes | advisory | No hook fires. |
| Branch name, commit format, PR title, PR body, one-ticket validation | advisory | The agent follows the rules from `.claude/rules/`; nothing blocks a bad value. |
| Migration gate, architecture-review gate, design gate | advisory | No hook fires. |
| Privileged escalation block (`block-privileged-escalation.sh`) | advisory | No command patterns are installed for it today. |

Harness-independent layer, still active under either Zed path: the git-native hooks in `.githooks/` block a direct commit or push to a protected branch for any terminal `git` command, once `core.hooksPath` points at `.githooks/` (`bin/install-git-hooks.sh`). That layer reads git's own refs, so it does not depend on the agent.

The deny rules are pattern-level, not semantic: they match the documented command shapes. Zed parses chained commands and checks each sub-command, so `cd repo && git add -A` still matches (see `docs/harnesses/zed-capabilities.json`, `tool_permissions.chained_commands`).

## How it works (transport)

`bin/sync-zed-adapter.sh` emits one tree:

- `.claude/skills/` → `.agents/skills/`, one directory per skill.

The export comes from the shared step in `bin/_lib-adapter-skills.sh`, which the Codex generator also calls. Both generators therefore write the same bytes into `.agents/skills/`, and running them in either order leaves both `--check` commands green (`docs/agdr/AgDR-0166-zed-native-agent-adapter.md`).

The export projects each `SKILL.md` frontmatter to the fields Zed documents — `name`, `description`, `disable-model-invocation` — and drops the Claude-only presentation fields (`argument-hint`, `allowed-tools`, `effort`). Codex reads only `name` and `description`, so the projection costs it nothing.

The adapter deliberately generates **no** hook files, agent files, or rule copies. Zed has nowhere to load them from; a generated file that never runs would be a false enforcement claim.

`bin/install-zed-adapter.sh` merges the tool-permission rules into the operator's Zed user settings:

- **deny**: `git add -A` / `--all` / `.`, `gh pr merge`, `gh api .../merge`
- **confirm**: `gh pr create`, `gh issue create`

The deny patterns mirror `.claude/hooks/block-git-add-all.sh` and `.claude/hooks/block-unreviewed-merge.sh`, so the rule is the same rule, expressed in the one place Zed can express it. Zed matches case-insensitively by default, so `git add -a` is caught too.

Zed reads `settings.json` as JSONC, and its default file starts with `//` comments. The installer rewrites only a strict-JSON file. For a JSONC file, `--check` works as usual, but an install or uninstall that needs a change writes nothing. It prints the rule block to merge by hand and exits 3. A rewrite would delete your comments. The installer refuses a file with no top-level JSON object, such as an empty or comment-only file, so `--check` cannot report rules that are absent.

## How to generate and install

```bash
bin/sync-zed-adapter.sh           # generate .agents/skills
bin/sync-zed-adapter.sh --check   # verify the generated tree (non-zero on drift)
bin/install-zed-adapter.sh        # merge the tool-permission rules (per machine)
bin/install-zed-adapter.sh --check
```

The installer writes `<settings>.bak-<timestamp>` before it changes anything, preserves every existing key, and is safe to run twice. Zed detects settings changes automatically; no restart is needed. Use `--settings <path>` to target a non-default settings file, and `--uninstall` to remove only ApexYard's rules.

`/sync-zed-adapter` runs both checks, regenerates drift, and re-runs the installer rules. It also fetches the live Zed sources and compares them with [`zed-capabilities.json`](zed-capabilities.json), so a Zed release that ships (for example) `agent.hooks` is reported with its source URL and version.

## Merges

Merges go through `tracker_pr_merge`, whose wrapper runs the merge gates ([AgDR-0162](../agdr/AgDR-0162-dispatch-merge-gates-inside-wrappers.md)). Do not run `gh pr merge` or `gh api .../merge` directly — the installed rules deny both.

## Preconditions

- **Project-local skills need a trusted worktree.** Zed loads `<worktree>/.agents/skills/` only from a trusted worktree; an untrusted clone shows no skills.
- **Each developer runs the installer.** The rules live in user settings, so they are per machine, not per repository.
- Run the generator from inside an ApexYard ops fork.

## Gaps + tracking

- No lifecycle hooks. The ticket-first gate, the merge-marker guard, the secrets scan and the reviewer read-only rule stay advisory. If Zed ships the proposed `agent.hooks` setting (zed-industries/zed#57890), `/sync-zed-adapter` reports it and a follow-up adds a hooks transport that delegates to the unmodified `.claude/hooks/*.sh` scripts.
- No project-level tool permissions are documented, so the install step is per developer. Recorded as `unverified` in the capability manifest.
- The capability check depends on the structure of Zed's documentation pages. A redesign breaks the fetch, and the skill must report `unknown` rather than "no change".

## Related AgDRs

- [AgDR-0166](../agdr/AgDR-0166-zed-native-agent-adapter.md) — the Zed adapter decision: generated skills, installed rules, advisory remainder
- [AgDR-0086](../agdr/AgDR-0086-hooks-stay-bash-not-ported.md) — hooks stay bash (why the adapter does not port a gate)
- [AgDR-0088](../agdr/AgDR-0088-codex-adapter-generation.md) — the generate-from-`.claude/` pattern this adapter follows
- [AgDR-0162](../agdr/AgDR-0162-dispatch-merge-gates-inside-wrappers.md) — merge gates run inside `tracker_pr_merge`

---

*Part of [ApexYard](https://github.com/me2resh/apexyard) — multi-project SDLC framework for Claude Code · MIT.*
