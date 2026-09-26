#!/usr/bin/env bash
# Tests for bin/sync-zed-adapter.sh and the shared skill export in
# bin/_lib-adapter-skills.sh (me2resh/apexyard#4 / AgDR-0166).
#
# The load-bearing claims under test:
#   - one .agents/skills/<name>/SKILL.md per skill in .claude/skills
#   - path references rewritten, bodies preserved
#   - frontmatter projected to name/description/disable-model-invocation
#   - approve-* keeps disable-model-invocation: true
#   - invalid names, name/folder mismatches and block scalars fail loudly
#   - unquoted `: ` in a kept value and a SKILL.md over 100KB fail loudly
#   - --check detects drift and ignores non-owned files
#   - the Codex and Zed generators share one export, in either order

set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
ZED_SCRIPT="$ROOT/bin/sync-zed-adapter.sh"
CODEX_SCRIPT="$ROOT/bin/sync-codex-adapter.sh"

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

assert_no_dir() {
  local path="$1" label="$2"
  [ ! -d "$path" ] && mark_pass "$label" || mark_fail "$label" "unexpected directory $path"
}

assert_contains() {
  local path="$1" pattern="$2" label="$3"
  grep -F "$pattern" "$path" >/dev/null 2>&1 && mark_pass "$label" || mark_fail "$label" "missing pattern [$pattern] in $path"
}

assert_not_contains() {
  local path="$1" pattern="$2" label="$3"
  if grep -F "$pattern" "$path" >/dev/null 2>&1; then
    mark_fail "$label" "unexpected pattern [$pattern] in $path"
  else
    mark_pass "$label"
  fi
}

TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/zed-adapter-test.XXXXXX")
trap 'rm -rf "$TMPROOT"' EXIT

make_fixture() {
  local root="$1"
  mkdir -p "$root/.claude/skills/status" "$root/.claude/skills/approve-merge" "$root/.claude/skills/code-review"
  mkdir -p "$root/.claude/hooks" "$root/.claude/agents"

  cat > "$root/.claude/skills/status/SKILL.md" <<'MD'
---
name: status
description: Current status.
argument-hint: "[--brief]"
effort: low
allowed-tools: Bash, Read
---

Source `.claude/hooks/_lib-portfolio-paths.sh` and read `.claude/skills/status/briefing.sh`.

Unique body marker: STATUS_BODY_MARKER.
MD
  printf '%s\n' '#!/usr/bin/env bash' 'echo status' > "$root/.claude/skills/status/briefing.sh"

  cat > "$root/.claude/skills/approve-merge/SKILL.md" <<'MD'
---
name: approve-merge
description: Record per-PR CEO approval and merge in one turn.
disable-model-invocation: true
argument-hint: "<pr-number>"
---

Approval body.
MD

  cat > "$root/.claude/skills/code-review/SKILL.md" <<'MD'
---
name: code-review
description: Review a PR.
disable-model-invocation: false
---

Review body.
MD

  printf '%s\n' '{"hooks": {}}' > "$root/.claude/settings.json"
}

echo "== Zed adapter sync smoke"

FIX="$TMPROOT/fork"
make_fixture "$FIX"

if bash "$ZED_SCRIPT" --root "$FIX" >/tmp/_zed_adapter_sync.out 2>&1; then
  mark_pass "generator writes adapter output"
else
  mark_fail "generator writes adapter output" "$(cat /tmp/_zed_adapter_sync.out)"
fi

assert_file "$FIX/.agents/skills/status/SKILL.md" "skill mirror exists"
assert_file "$FIX/.agents/skills/approve-merge/SKILL.md" "second skill mirror exists"
assert_file "$FIX/.agents/skills/code-review/SKILL.md" "third skill mirror exists"
assert_file "$FIX/.agents/skills/status/briefing.sh" "bundled skill resource is exported"

skill_count=$(find "$FIX/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
if [ "$skill_count" = "3" ]; then
  mark_pass "one directory per source skill"
else
  mark_fail "one directory per source skill" "expected 3, found $skill_count"
fi

skill_md_count=$(find "$FIX/.agents/skills" -mindepth 2 -maxdepth 2 -name 'SKILL.md' | wc -l | tr -d ' ')
if [ "$skill_md_count" = "3" ]; then
  mark_pass "one SKILL.md per skill"
else
  mark_fail "one SKILL.md per skill" "expected 3, found $skill_md_count"
fi

assert_contains "$FIX/.agents/skills/status/SKILL.md" ".agents/skills/status/briefing.sh" "skill paths are rewritten to .agents"
assert_contains "$FIX/.agents/skills/status/SKILL.md" ".claude/hooks/_lib-portfolio-paths.sh" "canonical hook paths are preserved"
assert_contains "$FIX/.agents/skills/status/SKILL.md" "STATUS_BODY_MARKER" "body is preserved"

assert_not_contains "$FIX/.agents/skills/status/SKILL.md" "argument-hint:" "argument-hint is dropped"
assert_not_contains "$FIX/.agents/skills/status/SKILL.md" "effort:" "effort is dropped"
assert_not_contains "$FIX/.agents/skills/status/SKILL.md" "allowed-tools:" "allowed-tools is dropped"
assert_contains "$FIX/.agents/skills/status/SKILL.md" "name: status" "name is kept"
assert_contains "$FIX/.agents/skills/status/SKILL.md" "description: Current status." "description is kept"

assert_contains "$FIX/.agents/skills/approve-merge/SKILL.md" "disable-model-invocation: true" "approve-* keeps disable-model-invocation: true"
assert_contains "$FIX/.agents/skills/code-review/SKILL.md" "disable-model-invocation: false" "review skill keeps disable-model-invocation: false"

if bash "$ZED_SCRIPT" --root "$FIX" --check >/tmp/_zed_adapter_check_fresh.out 2>&1; then
  mark_pass "--check passes on fresh output"
else
  mark_fail "--check passes on fresh output" "$(cat /tmp/_zed_adapter_check_fresh.out)"
fi

# Non-owned files beside the generated tree are invisible to the check.
mkdir -p "$FIX/.agents/notes"
printf '%s\n' 'operator scratch file' > "$FIX/.agents/notes/todo.md"
if bash "$ZED_SCRIPT" --root "$FIX" --check >/tmp/_zed_adapter_check_scoped.out 2>&1; then
  mark_pass "--check ignores non-owned files under .agents/"
else
  mark_fail "--check ignores non-owned files under .agents/" "$(cat /tmp/_zed_adapter_check_scoped.out)"
fi

# Source drift is detected, and so is generated-output drift.
printf '\nNew source line.\n' >> "$FIX/.claude/skills/status/SKILL.md"
if bash "$ZED_SCRIPT" --root "$FIX" --check >/tmp/_zed_adapter_check_src_drift.out 2>&1; then
  mark_fail "--check detects source drift" "expected non-zero exit"
else
  mark_pass "--check detects source drift"
fi
bash "$ZED_SCRIPT" --root "$FIX" >/dev/null 2>&1
printf '\nHand edit.\n' >> "$FIX/.agents/skills/status/SKILL.md"
if bash "$ZED_SCRIPT" --root "$FIX" --check >/tmp/_zed_adapter_check_out_drift.out 2>&1; then
  mark_fail "--check detects generated-output drift" "expected non-zero exit"
else
  mark_pass "--check detects generated-output drift"
fi
bash "$ZED_SCRIPT" --root "$FIX" >/dev/null 2>&1

# A skill removed from the source stops being generated; a hand-authored file
# beside the tree survives the same run.
rm -rf "$FIX/.claude/skills/code-review"
bash "$ZED_SCRIPT" --root "$FIX" >/dev/null 2>&1
assert_no_dir "$FIX/.agents/skills/code-review" "stale generated skill is removed"
assert_contains "$FIX/.agents/notes/todo.md" "operator scratch file" "non-owned .agents file survives regeneration"

# --- shared export: the Codex generator and the Zed generator agree ---------

SNAPSHOT="$TMPROOT/snapshot"
mkdir -p "$SNAPSHOT"
cp -R "$FIX/.agents/skills" "$SNAPSHOT/skills"

if bash "$CODEX_SCRIPT" --root "$FIX" >/tmp/_zed_adapter_codex.out 2>&1; then
  mark_pass "Codex generator runs against the same fixture"
else
  mark_fail "Codex generator runs against the same fixture" "$(cat /tmp/_zed_adapter_codex.out)"
fi
if diff -qr "$SNAPSHOT/skills" "$FIX/.agents/skills" >/dev/null 2>&1; then
  mark_pass "Codex generation leaves the Zed-exported tree byte-identical"
else
  mark_fail "Codex generation leaves the Zed-exported tree byte-identical" "$(diff -qr "$SNAPSHOT/skills" "$FIX/.agents/skills" 2>&1)"
fi
if bash "$ZED_SCRIPT" --root "$FIX" --check >/tmp/_zed_adapter_check_after_codex.out 2>&1; then
  mark_pass "Zed --check stays green after Codex generation"
else
  mark_fail "Zed --check stays green after Codex generation" "$(cat /tmp/_zed_adapter_check_after_codex.out)"
fi
if bash "$CODEX_SCRIPT" --root "$FIX" --check >/tmp/_codex_check_after_zed.out 2>&1; then
  mark_pass "Codex --check stays green after Zed generation"
else
  mark_fail "Codex --check stays green after Zed generation" "$(cat /tmp/_codex_check_after_zed.out)"
fi

# --- failure modes ---------------------------------------------------------

INVALID="$TMPROOT/invalid-name"
make_fixture "$INVALID"
rm -rf "$INVALID/.claude/skills/code-review"
mkdir -p "$INVALID/.claude/skills/Bad_Name"
cat > "$INVALID/.claude/skills/Bad_Name/SKILL.md" <<'MD'
---
name: Bad_Name
description: Broken name.
---
MD
if bash "$ZED_SCRIPT" --root "$INVALID" >/tmp/_zed_adapter_bad_name.out 2>&1; then
  mark_fail "invalid skill name fails generation" "expected non-zero exit"
elif grep -q 'not a valid Agent Skills name' /tmp/_zed_adapter_bad_name.out; then
  mark_pass "invalid skill name fails generation"
else
  mark_fail "invalid skill name fails generation" "$(cat /tmp/_zed_adapter_bad_name.out)"
fi

MISMATCH="$TMPROOT/name-mismatch"
make_fixture "$MISMATCH"
rm -rf "$MISMATCH/.claude/skills/code-review"
sed -i.bak 's/^name: status$/name: statuss/' "$MISMATCH/.claude/skills/status/SKILL.md"
rm -f "$MISMATCH/.claude/skills/status/SKILL.md.bak"
if bash "$ZED_SCRIPT" --root "$MISMATCH" >/tmp/_zed_adapter_mismatch.out 2>&1; then
  mark_fail "name/folder mismatch fails generation" "expected non-zero exit"
elif grep -q 'must match its folder name' /tmp/_zed_adapter_mismatch.out; then
  mark_pass "name/folder mismatch fails generation"
else
  mark_fail "name/folder mismatch fails generation" "$(cat /tmp/_zed_adapter_mismatch.out)"
fi

BLOCKSCALAR="$TMPROOT/block-scalar"
make_fixture "$BLOCKSCALAR"
rm -rf "$BLOCKSCALAR/.claude/skills/code-review"
cat > "$BLOCKSCALAR/.claude/skills/status/SKILL.md" <<'MD'
---
name: status
description: >
  A folded description.
---

Body.
MD
if bash "$ZED_SCRIPT" --root "$BLOCKSCALAR" >/tmp/_zed_adapter_block_scalar.out 2>&1; then
  mark_fail "block-scalar frontmatter fails generation" "expected non-zero exit"
elif grep -q 'YAML block scalar' /tmp/_zed_adapter_block_scalar.out; then
  mark_pass "block-scalar frontmatter fails generation"
else
  mark_fail "block-scalar frontmatter fails generation" "$(cat /tmp/_zed_adapter_block_scalar.out)"
fi

# Strict YAML rejects `: ` inside an unquoted value; Zed refuses the skill
# ("Invalid YAML frontmatter"). The export must fail instead (#7).
PLAINCOLON="$TMPROOT/plain-colon"
make_fixture "$PLAINCOLON"
cat > "$PLAINCOLON/.claude/skills/status/SKILL.md" <<'MD'
---
name: status
description: Initiative → tasks: per-milestone interview.
---

Body.
MD
if bash "$ZED_SCRIPT" --root "$PLAINCOLON" >/tmp/_zed_adapter_plain_colon.out 2>&1; then
  mark_fail "unquoted ': ' in a frontmatter value fails generation" "expected non-zero exit"
elif grep -q "unquoted frontmatter value that contains ': '" /tmp/_zed_adapter_plain_colon.out; then
  mark_pass "unquoted ': ' in a frontmatter value fails generation"
else
  mark_fail "unquoted ': ' in a frontmatter value fails generation" "$(cat /tmp/_zed_adapter_plain_colon.out)"
fi

QUOTEDCOLON="$TMPROOT/quoted-colon"
make_fixture "$QUOTEDCOLON"
cat > "$QUOTEDCOLON/.claude/skills/status/SKILL.md" <<'MD'
---
name: status
description: "Initiative → tasks: per-milestone interview."
---

Body.
MD
if bash "$ZED_SCRIPT" --root "$QUOTEDCOLON" >/tmp/_zed_adapter_quoted_colon.out 2>&1; then
  mark_pass "quoted ': ' in a frontmatter value is accepted"
else
  mark_fail "quoted ': ' in a frontmatter value is accepted" "$(cat /tmp/_zed_adapter_quoted_colon.out)"
fi

# Zed refuses a SKILL.md larger than 100KB. The export must fail instead (#7).
OVERSIZE="$TMPROOT/oversize"
make_fixture "$OVERSIZE"
{
  printf '%s\n' '---' 'name: status' 'description: Current status.' '---' ''
  head -c 100001 /dev/zero | tr '\0' 'x'
  printf '\n'
} > "$OVERSIZE/.claude/skills/status/SKILL.md"
if bash "$ZED_SCRIPT" --root "$OVERSIZE" >/tmp/_zed_adapter_oversize.out 2>&1; then
  mark_fail "oversized SKILL.md fails generation" "expected non-zero exit"
elif grep -q 'Zed refuses to load a SKILL.md larger than 100KB' /tmp/_zed_adapter_oversize.out; then
  mark_pass "oversized SKILL.md fails generation"
else
  mark_fail "oversized SKILL.md fails generation" "$(cat /tmp/_zed_adapter_oversize.out)"
fi

SYMLINK="$TMPROOT/symlink-escape"
make_fixture "$SYMLINK"
EXTERNAL="$TMPROOT/external"
mkdir -p "$EXTERNAL"
printf '%s\n' 'outside must survive' > "$EXTERNAL/sentinel.txt"
ln -s "$EXTERNAL" "$SYMLINK/.agents"
if bash "$ZED_SCRIPT" --root "$SYMLINK" >/tmp/_zed_adapter_symlink.out 2>&1; then
  mark_fail "symlinked .agents is rejected" "expected non-zero exit"
elif grep -q 'refusing Zed adapter output through symlink' /tmp/_zed_adapter_symlink.out; then
  mark_pass "symlinked .agents is rejected"
else
  mark_fail "symlinked .agents is rejected" "$(cat /tmp/_zed_adapter_symlink.out)"
fi
if [ "$(cat "$EXTERNAL/sentinel.txt" 2>/dev/null)" = 'outside must survive' ]; then
  mark_pass "symlinked .agents cannot mutate the external directory"
else
  mark_fail "symlinked .agents cannot mutate the external directory" "sentinel changed or missing"
fi

echo
echo "===== test_sync_zed_adapter.sh ====="
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed cases:$FAILED"
  exit 1
fi
exit 0
