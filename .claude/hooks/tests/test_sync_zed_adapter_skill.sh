#!/usr/bin/env bash
# Tests for the /sync-zed-adapter skill and its capability manifest
# (me2resh/apexyard#4 / AgDR-0166).
#
# The skill is instructions, so this test pins the parts a reader depends on:
# both checks, the live source list, the evidence rules, the never-merge rule,
# the reviewer spawn guidance, and the AGENTS.md section the skill re-checks.
# It also validates docs/harnesses/zed-capabilities.json's shape, so a
# hand-edited manifest cannot drop a status, a source, or a version.

set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$ROOT/.claude/skills/sync-zed-adapter/SKILL.md"
MANIFEST="$ROOT/docs/harnesses/zed-capabilities.json"
ZED_DOC="$ROOT/docs/harnesses/zed.md"
AGENTS="$ROOT/AGENTS.md"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

PASS=0
FAIL=0
FAILED=""

mark_pass() { green "  ok   $1"; PASS=$((PASS+1)); }
mark_fail() {
  red "  FAIL $1: $2" >&2
  FAIL=$((FAIL+1))
  FAILED="$FAILED $1"
}

assert_file() {
  local path="$1" label="$2"
  [ -f "$path" ] && mark_pass "$label" || mark_fail "$label" "missing $path"
}

assert_contains() {
  local path="$1" pattern="$2" label="$3"
  grep -F "$pattern" "$path" >/dev/null 2>&1 && mark_pass "$label" || mark_fail "$label" "missing [$pattern] in $path"
}

assert_jq() {
  local file="$1" filter="$2" label="$3"
  if jq -e "$filter" "$file" >/dev/null 2>&1; then
    mark_pass "$label"
  else
    mark_fail "$label" "jq assertion failed: $filter"
  fi
}

echo "== /sync-zed-adapter skill smoke"

assert_file "$SKILL" "skill file exists"
assert_file "$MANIFEST" "capability manifest exists"
assert_file "$ZED_DOC" "harness page exists"

# --- skill frontmatter -----------------------------------------------------

if [ "$(awk '/^name:/ { sub(/^name:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; exit }' "$SKILL")" = "sync-zed-adapter" ]; then
  mark_pass "skill name matches its folder"
else
  mark_fail "skill name matches its folder" "name field is not sync-zed-adapter"
fi

if [ -n "$(awk '/^description:/ { sub(/^description:[[:space:]]*/, ""); print; exit }' "$SKILL")" ]; then
  mark_pass "skill description is present"
else
  mark_fail "skill description is present" "no description in frontmatter"
fi

if [ "$(awk '/^disable-model-invocation:/ { sub(/^disable-model-invocation:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; exit }' "$SKILL")" = "false" ]; then
  mark_pass "skill is model-invocable"
else
  mark_fail "skill is model-invocable" "expected disable-model-invocation: false"
fi

# --- the two checks --------------------------------------------------------

assert_contains "$SKILL" "bin/sync-zed-adapter.sh --check" "skill runs the generator drift check"
assert_contains "$SKILL" "bin/install-zed-adapter.sh --check" "skill runs the installer rules check"
assert_contains "$SKILL" "### Zed overlay (native Zed agent)" "skill checks the AGENTS.md Zed section"

# --- the live sources ------------------------------------------------------

for url in \
  "https://zed.dev/docs/ai/skills" \
  "https://zed.dev/docs/ai/tool-permissions" \
  "https://zed.dev/docs/ai/tools" \
  "https://zed.dev/docs/ai/external-agents" \
  "https://api.github.com/repos/zed-industries/zed/releases/latest" \
  "https://api.github.com/repos/zed-industries/zed/issues/57890" ; do
  assert_contains "$SKILL" "$url" "skill lists source $url"
done

# --- evidence rules and the never-merge rule -------------------------------

assert_contains "$SKILL" "unverified" "skill requires unverified marking"
assert_contains "$SKILL" '`unknown`' "skill reports a failed fetch as unknown"
assert_contains "$SKILL" "Never copy a status from memory" "skill forbids memory-derived statuses"
assert_contains "$SKILL" "never merges" "skill states it never merges"
assert_contains "$SKILL" "Stop at the PR" "skill stops at the PR"
assert_contains "$SKILL" "tracker_pr_merge" "skill routes merges through tracker_pr_merge"
assert_contains "$SKILL" 'Never run `gh pr merge`' "skill forbids direct merges"
assert_contains "$SKILL" "docs/harnesses/zed-capabilities.json" "skill names the capability manifest"

# --- reviewer guidance -----------------------------------------------------

assert_contains "$SKILL" "spawn_agent" "skill tells reviewers to use spawn_agent"
assert_contains "$SKILL" ".claude/agents/code-reviewer.md" "skill names the reviewer agent-definition file"
assert_contains "$SKILL" "not modify the repository" "skill instructs the subagent not to write"

# --- capability manifest shape --------------------------------------------

if jq empty "$MANIFEST" >/dev/null 2>&1; then
  mark_pass "capability manifest is valid JSON"
else
  mark_fail "capability manifest is valid JSON" "jq cannot parse $MANIFEST"
fi

assert_jq "$MANIFEST" '.schema == 1' "manifest declares a schema version"
assert_jq "$MANIFEST" '.harness == "zed"' "manifest names the harness"
assert_jq "$MANIFEST" '.last_verified.zed_version != null and .last_verified.date != null' "manifest records the verified Zed version and date"
assert_flags=(
  '.status_legend.supported != null'
  '.status_legend.absent != null'
  '.status_legend.unverified != null'
  '(.capabilities | length) > 0'
  'all(.capabilities[]; (.id != null) and (.status != null) and (.zed_version != null) and (.verified_on != null) and (.source != null) and (.evidence != null))'
  'all(.capabilities[]; (.status | IN("supported", "absent", "unverified")))'
  'all(.capabilities[]; (.status == "unverified") or (.source | startswith("https://")))'
  '[.capabilities[] | select(.id == "agents.lifecycle_hooks")][0].status == "absent"'
)
for filter in "${assert_flags[@]}"; do
  assert_jq "$MANIFEST" "$filter" "manifest shape: $filter"
done

# --- the harness page carries the gate table ------------------------------

assert_contains "$ZED_DOC" "denied" "harness page names the denied commands"
assert_contains "$ZED_DOC" "confirm" "harness page names the confirm rules"
assert_contains "$ZED_DOC" "advisory" "harness page names the advisory gates"
assert_contains "$ZED_DOC" "Claude Agent over ACP" "harness page covers the ACP path"
assert_contains "$ZED_DOC" "Native Zed agent" "harness page covers the native path"
assert_contains "$ZED_DOC" "AgDR-0162" "harness page documents the merge path"

# --- the AGENTS.md section the skill re-checks ----------------------------

assert_contains "$AGENTS" "### Zed overlay (native Zed agent)" "AGENTS.md carries the Zed section"
assert_contains "$AGENTS" "Claude Agent over ACP" "AGENTS.md Zed section covers the ACP path"
assert_contains "$AGENTS" 'Read `CLAUDE.md` now' "AGENTS.md Zed section points at CLAUDE.md"
assert_contains "$AGENTS" "advisory" "AGENTS.md Zed section lists the advisory gates"
assert_contains "$AGENTS" "ticket-first" "AGENTS.md Zed section names ticket-first"
assert_contains "$AGENTS" "tracker_pr_merge" "AGENTS.md Zed section documents the merge path"

echo
echo "===== test_sync_zed_adapter_skill.sh ====="
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed cases:$FAILED"
  exit 1
fi
exit 0
