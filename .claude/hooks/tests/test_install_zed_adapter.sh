#!/usr/bin/env bash
# Tests for bin/install-zed-adapter.sh (me2resh/apexyard#4 / AgDR-0166).
#
# The load-bearing claims under test:
#   - the deny and confirm rules land under
#     agent.tool_permissions.tools.terminal
#   - every existing key survives, including the global default
#   - a timestamped backup is written before the first change
#   - the installer is idempotent and reports when nothing changed
#   - --check is read-only and detects a missing rule
#   - --uninstall removes exactly ApexYard's rules
#   - invalid JSON is refused without touching the file

set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$ROOT/bin/install-zed-adapter.sh"

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

assert_jq() {
  local file="$1" filter="$2" label="$3"
  if jq -e "$filter" "$file" >/dev/null 2>&1; then
    mark_pass "$label"
  else
    mark_fail "$label" "jq assertion failed: $filter"
  fi
}

backup_count() {
  local dir="$1"
  find "$dir" -maxdepth 1 -name 'settings.json.bak-*' | wc -l | tr -d ' '
}

TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/zed-install-test.XXXXXX")
trap 'rm -rf "$TMPROOT"' EXIT

echo "== Zed adapter installer smoke"

# --- 1. a missing settings file is created, with a backup ---------------

FRESH="$TMPROOT/fresh"
mkdir -p "$FRESH"
if bash "$SCRIPT" --settings "$FRESH/settings.json" >/tmp/_zed_install_fresh.out 2>&1; then
  mark_pass "installer creates a missing settings file"
else
  mark_fail "installer creates a missing settings file" "$(cat /tmp/_zed_install_fresh.out)"
fi
assert_jq "$FRESH/settings.json" '.agent.tool_permissions.tools.terminal.always_deny | length == 3' "three deny rules are installed"
assert_jq "$FRESH/settings.json" '.agent.tool_permissions.tools.terminal.always_confirm | length == 2' "two confirm rules are installed"
assert_jq "$FRESH/settings.json" '[.agent.tool_permissions.tools.terminal.always_deny[].pattern] | index("\\bgit\\s+add\\s+(-A|--all|\\.)(\\s|$)") != null' "git add deny pattern is the canonical shape"
assert_jq "$FRESH/settings.json" '[.agent.tool_permissions.tools.terminal.always_deny[].pattern] | index("\\bgh\\s+pr\\s+merge\\b") != null' "gh pr merge deny pattern is present"
assert_jq "$FRESH/settings.json" '[.agent.tool_permissions.tools.terminal.always_deny[].pattern] | index("\\bgh\\s+api\\b.*/merge(\\s|$)") != null' "gh api merge deny pattern is present"
assert_jq "$FRESH/settings.json" '[.agent.tool_permissions.tools.terminal.always_confirm[].pattern] | index("\\bgh\\s+pr\\s+create\\b") != null' "gh pr create confirm pattern is present"
assert_jq "$FRESH/settings.json" '[.agent.tool_permissions.tools.terminal.always_confirm[].pattern] | index("\\bgh\\s+issue\\s+create\\b") != null' "gh issue create confirm pattern is present"

if [ "$(backup_count "$FRESH")" = "1" ]; then
  mark_pass "installer writes a backup"
else
  mark_fail "installer writes a backup" "expected 1 backup, found $(backup_count "$FRESH")"
fi

# --- 2. an existing file keeps every key ---------------------------------

EXISTING="$TMPROOT/existing"
mkdir -p "$EXISTING"
cat > "$EXISTING/settings.json" <<'JSON'
{
  "theme": "One Dark",
  "buffer_font_size": 15,
  "agent": {
    "tool_permissions": {
      "default": "allow",
      "tools": {
        "terminal": {
          "default": "confirm",
          "always_deny": [{ "pattern": "sudo\\s+rm" }]
        },
        "fetch": { "always_allow": [{ "pattern": "docs\\.rs" }] }
      }
    }
  }
}
JSON
cp "$EXISTING/settings.json" "$EXISTING/before.json"

if bash "$SCRIPT" --settings "$EXISTING/settings.json" >/tmp/_zed_install_existing.out 2>&1; then
  mark_pass "installer merges into an existing file"
else
  mark_fail "installer merges into an existing file" "$(cat /tmp/_zed_install_existing.out)"
fi
assert_jq "$EXISTING/settings.json" '.theme == "One Dark" and .buffer_font_size == 15' "unrelated top-level keys survive"
assert_jq "$EXISTING/settings.json" '.agent.tool_permissions.default == "allow"' "the global default is untouched"
assert_jq "$EXISTING/settings.json" '.agent.tool_permissions.tools.terminal.default == "confirm"' "the tool default is untouched"
assert_jq "$EXISTING/settings.json" '[.agent.tool_permissions.tools.terminal.always_deny[].pattern] | index("sudo\\s+rm") != null' "the operator's own deny rule survives"
assert_jq "$EXISTING/settings.json" '[.agent.tool_permissions.tools.fetch.always_allow[].pattern] | index("docs\\.rs") != null' "other tools' rules survive"
assert_jq "$EXISTING/settings.json" '.agent.tool_permissions.tools.terminal.always_deny | length == 4' "deny rules are appended, not replaced"

# --- 3. idempotent --------------------------------------------------------

cp "$EXISTING/settings.json" "$EXISTING/after-first.json"
if bash "$SCRIPT" --settings "$EXISTING/settings.json" >/tmp/_zed_install_second.out 2>&1; then
  mark_pass "second run succeeds"
else
  mark_fail "second run succeeds" "$(cat /tmp/_zed_install_second.out)"
fi
if diff -q "$EXISTING/after-first.json" "$EXISTING/settings.json" >/dev/null 2>&1; then
  mark_pass "second run changes nothing"
else
  mark_fail "second run changes nothing" "the file changed on a repeat run"
fi
if grep -q 'already installed' /tmp/_zed_install_second.out; then
  mark_pass "second run reports that nothing changed"
else
  mark_fail "second run reports that nothing changed" "$(cat /tmp/_zed_install_second.out)"
fi
if [ "$(backup_count "$EXISTING")" = "1" ]; then
  mark_pass "a no-op run writes no further backup"
else
  mark_fail "a no-op run writes no further backup" "expected 1 backup, found $(backup_count "$EXISTING")"
fi

# --- 4. --check is read-only and detects a missing rule -------------------

if bash "$SCRIPT" --settings "$EXISTING/settings.json" --check >/tmp/_zed_install_check_ok.out 2>&1; then
  mark_pass "--check passes when the rules are installed"
else
  mark_fail "--check passes when the rules are installed" "$(cat /tmp/_zed_install_check_ok.out)"
fi
cp "$EXISTING/settings.json" "$EXISTING/check-before.json"
jq 'del(.agent.tool_permissions.tools.terminal.always_confirm)' "$EXISTING/settings.json" > "$EXISTING/check-tmp.json"
mv "$EXISTING/check-tmp.json" "$EXISTING/settings.json"
# Snapshot the missing-rule state AFTER the deliberate deletion, so the
# comparison below proves --check itself wrote nothing.
cp "$EXISTING/settings.json" "$EXISTING/check-before.json"
if bash "$SCRIPT" --settings "$EXISTING/settings.json" --check >/tmp/_zed_install_check_missing.out 2>&1; then
  mark_fail "--check detects a missing confirm rule" "expected non-zero exit"
else
  mark_pass "--check detects a missing confirm rule"
fi
if diff -q "$EXISTING/check-before.json" "$EXISTING/settings.json" >/dev/null 2>&1; then
  mark_pass "--check writes nothing"
else
  mark_fail "--check writes nothing" "the settings file changed"
fi
bash "$SCRIPT" --settings "$EXISTING/settings.json" >/dev/null 2>&1

# A missing file is a check failure too.
if bash "$SCRIPT" --settings "$TMPROOT/never-created.json" --check >/tmp/_zed_install_check_absent.out 2>&1; then
  mark_fail "--check fails when the settings file is missing" "expected non-zero exit"
else
  mark_pass "--check fails when the settings file is missing"
fi

# --- 5. invalid JSON is refused -------------------------------------------

BROKEN="$TMPROOT/broken"
mkdir -p "$BROKEN"
printf '{ this is not json\n' > "$BROKEN/settings.json"
cp "$BROKEN/settings.json" "$BROKEN/before.json"
if bash "$SCRIPT" --settings "$BROKEN/settings.json" >/tmp/_zed_install_broken.out 2>&1; then
  mark_fail "invalid JSON is refused" "expected non-zero exit"
elif grep -q 'not valid JSON' /tmp/_zed_install_broken.out; then
  mark_pass "invalid JSON is refused"
else
  mark_fail "invalid JSON is refused" "$(cat /tmp/_zed_install_broken.out)"
fi
if diff -q "$BROKEN/before.json" "$BROKEN/settings.json" >/dev/null 2>&1; then
  mark_pass "a refused install leaves the file untouched"
else
  mark_fail "a refused install leaves the file untouched" "the settings file changed"
fi

# --- 6. --uninstall removes exactly ApexYard's rules ---------------------

if bash "$SCRIPT" --settings "$EXISTING/settings.json" --uninstall >/tmp/_zed_install_uninstall.out 2>&1; then
  mark_pass "--uninstall succeeds"
else
  mark_fail "--uninstall succeeds" "$(cat /tmp/_zed_install_uninstall.out)"
fi
assert_jq "$EXISTING/settings.json" '[.agent.tool_permissions.tools.terminal.always_deny[].pattern] | index("sudo\\s+rm") != null' "uninstall keeps the operator's own deny rule"
assert_jq "$EXISTING/settings.json" '[.agent.tool_permissions.tools.terminal.always_deny[]? | select(.pattern | test("git"))] | length == 0' "uninstall removes the git add deny rule"
assert_jq "$EXISTING/settings.json" '.agent.tool_permissions.tools.terminal.always_confirm == []' "uninstall removes the confirm rules"
assert_jq "$EXISTING/settings.json" '.theme == "One Dark"' "uninstall keeps unrelated keys"
if bash "$SCRIPT" --settings "$EXISTING/settings.json" --check >/tmp/_zed_install_check_uninstalled.out 2>&1; then
  mark_fail "--check fails after uninstall" "expected non-zero exit"
else
  mark_pass "--check fails after uninstall"
fi

# --- 7. a symlinked settings file is written through, not replaced --------

LINKED="$TMPROOT/linked"
mkdir -p "$LINKED/real" "$LINKED/conf"
printf '{}\n' > "$LINKED/real/settings.json"
ln -s "$LINKED/real/settings.json" "$LINKED/conf/settings.json"
if bash "$SCRIPT" --settings "$LINKED/conf/settings.json" >/tmp/_zed_install_symlink.out 2>&1; then
  mark_pass "installer writes through a symlinked settings file"
else
  mark_fail "installer writes through a symlinked settings file" "$(cat /tmp/_zed_install_symlink.out)"
fi
if [ -L "$LINKED/conf/settings.json" ]; then
  mark_pass "the symlink survives the install"
else
  mark_fail "the symlink survives the install" "the symlink was replaced by a regular file"
fi
assert_jq "$LINKED/real/settings.json" '.agent.tool_permissions.tools.terminal.always_deny | length == 3' "the symlink target receives the rules"

echo
echo "===== test_install_zed_adapter.sh ====="
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed cases:$FAILED"
  exit 1
fi
exit 0
