#!/usr/bin/env bash
# Generate Zed native-agent adapter files from the canonical .claude runtime.
#
# Zed's native agent has no lifecycle hooks (verified against Zed v1.21.0,
# 2026-09-26), so this adapter is a degraded tier: it ships the skills the
# native agent loads from `.agents/skills/`, and it delegates what Zed can
# enforce to the user-level tool-permission rules that
# `bin/install-zed-adapter.sh` merges into the operator's Zed settings. The
# gates Zed cannot block stay advisory — AGENTS.md carries them, and
# docs/harnesses/zed.md records each gate's status.
#
# `.agents/skills` is produced by the shared export step in
# `bin/_lib-adapter-skills.sh` — the same step `bin/sync-codex-adapter.sh`
# calls — so the two generators write identical bytes into the shared root.
# Run them in either order and neither detects the other as drift
# (docs/agdr/AgDR-0166-zed-native-agent-adapter.md).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK=0
TARGET_ROOT=""

usage() {
  cat <<'USAGE'
Usage: bin/sync-zed-adapter.sh [--check] [--root <path>] [--target-root <path>]

Generate Zed native-agent adapter files from .claude:
  .claude/skills -> .agents/skills   (the path Zed discovers project skills in)

The generated tree is the canonical Agent Skills export: one directory per
skill, path references rewritten, and each SKILL.md frontmatter projected to
the fields Zed documents (name, description, disable-model-invocation).
Codex consumes the same tree, so both generators agree byte-for-byte.

Tool-permission rules for the Zed native agent are NOT generated here; run
bin/install-zed-adapter.sh to merge them into the operator's Zed settings.

Options:
  --check       Do not write files; fail if generated output would differ.
  --root PATH   Repository root to use instead of this script's parent.
  --target-root PATH
                Write generated output under PATH instead of <root>.
  -h, --help    Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) CHECK=1 ;;
    --root)
      [ "$#" -ge 2 ] || { echo "ERROR: --root requires a path" >&2; exit 2; }
      ROOT="$2"
      shift
      ;;
    --target-root)
      [ "$#" -ge 2 ] || { echo "ERROR: --target-root requires a path" >&2; exit 2; }
      TARGET_ROOT="$2"
      shift
      ;;
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

ROOT="$(cd "$ROOT" && pwd)"
[ -n "$TARGET_ROOT" ] && TARGET_ROOT="$(cd "$TARGET_ROOT" && pwd)" || TARGET_ROOT="$ROOT"
CLAUDE_DIR="$ROOT/.claude"

[ -d "$CLAUDE_DIR/skills" ] || { echo "ERROR: .claude/skills not found under $ROOT" >&2; exit 1; }

# shellcheck source=/dev/null
. "$SCRIPT_DIR/_lib-adapter-skills.sh"

# Adapter-owned generated subpaths, relative to the target root. Drift checks
# walk only these paths, so anything else living under .agents/ (a
# hand-authored skill tree, an operator scratch file) is never flagged.
ADAPTER_OWNED_PATHS=(
  ".agents/skills"
)

assert_safe_output_paths() {
  local rel
  if [ -L "$TARGET_ROOT/.agents" ]; then
    echo "ERROR: refusing Zed adapter output through symlink: $TARGET_ROOT/.agents" >&2
    return 1
  fi
  for rel in "${ADAPTER_OWNED_PATHS[@]}"; do
    if [ -L "$TARGET_ROOT/$rel" ]; then
      echo "ERROR: refusing Zed adapter output through symlink: $TARGET_ROOT/$rel" >&2
      return 1
    fi
  done
}

assert_safe_output_paths || exit 1

TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/zed-adapter.XXXXXX")
trap 'rm -rf "$TMPDIR"' EXIT

OUT_AGENTS="$TMPDIR/.agents"
mkdir -p "$OUT_AGENTS"
adapter_skills_export "$CLAUDE_DIR/skills" "$OUT_AGENTS/skills"

if grep -R "$(printf '%s' "$ROOT" | sed 's/[.[\*^$()+?{}|]/\\&/g')" "$OUT_AGENTS" >/dev/null 2>&1; then
  echo "ERROR: generated adapter contains an absolute path to $ROOT" >&2
  exit 1
fi

# Compares one generated root (.agents) against its on-disk counterpart, but
# ONLY across the owned relative paths listed in ADAPTER_OWNED_PATHS — never a
# whole-tree diff.
check_drift() {
  local actual_root="$1" expected_root="$2" label="$3"
  local rc=0 rel child_rel actual expected
  for rel in "${ADAPTER_OWNED_PATHS[@]}"; do
    case "$rel" in
      "$label"/*) child_rel="${rel#"$label"/}" ;;
      *) continue ;;
    esac
    actual="$actual_root/$child_rel"
    expected="$expected_root/$child_rel"
    if [ ! -e "$actual" ]; then
      echo "DRIFT: $label/$child_rel is missing; run bin/sync-zed-adapter.sh" >&2
      rc=1
      continue
    fi
    if ! diff -qr "$expected" "$actual" >/dev/null 2>&1; then
      echo "DRIFT: $label/$child_rel differs from generated output; run bin/sync-zed-adapter.sh" >&2
      diff -qr "$expected" "$actual" >&2 2>&1 || true
      rc=1
    fi
  done
  return "$rc"
}

if [ "$CHECK" = "1" ]; then
  check_drift "$TARGET_ROOT/.agents" "$OUT_AGENTS" ".agents"
  exit $?
fi

mkdir -p "$TARGET_ROOT/.agents"
adapter_skills_sync "$OUT_AGENTS/skills" "$TARGET_ROOT/.agents/skills"

skill_count=$(find "$TARGET_ROOT/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
echo "Generated Zed adapter from .claude:"
echo "  .agents/skills ($skill_count skills)"
