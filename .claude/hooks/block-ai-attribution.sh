#!/bin/bash
# block-ai-attribution.sh — block agent commands that write AI attribution
# lines into a commit message or a PR description (#12, AgDR-0167).
#
# Fires (via dispatch-bash.sh) on: git commit, gh pr create, gh pr edit,
# gh pr merge. It scans the command text and any message or body file the
# command names (git commit -F/--file, gh --body-file/-F). Any line that
# matches a pattern in _lib-attribution.sh blocks the command.
#
# This is the agent-side layer. It fires in every repo the agent works in,
# including managed-project clones that never set core.hooksPath, and it
# still fires for `git commit --no-verify`. .githooks/commit-msg is the
# git-side layer that strips the same lines for every other author.
#
# Every default pattern is anchored to the start of a line, so a message
# that only mentions a trailer mid-sentence passes.

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$HOOK_DIR/_lib-attribution.sh"

if [ -z "$COMMAND" ]; then
  # jq missing or payload unparseable: scan the raw payload. JSON encodes
  # newlines as \n, so split on them first.
  COMMAND=$(printf '%s' "$INPUT" | sed 's/\\n/\n/g')
fi
[ -n "$COMMAND" ] || exit 0

# Resolve a `cd <dir> &&` prefix so a relative file path resolves where the
# command runs.
CD_TARGET=$(printf '%s' "$COMMAND" | sed -nE 's/^[[:space:]]*cd[[:space:]]+("([^"]+)"|'\''([^'\'']+)'\''|([^[:space:];&]+)).*/\2\3\4/p' | head -1)

# Collect the file arguments that carry message or body text.
FILES=$(printf '%s\n' "$COMMAND" | grep -oE -- '(--body-file|--file|-F)[[:space:]=]+("[^"]+"|'\''[^'\'']+'\''|[^[:space:];&|]+)' \
  | sed -E 's/^(--body-file|--file|-F)[[:space:]=]+//; s/^["'\'']//; s/["'\'']$//')

# A trailer passed as its own argument, such as
# `-m "Co-Authored-By: …"` or `--trailer "Co-authored-by: …"`, does not start
# a line in the command text. Scan a second copy with a line break before
# each message, trailer and body value so the anchored patterns see it.
ARGS_SPLIT=$(printf '%s\n' "$COMMAND" | sed -E 's/(^|[[:space:]])(-m|--message|--trailer|--body|-b|--subject|-t)[[:space:]=]+["'\'']?/\
/g')

HAYSTACK="$COMMAND
$ARGS_SPLIT"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ "$f" = "-" ] && continue
  case "$f" in
    /*) path="$f" ;;
    *) path="${CD_TARGET:+$CD_TARGET/}$f" ;;
  esac
  [ -f "$path" ] && HAYSTACK="$HAYSTACK
$(cat "$path")"
done <<< "$FILES"

FOUND=$(printf '%s\n' "$HAYSTACK" | attribution_find | sort -u)
[ -n "$FOUND" ] || exit 0

{
  echo "BLOCKED: this command writes AI attribution lines into a commit message or PR description."
  echo ""
  echo "Remove these lines, then retry:"
  printf '%s\n' "$FOUND" | sed 's/^/  /'
  echo ""
  echo "Commit messages and PR descriptions carry no AI attribution trailer or footer."
  echo "See .claude/rules/git-conventions.md § \"No AI attribution\"."
  echo "Patterns: .claude/project-config.json → .attribution.blocked_patterns"
} >&2
exit 2
