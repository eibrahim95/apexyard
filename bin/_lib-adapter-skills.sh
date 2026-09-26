#!/usr/bin/env bash
# _lib-adapter-skills.sh — the shared skill-export step for generated harness
# adapters.
#
# .claude/skills is the source of truth. Every adapter generator that consumes
# the Agent Skills layout (`.agents/skills/<name>/SKILL.md`) exports through
# THIS library, so the Codex and Zed generators cannot disagree about the
# bytes they write into the shared `.agents/skills` root: run them in any
# order, the tree is identical and both generators' `--check` stays green.
# See docs/agdr/AgDR-0166-zed-native-agent-adapter.md.
#
# Sourced, never executed.

# ---------------------------------------------------------------------------
# The harness-neutral frontmatter field set.
# ---------------------------------------------------------------------------
# Zed documents three SKILL.md fields — name, description and
# disable-model-invocation — and says other Agent Skills fields are planned
# (https://zed.dev/docs/ai/skills, verified 2026-09-26 against Zed v1.21.0).
# Codex requires name + description and puts its extra skill metadata in a
# sibling `agents/openai.yaml` file, not in frontmatter
# (https://developers.openai.com/codex/skills, verified same date).
#
# So the export keeps exactly those three fields and drops the Claude-Code-only
# presentation fields (`argument-hint`, `allowed-tools`, `effort`) that neither
# generated consumer reads. When Zed starts honoring more Agent Skills fields,
# /sync-zed-adapter reports it from the live docs and this list widens.
ADAPTER_SKILL_FIELDS="name description disable-model-invocation"

# adapter_skill_field_supported <key> — 0 when the export keeps the field.
adapter_skill_field_supported() {
  local key
  for key in $ADAPTER_SKILL_FIELDS; do
    [ "$key" = "$1" ] && return 0
  done
  return 1
}

# adapter_skill_name_valid <name> — Agent Skills / Zed name validation:
# lowercase letters, numbers and hyphens, no leading or trailing hyphen, no
# consecutive hyphens, 1-64 characters. Zed refuses to load a skill whose name
# fails these rules, so the exporter fails the whole generation instead of
# emitting an output that silently will not load.
adapter_skill_name_valid() {
  local name="$1"
  [ -n "$name" ] || return 1
  [ "${#name}" -le 64 ] || return 1
  case "$name" in
    -*) return 1 ;;
    *-) return 1 ;;
    *--*) return 1 ;;
    *[!a-z0-9-]*) return 1 ;;
  esac
  return 0
}

# adapter_skill_project_frontmatter <file> — project one SKILL.md's YAML
# frontmatter to $ADAPTER_SKILL_FIELDS and rewrite the file in place. The body
# is preserved byte-for-byte.
#
# The projection is line-based, so a YAML block scalar (`description: >`) would
# be truncated silently. That shape does not exist in the tree today; if one
# appears, this function fails loudly instead of corrupting the value — the
# fix is to teach the projection about block scalars, not to drop them.
adapter_skill_project_frontmatter() {
  local file="$1" tmp fields rc=0
  fields="$ADAPTER_SKILL_FIELDS"
  tmp="$file.tmp.$$"

  awk -v fields="$fields" '
    function keep(k,    n, i, arr) {
      n = split(fields, arr, " ")
      for (i = 1; i <= n; i++) if (arr[i] == k) return 1
      return 0
    }
    NR == 1 {
      if ($0 != "---") exit 2
      in_fm = 1
      print
      next
    }
    in_fm && $0 == "---" { in_fm = 0; print; next }
    in_fm {
      sub(/\r$/, "")
      if ($0 ~ /^[A-Za-z][A-Za-z0-9-]*:[[:space:]]*[>|]/) exit 3
      key = $0
      sub(/:.*/, "", key)
      if (keep(key)) print
      next
    }
    { print }
  ' "$file" > "$tmp" || rc=$?

  if [ "$rc" != "0" ]; then
    rm -f "$tmp"
    case "$rc" in
      2) echo "ERROR: $file does not start with YAML frontmatter; the shared skill export needs a name and a description to produce a loadable Zed/Codex skill. Add them, or exclude the file from .claude/skills." >&2 ;;
      3) echo "ERROR: $file uses a YAML block scalar in its frontmatter; the shared skill export cannot project it safely." >&2 ;;
      *) echo "ERROR: failed to project frontmatter of $file (awk rc=$rc)." >&2 ;;
    esac
    return 1
  fi

  mv "$tmp" "$file"
}

# adapter_skills_export <claude_skills_dir> <out_dir> — write the canonical
# `.agents/skills` tree: one directory per skill in the source, every
# `.claude/skills` path reference rewritten to `.agents/skills`, and each
# SKILL.md frontmatter projected to the harness-neutral field set.
adapter_skills_export() {
  local src="$1" dst="$2"
  local src_dir dir name file fm_name

  [ -d "$src" ] || { echo "ERROR: skills source not found: $src" >&2; return 1; }
  src_dir="$(cd "$src" && pwd)"

  rm -rf "$dst"
  mkdir -p "$dst"

  for dir in "$src_dir"/*/; do
    [ -d "$dir" ] || continue
    [ -f "$dir/SKILL.md" ] || continue
    name="$(basename "$dir")"
    if ! adapter_skill_name_valid "$name"; then
      echo "ERROR: skill directory '$name' is not a valid Agent Skills name (Zed would refuse to load it)." >&2
      return 1
    fi
    cp -R "$dir" "$dst/$name"
  done

  # Rewrite path references in every exported file, then project frontmatter.
  while IFS= read -r -d '' file; do
    perl -0pi -e 's/\.claude\/skills/.agents\/skills/g;' "$file"
  done < <(find "$dst" -type f -print0)

  for dir in "$dst"/*/; do
    [ -f "$dir/SKILL.md" ] || continue
    file="$dir/SKILL.md"
    name="$(basename "$dir")"
    adapter_skill_project_frontmatter "$file" || return 1
    fm_name="$(awk '/^name:/ { sub(/^name:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; exit }' "$file")"
    if [ "$fm_name" != "$name" ]; then
      echo "ERROR: skill '$name' declares name: '$fm_name' — the generated skill name must match its folder name." >&2
      return 1
    fi
  done

  return 0
}

# adapter_skills_sync <staged_dir> <target_dir> — reconcile an exported tree
# into the owned output root. Each generated skill directory is replaced, and
# a skill directory is removed only when its source no longer produces it.
# The target root itself is never deleted: other harness output (or a
# hand-authored file) living beside the generated skills survives.
adapter_skills_sync() {
  local staged="$1" target="$2"
  local dir name

  [ -d "$staged" ] || { echo "ERROR: staged skills tree not found: $staged" >&2; return 1; }
  mkdir -p "$target"

  for dir in "$target"/*/; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    [ -d "$staged/$name" ] || rm -rf "$dir"
  done

  for dir in "$staged"/*/; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    rm -rf "$target/$name"
    cp -R "$dir" "$target/$name"
  done

  return 0
}
