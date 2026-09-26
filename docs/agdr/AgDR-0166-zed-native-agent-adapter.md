# AgDR-0166 — Zed native-agent adapter: generated skills, installed rules, honest advisory remainder

> In the context of adding Zed support to a framework whose agents block tool
> calls through `.claude/hooks/*.sh`, facing a native agent with no lifecycle
> hooks to fire them, I decided to generate only the surfaces Zed actually
> loads (`.agents/skills/` plus an `AGENTS.md` bridge), to install the rules Zed
> can enforce natively (user-level tool permissions), and to document every
> remaining gate as advisory — to achieve Zed support without claiming
> enforcement the harness cannot deliver.

## Context

- Zed runs agents two ways. **Claude Agent over ACP** is an External Agent:
  Claude Code runs in Zed's agent panel and reads `CLAUDE.md` and `.claude/`
  itself, so the full enforcement layer applies unchanged. The **native Zed
  agent** is Zed's own; it reads `AGENTS.md` first and loads project skills
  from `<worktree>/.agents/skills/`.
- Zed v1.21.0 documents no lifecycle hooks. `zed.dev/docs/ai/hooks` returns
  404, and no fetched page documents an `agent.hooks` setting. The proposal
  zed-industries/zed#57890 covered commands, hooks and skills together, and
  closed on 2026-05-28 with only the skills half documented.
- Zed's native block surface is `agent.tool_permissions` in user settings. Its
  `always_deny` layer outranks `always_confirm`, `always_allow`, and both
  defaults. Zed parses chained commands and checks each sub-command.
- `spawn_agent` gives a subagent the parent's tools. No read-only subagent tier
  is documented, so a Zed reviewer can still write files.
- The framework already has one generated-from-`.claude/` adapter (Codex,
  [AgDR-0088](AgDR-0088-codex-adapter-generation.md)) and one native-first
  overlay (Cursor, [AgDR-0151](AgDR-0151-native-first-cursor-overlay.md)).
  Both generators write `.agents/skills/`.
- Zed ships weekly, and `.claude/` keeps changing. The adapter needs a drift
  check in both directions.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| Do nothing for Zed | Zero maintenance | Zed users get no skills, no prompt bridge, and no mechanical rules at all |
| Port the gates into a Zed-native mechanism | Would look like enforcement | Zed has no hook surface to port them into. Any copy would also fork the audited bash gate logic, which AgDR-0086 forbids |
| Generate hook files for Zed anyway | Visible adapter output | A generated file that never runs is a false enforcement claim. The repository treats that as a defect class, not a feature |
| Wait for `agent.hooks` to ship | No interim risk | Leaves Zed unsupported for an unknown time, and the arrival still needs a follow-up |
| Generate the surfaces Zed loads, install the rules Zed enforces, document the rest as advisory | Real capabilities on day one. No false claims. Reuses the shared export so Codex and Zed cannot drift apart | The tier is honestly degraded: most gates stay advisory, and the permission rules need a per-machine install |

## Decision

Chosen: **generate the surfaces Zed loads, install the rules Zed enforces, and
document every remaining gate as advisory.**

The adapter is four pieces:

- `bin/_lib-adapter-skills.sh` — the shared skill-export step. It writes the
  canonical `.agents/skills/` tree: one directory per skill, path references
  rewritten, and each `SKILL.md` frontmatter projected to the fields both
  consumers read. Codex requires `name` and `description` and keeps its extra
  metadata in `agents/openai.yaml`. Zed documents `name`, `description` and
  `disable-model-invocation`. The projection keeps exactly those three fields
  and drops the Claude-only presentation fields (`argument-hint`,
  `allowed-tools`, `effort`). Both generators call this step, so the shared
  tree is byte-identical whichever runs last and neither detects the other as
  drift.
- `bin/sync-zed-adapter.sh` — writes `.agents/skills/` from `.claude/skills/`
  and supports `--check` for drift.
- `bin/install-zed-adapter.sh` — merges the deny and confirm rules into the
  operator's Zed user settings, with a backup and an idempotent merge. The deny
  patterns mirror `.claude/hooks/block-git-add-all.sh` and
  `.claude/hooks/block-unreviewed-merge.sh`.
- `AGENTS.md` and `docs/harnesses/zed.md` — the prompt bridge and the per-gate
  status table. `docs/harnesses/zed-capabilities.json` records each capability
  with a status, a source URL, and the Zed version where it was verified.

`/sync-zed-adapter` keeps it current: it re-runs the generator and installer
rules on drift, fetches the live Zed sources, and reports each capability
change with its source. It opens a PR and never merges.

## Consequences

- The enforcement split is explicit. Denied commands, confirmed commands and
  advisory gates are each named in `docs/harnesses/zed.md`. Nothing claims to
  be enforced that Zed cannot block.
- The deny rules are pattern-level, not semantic. They match the documented
  command shapes. A determined operator can still bypass them. They are a
  guardrail for the agent, not a security boundary.
- Each developer installs the rules once per machine, because the documented
  settings path is the user settings file. Project-level permissions are
  unverified and recorded as such.
- Reviewer independence stays advisory under Zed. The spawn prompt must tell
  the subagent to review only.
- The Codex generated skills change shape: three Claude-only fields stop
  appearing in `.agents/skills/`. Codex reads only `name` and `description`,
  so the change costs it nothing, and it buys one shared tree instead of two
  competing ones.
- The shared export becomes the compatibility boundary. A future harness that
  consumes the Agent Skills layout adds a column of supported fields there,
  not a second exporter.
- Zed's capability surface is version-sensitive. The manifest carries the
  version and the source for every status, so a weekly release cannot silently
  invalidate the adapter.
- The adapter gains a hooks transport only when Zed ships one. The capability
  check reports the arrival, and a follow-up delegates to the unmodified
  `.claude/hooks/*.sh` scripts. The tier changes then, not now.

## Artifacts

- Refs eibrahim95/apexyard#4
- `bin/_lib-adapter-skills.sh`, `bin/sync-zed-adapter.sh`,
  `bin/install-zed-adapter.sh`
- `.claude/skills/sync-zed-adapter/SKILL.md`
- `docs/harnesses/zed.md`, `docs/harnesses/zed-capabilities.json`
- `bin/sync-codex-adapter.sh` (now exports through the shared step)
- `.claude/hooks/tests/test_sync_zed_adapter.sh`,
  `.claude/hooks/tests/test_install_zed_adapter.sh`,
  `.claude/hooks/tests/test_sync_zed_adapter_skill.sh`
