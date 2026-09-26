# /handover step 5 — handover assessment template

Step 5 of `.claude/skills/handover/SKILL.md` loads this file. Write `projects/<name>/handover-assessment.md` from the template below.

````markdown
# {name} — Handover Assessment

**Date**: YYYY-MM-DD
**Assessor**: {git user}
**Status**: handover

## Origin

- **Where it came from**: {acquisition / inherited team / open source / contractor / etc.}
- **Original owner**: {if known}
- **Repo location**: {URL or path}
- **First commit date**: {from git log}
- **Last commit date**: {from git log}

## Current State

### Tech stack
- Language: {…}
- Runtime: {…}
- Framework: {…}
- Database: {…}
- Test framework: {…}
- CI: {…}

### Build status
- `npm install`: {ok / failed}
- `npm run build`: {ok / failed / not attempted}
- `npm run test`: {ok / failed / not attempted}
- `npm run lint`: {ok / failed / not attempted}

### Test coverage
- Estimated: {…} (from coverage report if available, otherwise "unknown")

### Repo activity
- Commits in last 90 days: {…}
- Open issues: {…}
- Open PRs: {…}
- Top contributors: {…}

## Harnessability assessment

**Overall verdict**: `{high | moderate | low}`

{If `low`, embed the warning block verbatim here:}

> ⚠ Harnessability: LOW
>
> Rex's architecture handbooks will fire advisory-only on this codebase. The blocking gate (`ENFORCEMENT: blocking`) will generate false positives. Recommended: adopt as advisory-only, plan a follow-up to add the missing scaffolding (typescript strict, lint baseline, etc.)

| Dimension | Score | Evidence |
|-----------|-------|----------|
| Type safety | `{strong / partial / none}` | {1-line rationale citing the path + key signal, e.g. `tsconfig.json line 6: "strict": true`} |
| Module boundaries | `{strong / partial / flat}` | {1-line rationale, e.g. `src/domain/ + src/application/ + src/infrastructure/ all present`} |
| Framework opinionation | `{strong / moderate / weak}` | {1-line rationale, e.g. `package.json deps include @nestjs/core (DI + HTTP + persistence opinionation)`} |
| Test coverage signal | `{present / absent}` | {1-line rationale, e.g. `jest.config.js has coverageThreshold: { global: { lines: 80 } }`} |
| Lint baseline | `{present / absent}` | {1-line rationale, e.g. `.eslintrc.json present at repo root`} |

See AgDR-0042 for the scoring rationale and v1 thresholds.

## Quality Risks

### Security
- {known CVEs in deps, hardcoded secrets, missing auth, etc.}

### Dependencies
- {abandoned packages, major versions behind, license issues}

### Technical debt
- {missing tests, no types, dead code, tangled architecture, etc.}

### Operational
- {missing CI, no monitoring, no deploy automation, etc.}

## Integration Plan

### Roles that apply
- {tech-lead, backend-engineer, frontend-engineer, sre, security-auditor, …}

### Workflows that kick in
- [ ] PR workflow (`.claude/rules/pr-workflow.md`) — every change goes through a PR
- [ ] AgDR for technical decisions
- [ ] Code Reviewer agent on every PR
- [ ] Security Reviewer agent on first pass and high-risk PRs
- [ ] `/audit-deps` on adoption and monthly thereafter

### Hooks to enable
- [ ] `block-git-add-all`
- [ ] `block-main-push`
- [ ] `validate-branch-name` (set `ticket_prefix` for this project's tracker)
- [ ] `validate-pr-create`
- [ ] `pre-push-gate`
- [ ] `check-secrets`

### CI templates to copy in
- [ ] `golden-paths/pipelines/ci.yml`
- [ ] `golden-paths/pipelines/security.yml`
- [ ] `golden-paths/pipelines/pr-title-check.yml`

### Registry entry

The entry that will be appended to `apexyard.projects.yaml` at the root of the ops repo (see step 7 — the skill does this append for you, with confirmation):

```yaml
- name: {name}
  repo: {owner/name}
  workspace: workspace/{name}
  docs: projects/{name}
  status: handover
  roles:
    {dynamically derived from the tech stack + CI config — see
     "Deriving applicable roles" below}
```

**Deriving applicable roles**: don't hard-code `[tech-lead, backend-engineer]`. Look at the tech stack from step 3:

| Signal | Add role |
|--------|----------|
| Any backend code (package.json with server deps, pyproject.toml, etc.) | `backend-engineer` |
| Any UI code (React/Vue/Svelte, `src/components/`, CSS modules) | `frontend-engineer` |
| CI config detected (`.github/workflows/`, `.gitlab-ci.yml`, etc.) | `platform-engineer` |
| Production deployment evidence (Dockerfile, Terraform, AWS/GCP/Azure SDK) | `sre` |
| Auth / crypto / secrets in the diff | `security-auditor` |
| Always | `tech-lead` |

For a typical handover you'll end up with 3-5 roles in the list.

## Next Steps

Derived dynamically from the Quality Risks found in this assessment. Don't emit generic placeholders — emit specific actions.

Mapping table:

| Risk found | Next step entry |
|------------|-----------------|
| ≥ 1 CVE in deps (any severity) | `1. /audit-deps {name} — triage the {severity} {package} CVE before any new feature work` |
| Failing tests | `2. Fix the {N} failing tests in {module} before merging new PRs (baseline must be green)` |
| No observability (no Sentry/Datadog/CloudWatch/etc.) | `3. /decide on observability ({two most common options for this stack})` |
| Stale CI (no runs in > 30 days) | `4. Re-enable CI on this repo — copy in golden-paths/pipelines/ci.yml` |
| Test coverage unknown | `5. Set up test coverage reporting (vitest/jest coverage config) before the first feature` |
| ≥ 10 open issues | `6. Triage the issue backlog with the previous owner before taking ownership` |
| Missing README or onboarding doc | `7. Write a minimum-viable README (what the project does, how to run it locally, where it deploys)` |

If no risks match a row, omit that row. If fewer than 3 actions come out, add:

- `{next} /code-review the most-recent PR on this repo as Rex to calibrate review standards`
- `{next} Stakeholder sync with the previous owner to cover context the static read couldn't surface`

**Re-handover preservation.** On re-runs of `/handover`, the regenerated `## Next Steps` section MUST preserve any prior-run `~~strikethrough~~ → Filed as [#N](url)` markers on entries that recur in the new list. Detection rule: for each entry that would be emitted by the mapping table above, scan the prior `handover-assessment.md` (if present) for a matching entry by leading verb + key noun phrase (e.g. "Fix the N failing tests in {module}" matches the prior "Fix the M failing tests in {module}" regardless of the count). If matched and the prior version carries a `Filed as` link, preserve the link in the regenerated entry. This is the load-bearing input to step 7.5's filed-marker skip logic — without it, the operator gets re-prompted on every filed entry on every re-handover. See Rule 18.

## Cleanup (REQUIRED before exit)

```bash
rm -f .claude/session/active-bootstrap
```

Always remove the bootstrap marker on a clean exit. If the skill is interrupted before this step, `clear-bootstrap-marker.sh` clears the stale marker on the next session.

## Post-Handover Checklist

Also derived from the risks found. Tailor to the specific repo — don't emit generic items.

- [ ] Review this assessment with the previous owner
- [ ] {top quality risk} — close before the first feature PR
- [ ] {second quality risk} — scheduled in the first 2 weeks
- [ ] Add `{name}` to the weekly `/stakeholder-update` rollup
- [ ] Onboard the roles listed above into the team's on-call / review rotation
- [ ] Set up a test coverage baseline (run `npm test -- --coverage` or equivalent and commit the threshold)
- [ ] Run `/audit-deps {name}` monthly for the next 3 months

## Open Questions

- {anything you couldn't determine from a static read}

````
