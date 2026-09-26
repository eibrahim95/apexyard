#!/bin/bash
# _lib-attribution.sh — shared AI-attribution line matcher (#12, AgDR-0167).
#
# Agents add attribution lines to the commit messages and PR descriptions
# they write: `Co-Authored-By: Claude …`, `Claude-Session: …`, and the
# `Generated with Claude Code` footer. This library is the one place that
# decides which lines count. Three callers use it:
#
#   - .githooks/commit-msg        strips the lines before Git writes a commit
#   - block-ai-attribution.sh     blocks agent commands that carry the lines
#   - /approve-merge              strips the lines from the squash body
#
# Patterns are extended regular expressions, matched case-insensitively
# against one line at a time. Each default pattern is anchored to the start
# of a line, so prose that mentions a trailer mid-sentence does not match.
# A co-author trailer matches only on the Anthropic noreply address, so a
# human co-author never matches, even one named Claude.
#
# Adopters replace the list via .claude/project-config.json →
# .attribution.blocked_patterns. Arrays replace the inherited array
# wholesale, so copy the defaults you want to keep.

_ATTRIBUTION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Built-in defaults. Used when the config cannot be read (no jq, missing
# defaults file) so the matcher never silently degrades to "match nothing".
# Keep in sync with .claude/project-config.defaults.json.
_ATTRIBUTION_DEFAULT_PATTERNS=(
  '^[[:space:]]*Co-authored-by:.*noreply@anthropic\.com'
  '^[[:space:]]*Claude-Session:'
  '^[[:space:]]*(🤖[[:space:]]*)?Generated with \[?Claude Code'
  '^[[:space:]]*<?https://claude\.ai/code/session_'
)

# attribution_patterns — print the active patterns, one per line.
attribution_patterns() {
  local configured=""
  if [ -f "$_ATTRIBUTION_LIB_DIR/_lib-read-config.sh" ]; then
    # shellcheck source=/dev/null
    . "$_ATTRIBUTION_LIB_DIR/_lib-read-config.sh" 2>/dev/null
    if command -v config_get >/dev/null 2>&1; then
      configured=$(config_get '.attribution.blocked_patterns // empty | .[]' 2>/dev/null)
    fi
  fi
  if [ -n "$configured" ]; then
    printf '%s\n' "$configured"
  else
    printf '%s\n' "${_ATTRIBUTION_DEFAULT_PATTERNS[@]}"
  fi
}

# _attribution_pattern_file — write the patterns to a temp file for grep -f.
_attribution_pattern_file() {
  local f
  f=$(mktemp) || return 1
  attribution_patterns > "$f"
  printf '%s' "$f"
}

# attribution_find — read text on stdin, print each attribution line found.
# Exit 0 when at least one line matched, 1 when none did.
attribution_find() {
  local pf rc
  pf=$(_attribution_pattern_file) || return 2
  LC_ALL=C grep -iE -f "$pf"
  rc=$?
  rm -f "$pf"
  return "$rc"
}

# attribution_strip — read text on stdin, write it to stdout without the
# attribution lines. Runs of blank lines left behind collapse to one, and
# trailing blank lines are removed.
attribution_strip() {
  local pf
  pf=$(_attribution_pattern_file) || return 2
  LC_ALL=C grep -viE -f "$pf" | awk '
    /^[[:space:]]*$/ { blank++; next }
    { if (printed && blank) print ""; print; printed = 1; blank = 0 }
  '
  rm -f "$pf"
}
