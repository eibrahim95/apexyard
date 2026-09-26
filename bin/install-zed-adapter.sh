#!/usr/bin/env bash
# Merge the ApexYard tool-permission rules into the operator's Zed settings.
#
# Zed's native agent holds tool permissions in USER settings only (Zed v1.21.0
# documents no project-level permission file), so every developer who wants the
# mechanical half of the Zed adapter runs this installer once per machine.
# Zed's rule precedence makes `always_deny` the highest-priority setting layer
# (built-in security rules sit above it) — see
# https://zed.dev/docs/ai/tool-permissions (verified 2026-09-26).
#
# The rules deny the commands the framework forbids outright and confirm the
# commands it requires a human to approve:
#
#   deny     git add -A / --all / .      (mirrors .claude/hooks/block-git-add-all.sh)
#   deny     gh pr merge                 (mirrors .claude/hooks/block-unreviewed-merge.sh)
#   deny     gh api .../merge            (same hook)
#   confirm  gh pr create
#   confirm  gh issue create
#
# Everything else Zed cannot block stays advisory; docs/harnesses/zed.md lists
# each gate's status. This script never edits .claude/ or the repository.

set -euo pipefail

DEFAULT_SETTINGS=""
SETTINGS=""
CHECK=0
UNINSTALL=0

usage() {
  cat <<'USAGE'
Usage: bin/install-zed-adapter.sh [--settings <path>] [--check] [--uninstall]

Merges ApexYard's tool-permission rules for the Zed native agent into the
operator's Zed settings.json. The merge preserves every existing key and is
safe to run more than once. A timestamped backup is written before any change.

Options:
  --settings PATH  Zed settings.json to edit. Defaults to the path for this
                   platform (~/.config/zed/settings.json on Linux,
                   ~/Library/Application Support/Zed/settings.json on macOS,
                   %APPDATA%\Zed\settings.json on Windows).
  --check          Report whether the rules are installed. Writes nothing;
                   exits non-zero when a rule is missing.
  --uninstall      Remove exactly ApexYard's rules, leaving everything else
                   alone. A timestamped backup is written first.
  -h, --help       Show this help.

Zed allows comments and trailing commas in settings.json (JSONC). For a JSONC
file, --check works as usual. An install or uninstall that needs a change
writes nothing, prints the block to paste, and exits 3.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --settings)
      [ "$#" -ge 2 ] || { echo "ERROR: --settings requires a path" >&2; exit 2; }
      SETTINGS="$2"
      shift
      ;;
    --check) CHECK=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to merge the Zed tool-permission rules safely" >&2
  exit 1
fi

if [ -z "$SETTINGS" ]; then
  case "$(uname -s)" in
    Darwin)
      DEFAULT_SETTINGS="${HOME:-}/Library/Application Support/Zed/settings.json"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      DEFAULT_SETTINGS="${APPDATA:-${HOME:-}/AppData/Roaming}/Zed/settings.json"
      ;;
    *)
      DEFAULT_SETTINGS="${XDG_CONFIG_HOME:-${HOME:-}/.config}/zed/settings.json"
      ;;
  esac
  SETTINGS="$DEFAULT_SETTINGS"
fi

# The rule set. Patterns use Rust regex syntax, which is what Zed compiles;
# JSON escaping turns each `\b` into the two characters backslash + b.
DENY_RULES='[
  {"pattern": "\\bgit\\s+add\\s+(-A|--all|\\.)(\\s|$)"},
  {"pattern": "\\bgh\\s+pr\\s+merge\\b"},
  {"pattern": "\\bgh\\s+api\\b.*/merge(\\s|$)"}
]'
CONFIRM_RULES='[
  {"pattern": "\\bgh\\s+pr\\s+create\\b"},
  {"pattern": "\\bgh\\s+issue\\s+create\\b"}
]'

if [ ! -f "$SETTINGS" ]; then
  if [ "$CHECK" = "1" ]; then
    echo "MISSING: $SETTINGS does not exist; run bin/install-zed-adapter.sh" >&2
    exit 1
  fi
  if [ "$UNINSTALL" = "1" ]; then
    echo "Nothing to uninstall: $SETTINGS does not exist."
    exit 0
  fi
  mkdir -p "$(dirname "$SETTINGS")"
  printf '{}\n' > "$SETTINGS"
fi

# Zed reads settings.json as JSONC: comments and trailing commas are legal, and
# the default file Zed creates starts with `//` comment lines. jq parses strict
# JSON only, so a JSONC file is read through a stripped copy. The installer
# never rewrites a JSONC file, because a jq round-trip would delete the
# operator's comments. It prints the block to paste instead.
JSONC=0
SOURCE_JSON="$SETTINGS"
STRIPPED=""
trap 'if [ -n "$STRIPPED" ]; then rm -f "$STRIPPED"; fi' EXIT

strip_jsonc() {
  # Pass 1 drops // and /* */ comments. Pass 2 drops a comma before } or ].
  # Each pass matches whole string literals first and keeps them unchanged,
  # so a "//" or "," inside a string value survives.
  perl -0777 -pe '
    s{("(?:[^"\\]|\\.)*")|//[^\n]*|/\*.*?\*/}{defined $1 ? $1 : ""}gse;
    s{("(?:[^"\\]|\\.)*")|,(\s*[\}\]])}{defined $1 ? $1 : $2}gse;
  ' "$1"
}

if ! jq empty "$SETTINGS" >/dev/null 2>&1; then
  if command -v perl >/dev/null 2>&1; then
    STRIPPED="$(mktemp "${TMPDIR:-/tmp}/zed-settings-stripped.XXXXXX")"
    strip_jsonc "$SETTINGS" > "$STRIPPED"
  fi
  if [ -n "$STRIPPED" ] && jq empty "$STRIPPED" >/dev/null 2>&1; then
    JSONC=1
    SOURCE_JSON="$STRIPPED"
  else
    echo "ERROR: $SETTINGS is not valid JSON or JSONC; refusing to modify it automatically. Inspect it by hand." >&2
    exit 1
  fi
fi

# merge_rules appends only the rules that are not already present, so a second
# run adds nothing and the operator's own ordering survives.
merge_rules_filter='
  . as $doc
  | ($doc.agent.tool_permissions.tools.terminal.always_deny // []) as $deny_now
  | ($doc.agent.tool_permissions.tools.terminal.always_confirm // []) as $confirm_now
  | .agent.tool_permissions.tools.terminal.always_deny =
      ($deny_now + ($deny | map(select(.pattern as $p | ($deny_now | map(.pattern) | index($p)) | not))))
  | .agent.tool_permissions.tools.terminal.always_confirm =
      ($confirm_now + ($confirm | map(select(.pattern as $p | ($confirm_now | map(.pattern) | index($p)) | not))))
'

uninstall_rules_filter='
  . as $doc
  | ($deny | map(.pattern)) as $deny_patterns
  | ($confirm | map(.pattern)) as $confirm_patterns
  | .agent.tool_permissions.tools.terminal.always_deny =
      (($doc.agent.tool_permissions.tools.terminal.always_deny // [])
       | map(select(.pattern as $p | ($deny_patterns | index($p)) | not)))
  | .agent.tool_permissions.tools.terminal.always_confirm =
      (($doc.agent.tool_permissions.tools.terminal.always_confirm // [])
       | map(select(.pattern as $p | ($confirm_patterns | index($p)) | not)))
'

if [ "$UNINSTALL" = "1" ]; then
  FILTER="$uninstall_rules_filter"
else
  FILTER="$merge_rules_filter"
fi
jq --argjson deny "$DENY_RULES" --argjson confirm "$CONFIRM_RULES" \
  "$FILTER" "$SOURCE_JSON" > "$SETTINGS.tmp"

if ! jq empty "$SETTINGS.tmp" >/dev/null 2>&1; then
  rm -f "$SETTINGS.tmp"
  echo "ERROR: the merged settings are not valid JSON; leaving $SETTINGS untouched." >&2
  exit 1
fi

changed=0
if ! diff -q <(jq -S . "$SOURCE_JSON") <(jq -S . "$SETTINGS.tmp") >/dev/null 2>&1; then
  changed=1
fi

if [ "$CHECK" = "1" ]; then
  rm -f "$SETTINGS.tmp"
  if [ "$changed" = "1" ]; then
    echo "MISSING: Zed tool-permission rules are not fully installed in $SETTINGS; run bin/install-zed-adapter.sh" >&2
    exit 1
  fi
  echo "Zed tool-permission rules are installed in $SETTINGS"
  exit 0
fi

if [ "$UNINSTALL" = "1" ] && [ "$changed" = "0" ]; then
  rm -f "$SETTINGS.tmp"
  echo "No ApexYard rules found in $SETTINGS; nothing to remove."
  exit 0
fi

if [ "$changed" = "0" ]; then
  rm -f "$SETTINGS.tmp"
  echo "Zed tool-permission rules are already installed in $SETTINGS; nothing to change."
  exit 0
fi

if [ "$JSONC" = "1" ]; then
  echo "$SETTINGS contains comments or trailing commas (JSONC)." >&2
  echo "The installer does not rewrite JSONC, because that would delete your comments." >&2
  echo "Merge this block into $SETTINGS by hand. It is the complete terminal" >&2
  echo "rule set, so it replaces agent.tool_permissions.tools.terminal:" >&2
  echo >&2
  jq '{agent: {tool_permissions: {tools: {terminal: .agent.tool_permissions.tools.terminal}}}}' "$SETTINGS.tmp" >&2
  echo >&2
  echo "Then run bin/install-zed-adapter.sh --check to confirm." >&2
  rm -f "$SETTINGS.tmp"
  exit 3
fi

BACKUP="$SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
cp "$SETTINGS" "$BACKUP"

# Write through a symlink (a dotfile manager may own the real file) and
# replace a regular file atomically.
if [ -L "$SETTINGS" ]; then
  cat "$SETTINGS.tmp" > "$SETTINGS"
  rm -f "$SETTINGS.tmp"
else
  mv "$SETTINGS.tmp" "$SETTINGS"
fi

if [ "$UNINSTALL" = "1" ]; then
  echo "Removed ApexYard's Zed tool-permission rules from $SETTINGS"
else
  echo "Installed ApexYard's Zed tool-permission rules in $SETTINGS"
  echo "  denied:  git add -A / --all / ., gh pr merge, gh api .../merge"
  echo "  confirm: gh pr create, gh issue create"
fi
echo "Backup saved at $BACKUP (restore with: cp \"$BACKUP\" \"$SETTINGS\")"
echo "Other gates stay advisory in Zed; see docs/harnesses/zed.md for the table."
