---
name: sync-zed-adapter
description: Keep the Zed adapter current. Check .agents/skills drift and the installed tool-permission rules, compare live Zed docs with the capability manifest, open a PR for changes — never merges.
disable-model-invocation: false
argument-hint: "[--check-only]"
allowed-tools: Bash, Read, Write
---

## Writing rule

When this skill writes a durable artifact, read .claude/rules/writing-standard.md. Use the controlled technical writing profile.

# /sync-zed-adapter — Keep the Zed Adapter Current

Zed ships weekly and `.claude/` keeps changing, so the Zed adapter has two ways to go stale: the generated output drifts from `.claude/`, or Zed ships a capability the adapter does not use yet. This skill checks both and reports each result with its source.

It runs two checks:

1. **Framework drift** — compare the generated Zed output with the `.claude/` sources, and re-run the generator and the installer rules when they differ.
2. **Zed capability check** — fetch the live Zed sources and compare them with `docs/harnesses/zed-capabilities.json`.

It never merges. A merge needs Rex's approval and an explicit per-PR human nod.

## Process

### 1. Framework drift

Run the read-only check first:

```bash
bin/sync-zed-adapter.sh --check
```

A non-zero exit means `.agents/skills` differs from what `.claude/skills` would generate. Report each `DRIFT:` line, then regenerate:

```bash
bin/sync-zed-adapter.sh
```

Then check the installer rules on this machine:

```bash
bin/install-zed-adapter.sh --check
```

A non-zero exit means the Zed user settings are missing one or more rules. Report the missing rules, then install them:

```bash
bin/install-zed-adapter.sh
```

The installer writes a timestamped backup first. Report the backup path. Zed detects settings changes automatically, so no restart is needed.

Two `.claude/` sources have no generated Zed counterpart today, because Zed's native agent has no lifecycle hooks and no agent-definition files:

- `.claude/settings.json` — nothing to wire; the adapter carries the rules it can express as Zed tool permissions.
- `.claude/agents/` — no Zed agent files exist; reviewer roles are adopted through `spawn_agent` prompts instead.

Do not fabricate output for these. Re-evaluate them only when step 2 reports a new capability.

Finally, confirm the `AGENTS.md` Zed section is still present and complete. It must contain:

- the heading `### Zed overlay (native Zed agent)`
- a pointer to `CLAUDE.md`
- the list of gates that stay advisory in Zed

If any part is missing, treat it as drift and restore it through step 3 (a branch and a PR), never by editing `main` in place.

### 2. Zed capability check

Fetch the live sources. Read each one with whatever fetch tool the harness provides (the Zed native agent's `fetch`, Claude Code's `WebFetch`, or `curl` through Bash).

| Source id | URL |
| --- | --- |
| `zed-docs-skills` | https://zed.dev/docs/ai/skills |
| `zed-docs-tool-permissions` | https://zed.dev/docs/ai/tool-permissions |
| `zed-docs-tools` | https://zed.dev/docs/ai/tools |
| `zed-docs-external-agents` | https://zed.dev/docs/ai/external-agents |
| `zed-docs-hooks` | https://zed.dev/docs/ai/hooks (a 404 confirms hooks are still absent) |
| `zed-releases-api` | https://api.github.com/repos/zed-industries/zed/releases/latest |
| `zed-hooks-proposal` | https://api.github.com/repos/zed-industries/zed/issues/57890 |

Compare each fetch with the matching entry in `docs/harnesses/zed-capabilities.json` and report a table:

| Capability | Was | Now | Source URL | Zed version |
| --- | --- | --- | --- | --- |

Rules for the manifest:

- Update `last_verified` only from the fetched release tag and the fetch date.
- Mark a capability `supported` only when a fetched source states it, and cite that source URL plus the Zed version where it was verified.
- Mark a capability `absent` only when a fetched source shows it does not exist at the fetched version.
- Mark a capability `unverified` when the fetch failed, the page moved, or the source does not state the capability. Never report "no change" from a failed fetch — report `unknown` and keep the entry `unverified`.
- Never copy a status from memory or from this skill's own text. Evidence or `unverified`.

### 3. Adapter change proposal

Propose a change only when step 2 finds a usable new capability (for example `agent.hooks` shipping in a Zed release).

1. State the proposed change in the report: which Zed capability, which adapter files, and what the change buys. Name the acceptance criterion or gate it satisfies.
2. Attach it to a ticket. Use the open ticket that covers the capability, or file one first (`/task`).
3. Create the branch `{type}/{TICKET-ID}-zed-<slug>`, commit with `type: subject` and `Refs #N`, push, and open the PR with a `Closes #N` body.
4. Include the `docs/harnesses/zed-capabilities.json` update in the same PR.
5. Stop at the PR. State that Rex's review and the explicit per-PR nod are still outstanding.

Merges go through `tracker_pr_merge`, whose wrapper runs the merge gates (AgDR-0162). Never run `gh pr merge` or `gh api .../merge` directly: the Zed adapter's own tool-permission rules deny both commands, and the framework denies them with or without the adapter.

### 4. Report

Close with a summary that states the outcome first:

- framework drift: none, or what was regenerated
- installer rules: current, or what was installed and where the backup is
- capability check: each new or changed capability with its source URL and Zed version, or `unknown` for each source that could not be fetched
- next action: none, or the PR that awaits review

## Running reviews under Zed

The native Zed agent has no read-only reviewer tier: `spawn_agent` gives the subagent the parent's tools, so it can write files. When a review skill spawns a reviewer under Zed, make the prompt:

1. Have the subagent adopt the reviewer's agent-definition file — `.claude/agents/code-reviewer.md` for Rex, `.claude/agents/security-reviewer.md` for Hakim.
2. Instruct it to review only and not modify the repository.

Example prompt fragment:

```
Read .claude/agents/code-reviewer.md and adopt that role for this review.
Review the diff only. Do not edit, stage, or commit anything.
```

---

*Part of [ApexYard](https://github.com/me2resh/apexyard) — multi-project SDLC framework for Claude Code · MIT.*
