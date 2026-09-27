#!/usr/bin/env bash
# Contract test for the Git identity handoff documented by #11.
# The three skills are prose workflows, so this test checks that each one
# carries the source lookup, missing-identity prompt, and target guard.

set -u

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
PASS=0
FAIL=0

mark_pass() {
  printf '  ✓ %s\n' "$1"
  PASS=$((PASS + 1))
}

mark_fail() {
  printf '  ✗ %s: %s\n' "$1" "$2" >&2
  FAIL=$((FAIL + 1))
}

assert_contains() {
  local file="$1"
  local label="$2"
  local needle="$3"

  if grep -qF "$needle" "$file"; then
    mark_pass "$label"
  else
    mark_fail "$label" "missing: $needle"
  fi
}

for skill in setup split-portfolio handover; do
  file="$ROOT/.claude/skills/$skill/SKILL.md"
  if [ ! -f "$file" ]; then
    mark_fail "$skill skill exists" "$file is missing"
    continue
  fi

  mark_pass "$skill skill exists"
  assert_contains "$file" "$skill reads the ops user.name" 'config --get user.name'
  assert_contains "$file" "$skill reads the ops user.email" 'config --get user.email'
  assert_contains "$file" "$skill prompts for an incomplete identity" 'read -r -p "Git user.'
  assert_contains "$file" "$skill rejects an incomplete identity" 'A complete Git identity is required before the first commit.'
  assert_contains "$file" "$skill guards user.name before writing" 'config user.name "$OPS_NAME"'
  assert_contains "$file" "$skill guards user.email before writing" 'config user.email "$OPS_EMAIL"'
done

echo
echo "===== test_git_identity_propagation.sh ====="
echo "Passed: $PASS"
echo "Failed: $FAIL"
[ "$FAIL" -eq 0 ]
