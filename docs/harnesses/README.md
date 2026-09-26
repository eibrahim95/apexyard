# Harness support

An **agent harness** is the CLI or IDE that runs an ApexYard session. Examples
include Claude Code, Codex, pi, opencode, and Cursor.

ApexYard was built for Claude Code first. Claude Code still provides the full
native experience. The enforcement layer uses portable Bash. Other harnesses
can reach the same gates through thin adapters.

This directory records what each harness supports today.

> **Positioning:** The primary tagline remains **"for Claude Code."** These
> pages document the current adapter support. A separate product decision is
> required before the headline changes. See [Rebrand trigger](#rebrand-trigger).

## Support matrix

This page answers one question: **does ApexYard enforce my rules on this tool,
and how do I set it up?** A tool is **proven** only after a real,
credentialed agent turn is stopped by the same unmodified Bash rule. Mocks do
not qualify.

| Tool | Enforces your rules? | Setup | Good to know |
|------|----------------------|-------|--------------|
| **Claude Code** | ✅ **Yes — natively.** The rules fire on every tool call; no adapter. | Nothing to install — `/setup`; `.claude/` is auto-picked-up. | The reference tool: `CLAUDE.md` auto-loads, and all rules, skills, and agents are first-class. |
| **opencode** | ✅ **Yes — proven (2026-07-09).** A real `opencode run --auto` turn's `git add -A` was blocked by the same rule. | `bash bin/install-opencode-adapter.sh` → `.opencode/plugins/apexyard/` | Run with `--auto` so the command reaches the rule. The plugin reads its rule list straight from `.claude/settings.json`, so it can't drift. Details: [opencode.md](opencode.md), [AgDR-0092](../agdr/AgDR-0092-opencode-gate-adapter.md). |
| **pi** (pi.dev) | ✅ **Yes — proven (2026-07-09).** A real `pi -p -a` turn was stopped the same way. | `bash bin/install-pi-adapter.sh` → `.pi/extensions/apexyard/` | Run headless with `-a` / `--approve`. pi ships deliberately bare-bones and leaves governance to you — ApexYard is that layer. An `AGENTS.md` + `SYSTEM.md` bridge carries the advisory rules. Details: [pi.md](pi.md), [AgDR-0082](../agdr/AgDR-0082-pi-gate-dispatcher-adapter.md). |
| **Codex** | ✅ **Yes — proven (2026-07-09).** A real `codex exec -m gpt-5.5` turn's `git add -A` fired the same rule (clean exit 2, nothing staged). | `bash bin/sync-codex-adapter.sh` → generates `.codex/hooks.json` | Codex has to trust the rules once — `/hooks` (interactive), `--dangerously-bypass-hook-trust` (one-off), or a user-level `~/.codex/hooks.json`. That's a trust step, not a missing capability. Details: [codex.md](codex.md), [AgDR-0088](../agdr/AgDR-0088-codex-adapter-generation.md). |
| **Cursor** | ✅ **Yes — native in the IDE (2026-09-16).** Cursor loads `.claude/settings.json` when third-party configs are on. A real Write call was refused by `require-active-ticket.sh`. | Enable third-party configs. Then `bash bin/install-cursor-adapter.sh` for the session-pin overlay. | IDE only. The `cursor-agent` CLI ignores hooks. A leftover full generated adapter can fail-closed-lock the session. Overlay does not copy gates. Details: [cursor.md](cursor.md). |
| **Zed** | ⚠️ **Native agent: no blocking gates (degraded tier, verified 2026-09-26).** Zed v1.21.0 has no lifecycle hooks, so the bash gates cannot run. Claude Agent over ACP does enforce fully, because Claude Code reads `.claude/` itself. | Native agent: `bash bin/sync-zed-adapter.sh` for skills, then `bash bin/install-zed-adapter.sh` once per machine for the tool-permission rules. ACP path: install Claude Agent from the ACP registry and enable nothing else. | The installer denies `git add -A`/`.`, `gh pr merge` and `gh api .../merge`, and confirms `gh pr create` and `gh issue create`. Every other gate is advisory. Details: [zed.md](zed.md), [AgDR-0166](../agdr/AgDR-0166-zed-native-agent-adapter.md). |

**The pattern underneath.** The rule is always the *same* unmodified bash. What changes per tool is one small setting that lets the agent's command reach it. That setting is an approve/trust flag (opencode `--auto`, pi `-a`, Codex trust), a config location, or Cursor's third-party-config toggle. Once that's set, the delegated `.claude/hooks/*.sh` runs. Cursor's generated overlay is not a second gate list. It only maps the session id.

## Shared-core architecture

Everything above rests on four load-bearing decisions:

1. **Gates stay portable bash — they are not ported per harness.** The `.claude/hooks/*.sh` scripts (merge gates, red-CI block, ticket-first, secrets/leak-protection) are the framework's security-critical trust chain. Rewriting them in a per-harness language would fork the gate logic and re-trigger a full security review per file. Instead, every harness reaches the *same* unmodified scripts. Rationale and the rejected language-port options: [AgDR-0086](../agdr/AgDR-0086-hooks-stay-bash-not-ported.md).
2. **`.claude/` is the canonical authoring surface.** Skills, agents, hooks, settings, rules, and templates are authored under `.claude/` first. Adapter surfaces (`.agents/`, `.codex/`, `harness-adapters/pi/`, Cursor's thin `.cursor/` overlay) are *generated from* or *shell out to* `.claude/` — never a second hand-maintained copy of gate logic. This is why adding a gate is a one-place change.
3. **Harnesses are transports, not forks.** An adapter's job is to carry a tool call from the harness's event model into the bash hook's stdin/exit-code contract and back. It carries no governance logic of its own. A bug in an adapter can fail to *invoke* a gate; it cannot silently *change* a gate's decision, because the decision lives in bash.
4. **Model tiers resolve through one matrix.** Framework agent frontmatter uses Claude model-tier labels (`opus` / `sonnet` / `haiku`). Each harness maps those to its own concrete models via a single file, [`.claude/harness-models.json`](../../.claude/harness-models.json) — the Codex adapter reads the `codex` column; a pi/opencode adapter adds its own column rather than hardcoding a second mapping. Per [AgDR-0087](../agdr/AgDR-0087-reasoning-agents-require-frontier-model.md), each harness's `opus` row must stay on that harness's strongest available model — the reasoning-layer reviewers (Rex, Hakim, Tariq, Naqid) have a frontier-model floor and are never downgraded when a harness is added. See [AgDR-0088](../agdr/AgDR-0088-codex-adapter-generation.md) for how the Codex generator consumes the matrix.

The upshot: mechanical governance is model- and harness-agnostic and self-hostable, while review *depth* keeps a frontier-model floor. Those two facts are decided in AgDR-0086/0087/0088 and 0082, not asserted here.

## Per-harness pages

Each harness has a dedicated page with a consistent skeleton — status, what's enforced vs advisory today, how the transport works, how to install/generate, gaps + tracking, and related AgDRs.

- **[Claude Code](claude-code.md)** — Native, full experience. The reference harness: `CLAUDE.md` auto-load, hooks firing live, slash-command skills, sub-agents, session markers. Install pointer: [`docs/getting-started.md`](../getting-started.md).
- **[opencode](opencode.md)** — ✅ **Live-proven (2026-07-09)**. A TypeScript plugin over the unmodified bash hooks with `settings.json`-derived gates (drift-proof by construction); a real `opencode run --auto` turn's `git add -A` was refused by the delegated `block-git-add-all.sh`. Install: `bash bin/install-opencode-adapter.sh` (subdir shape, #845). Precondition: `--auto`.
- **[pi (pi.dev)](pi.md)** — ✅ **Live-proven (2026-07-09)**. A single dispatcher extension shells out to the bash hooks; a real `pi -p -a` turn was blocked the same way. The `AGENTS.md`/`SYSTEM.md` advisory bridge works today. Install: `bash bin/install-pi-adapter.sh` (`.pi/extensions/apexyard/`, #845). Precondition: headless `-a`/`--approve`.
- **[Codex](codex.md)** — ✅ **Live-proven (2026-07-09)**. Generated from `.claude/`; a real `codex exec --dangerously-bypass-hook-trust -m gpt-5.5` turn's `git add -A` fired the delegated `block-git-add-all.sh` cleanly (exit 2, nothing staged). Model mapping (`opus`→`gpt-5.5`) is correct. Precondition: **hook-trust** — `/hooks` (interactive), `--dangerously-bypass-hook-trust` (headless one-off), or user-level `~/.codex/hooks.json`. Full workflow in [`docs/codex-adapter.md`](../codex-adapter.md) (linked, not moved).
- **[Cursor](cursor.md)** — ✅ **Native in the IDE (2026-09-16)**. Cursor loads `.claude/settings.json` when third-party configs are on. The generated overlay is session-pin only ([AgDR-0151](../agdr/AgDR-0151-native-first-cursor-overlay.md)). The `cursor-agent` CLI still ignores `hooks.json`. Full workflow in [`docs/cursor-adapter.md`](../cursor-adapter.md).
- **[Zed](zed.md)** — ⚠️ **Degraded tier (verified 2026-09-26, Zed v1.21.0)**. The native agent has no lifecycle hooks, so the adapter ships generated skills plus user-level tool-permission rules and every other gate stays advisory. The Claude Agent path over ACP keeps the full `.claude/` layer. Capability manifest: [`zed-capabilities.json`](zed-capabilities.json). Generate: `bash bin/sync-zed-adapter.sh`. Install the rules: `bash bin/install-zed-adapter.sh`.

## Conformance CI — the ongoing, live proof

The manual proofs above are dated (2026-07-09) — a single, one-off run per harness. [**Conformance CI**](../conformance-ci.md) (`.github/workflows/conformance.yml`) turns that into a **daily, scheduled, credentialed** check: one real gated turn per harness (opencode, pi, Codex), asserted against the delegated hook's own live output, with a per-harness status badge and a **3-consecutive-green-run** definition of "green-continuous" before any harness's badge claims "(proven)". Cursor is deliberately not in the matrix — no headless path exists that would exercise the real gate — and its badge stays a static, hand-seeded "documented-manual" entry that no scheduled run can silently flip to proven. Decision record: [AgDR-0095](../agdr/AgDR-0095-conformance-ci-badge.md).

## Adapter-authoring pattern for future harnesses

Every adapter answers the same question — *how does this harness let a pre-tool gate block an action, and how do I route that to the bash hooks without duplicating their logic?* Two shapes have emerged, chosen by how the target harness consumes hook configuration:

- **Declarative-generate** — for harnesses that read a static hook-config file (Codex's `.codex/hooks.json`). Write a generator that reads `.claude/settings.json` + `.claude/agents/*` and emits the harness's native config, with each `command` still exec'ing the unmodified `.claude/hooks/*.sh`. Compile any Claude-Code-specific handler metadata (e.g. handler-level `if` predicates) into a shell-side preflight in the generated command. Ship the *generator and its tests* as the durable contribution; treat the generated tree as regenerable output. Reference: the Codex generator (`bin/sync-codex-adapter.sh`, [AgDR-0088](../agdr/AgDR-0088-codex-adapter-generation.md)). Cursor used this shape until native `.claude/settings.json` loading was observed. It now ships a thin session-pin overlay instead ([AgDR-0151](../agdr/AgDR-0151-native-first-cursor-overlay.md)).
- **Live extension** — for harnesses with an imperative plugin/extension API (pi's `tool_call` event; opencode's plugin hooks). Write one dispatcher extension driven by a gate table: on each tool call, reconstruct the exact stdin JSON the bash hook expects, spawn the hook, and map its exit code (`2` = block, `0` = allow) to the harness's block/allow return contract. One dispatcher, N gates as data rows — adding a gate is a table entry, not a new file. Reference: the pi dispatcher (`harness-adapters/pi/src/gate-dispatcher.ts`, [AgDR-0082](../agdr/AgDR-0082-pi-gate-dispatcher-adapter.md)).

In both shapes the non-negotiable is the same: **bash owns every gate decision.** The adapter is the wire, never the judge. And both shapes carry the same last-mile obligation — a live, credentialed end-to-end run proving the harness invokes the gate at the right moment during a real model turn, not just a by-construction test of the transport.

A third shape exists for harnesses with **no hook surface at all**: the **advisory tier**. When the harness cannot intercept a tool call, do not generate gate files that never run. Export what the harness does load (skills), express the rules it can enforce natively (Zed's user-level tool permissions), and list every remaining gate as advisory in the harness page. Zed is the reference: [`zed.md`](zed.md), [AgDR-0166](../agdr/AgDR-0166-zed-native-agent-adapter.md). Watch for the hook surface shipping — `/sync-zed-adapter` reports it from the live docs and the capability manifest.

## Rebrand trigger

The headline stays **"for Claude Code"** until this condition is met, verbatim:

> The headline flips to harness-neutral only when **≥2 adapters have live end-to-end conformance proof** (then the site + channel positioning follow in a coordinated pass).

"Live end-to-end conformance proof" means the credentialed run described above: a real model turn under that harness actually blocked by a gate (e.g. a `git add -A` refused by the unmodified bash hook), not a mock or a by-construction test.

**As of 2026-07-09 the trigger condition is MET** — three adapters (**opencode**, **pi**, and **Codex**) have recorded that proof. Cursor IDE native exec was later observed (2026-09-16) but still has no headless conformance-CI path, so it does not add a fourth scheduled proof. That does **not** auto-flip the headline: the flip is a **separate, deliberate decision** that moves the site (apexyard.ai) and channel positioning in one coordinated pass, and it hasn't been taken. Until it is, the framework keeps the Claude-Code tagline and describes multi-harness support in the precise, per-harness terms above rather than as a blanket claim.

---

*Part of [ApexYard](https://github.com/me2resh/apexyard) — multi-project SDLC framework for Claude Code · MIT.*

- [Portfolio adapter management](portfolio-adapters.md) — registry-driven install and drift checks.
