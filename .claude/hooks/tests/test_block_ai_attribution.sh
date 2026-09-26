#!/bin/bash
# Tests for AI-attribution enforcement (#12, AgDR-0167):
#   - _lib-attribution.sh      pattern matching and stripping
#   - block-ai-attribution.sh  PreToolUse block on agent commands
#   - .githooks/commit-msg     git-layer strip, run in a real repo
#
# Exit 0 if all cases pass; 1 on any failure.

set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/.claude/hooks/block-ai-attribution.sh"
LIB="$ROOT/.claude/hooks/_lib-attribution.sh"
COMMIT_MSG_HOOK="$ROOT/.githooks/commit-msg"

PASS=0
FAIL=0
FAILED=""

ok()   { PASS=$((PASS + 1)); echo "PASS [$1]"; }
fail() { FAIL=$((FAIL + 1)); FAILED="$FAILED\n  - $1"; echo "FAIL [$1]${2:+ — $2}"; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

CLAUDE_TRAILER='Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
GH_SQUASH_TRAILER='Co-authored-by: Claude Opus 5.5 <noreply@anthropic.com>'
SESSION_LINE='Claude-Session: https://claude.ai/code/session_01AbCdEf'
FOOTER='🤖 Generated with [Claude Code](https://claude.com/claude-code)'
BARE_SESSION_URL='https://claude.ai/code/session_01AbCdEf'
HUMAN_TRAILER='Co-authored-by: Jane Doe <jane@example.com>'

# ---------------------------------------------------------------------------
# Library
# ---------------------------------------------------------------------------
# shellcheck source=/dev/null
. "$LIB"

for line in "$CLAUDE_TRAILER" "$GH_SQUASH_TRAILER" "$SESSION_LINE" "$FOOTER" \
            "Generated with Claude Code" "$BARE_SESSION_URL" \
            "  $CLAUDE_TRAILER" "Co-Authored-By: Claude <noreply@anthropic.com>"; do
  if printf '%s\n' "$line" | attribution_find >/dev/null; then
    ok "lib matches: $line"
  else
    fail "lib matches: $line"
  fi
done

for line in "$HUMAN_TRAILER" \
            'Co-authored-by: Claudette Smith <c@example.com>' \
            '- Block the `Co-Authored-By: Claude` trailer in commits' \
            '- Remove the `Generated with Claude Code` footer' \
            'fix: stop agents adding Claude-Session: lines'; do
  if printf '%s\n' "$line" | attribution_find >/dev/null; then
    fail "lib ignores: $line"
  else
    ok "lib ignores: $line"
  fi
done

got=$(printf 'feat: x\n\n- detail\n\n%s\n%s\n\n%s\n' "$CLAUDE_TRAILER" "$SESSION_LINE" "$FOOTER" | attribution_strip)
want=$(printf 'feat: x\n\n- detail')
[ "$got" = "$want" ] && ok "lib strip removes lines and trailing blanks" \
  || fail "lib strip removes lines and trailing blanks" "got: $(printf '%q' "$got")"

got=$(printf 'feat: x\n\n%s\n%s\n' "$HUMAN_TRAILER" "$CLAUDE_TRAILER" | attribution_strip)
want=$(printf 'feat: x\n\n%s' "$HUMAN_TRAILER")
[ "$got" = "$want" ] && ok "lib strip keeps human co-author" \
  || fail "lib strip keeps human co-author" "got: $(printf '%q' "$got")"

# ---------------------------------------------------------------------------
# PreToolUse hook
# ---------------------------------------------------------------------------
run_hook() {
  jq -nc --arg c "$1" '{tool_input:{command:$c}}' | "$HOOK" >/dev/null 2>"$TMP/stderr"
}

expect_block() {
  local label="$1" cmd="$2"
  run_hook "$cmd"; local rc=$?
  if [ "$rc" -eq 2 ]; then ok "hook blocks: $label"; else fail "hook blocks: $label" "rc=$rc"; fi
}
expect_allow() {
  local label="$1" cmd="$2"
  run_hook "$cmd"; local rc=$?
  if [ "$rc" -eq 0 ]; then ok "hook allows: $label"; else fail "hook allows: $label" "rc=$rc $(cat "$TMP/stderr")"; fi
}

expect_block "git commit heredoc with Claude trailer" "git commit -m \"\$(cat <<'EOF'
feat: x

$CLAUDE_TRAILER
EOF
)\""
expect_block "git commit with Claude-Session line" "git commit -m 'feat: x

$SESSION_LINE'"
expect_block "gh pr create with footer" "gh pr create --title 'feat(x): y' --body '## Summary
- x

$FOOTER'"

printf '## Summary\n- x\n\n%s\n' "$FOOTER" > "$TMP/body.md"
expect_block "gh pr create --body-file with footer" "gh pr create --title 'feat(x): y' --body-file $TMP/body.md"
expect_block "gh pr edit -F with footer" "gh pr edit 5 -F \"$TMP/body.md\""

mkdir -p "$TMP/proj"
printf 'feat: x\n\n%s\n' "$CLAUDE_TRAILER" > "$TMP/proj/msg.txt"
expect_block "cd + git commit -F relative file" "cd $TMP/proj && git commit -F msg.txt"

grep -q 'Remove these lines' "$TMP/stderr" && grep -qF "$CLAUDE_TRAILER" "$TMP/stderr" \
  && ok "hook message names the line" || fail "hook message names the line" "$(cat "$TMP/stderr")"

expect_allow "git commit with human co-author" "git commit -m 'feat: x

$HUMAN_TRAILER'"
expect_allow "commit that mentions the trailer mid-line" "git commit -m 'feat: x

- Block the \`Co-Authored-By: Claude\` trailer and the \`Generated with Claude Code\` footer'"
printf '## Summary\n- clean\n' > "$TMP/clean.md"
expect_allow "gh pr create with clean body file" "gh pr create --title 'feat(x): y' --body-file $TMP/clean.md"

# ---------------------------------------------------------------------------
# .githooks/commit-msg in a real repository
# ---------------------------------------------------------------------------
REPO="$TMP/repo"
mkdir -p "$REPO/.claude/hooks" "$REPO/.githooks"
cp "$LIB" "$ROOT/.claude/hooks/_lib-read-config.sh" "$REPO/.claude/hooks/"
cp "$ROOT/.claude/project-config.defaults.json" "$REPO/.claude/"
cp "$COMMIT_MSG_HOOK" "$REPO/.githooks/commit-msg"
(
  cd "$REPO" || exit 1
  git init -q -b feature/x
  git config user.email t@example.com
  git config user.name Tester
  git config core.hooksPath .githooks
  echo a > a.txt
  git add a.txt
  printf 'feat: add a\n\n- detail\n\n%s\n%s\n%s\n' "$HUMAN_TRAILER" "$CLAUDE_TRAILER" "$SESSION_LINE" > "$TMP/m1"
  git commit -q -F "$TMP/m1" 2>"$TMP/cm_stderr"
) || fail "commit-msg: commit succeeded"

msg=$(git -C "$REPO" log -1 --format=%B)
want=$(printf 'feat: add a\n\n- detail\n\n%s' "$HUMAN_TRAILER")
[ "$msg" = "$(printf '%s\n' "$want")" ] || [ "$msg" = "$want" ] \
  && ok "commit-msg strips Claude lines, keeps the rest" \
  || fail "commit-msg strips Claude lines, keeps the rest" "got: $(printf '%q' "$msg")"
grep -q 'removed AI attribution line' "$TMP/cm_stderr" \
  && ok "commit-msg reports removed lines" || fail "commit-msg reports removed lines"

(
  cd "$REPO" || exit 1
  echo b > b.txt
  git add b.txt
  git commit -q -m 'feat: add b' 2>"$TMP/cm_stderr2"
)
[ "$(git -C "$REPO" log -1 --format=%s)" = "feat: add b" ] && [ ! -s "$TMP/cm_stderr2" ] \
  && ok "commit-msg leaves a clean message alone" || fail "commit-msg leaves a clean message alone"

# Config override replaces the list.
printf '{"attribution":{"blocked_patterns":["^Signed-off-by: Bot"]}}\n' > "$REPO/.claude/project-config.json"
(
  cd "$REPO" || exit 1
  echo c > c.txt
  git add c.txt
  printf 'feat: add c\n\nSigned-off-by: Bot\n%s\n' "$CLAUDE_TRAILER" > "$TMP/m3"
  git commit -q -F "$TMP/m3" 2>/dev/null
)
msg=$(git -C "$REPO" log -1 --format=%B)
if ! printf '%s' "$msg" | grep -q 'Signed-off-by: Bot' && printf '%s' "$msg" | grep -qF "$CLAUDE_TRAILER"; then
  ok "config override replaces the pattern list"
else
  fail "config override replaces the pattern list" "got: $(printf '%q' "$msg")"
fi

echo ""
echo "Passed: $PASS  Failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'Failures:%b\n' "$FAILED"
  exit 1
fi
exit 0
