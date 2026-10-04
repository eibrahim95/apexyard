#!/usr/bin/env bash
# Smoke test for /wireframes generators. Runs both against the sample fixture and checks
# the outputs are well-formed and carry every screen. Exit 0 on pass, 1 on fail.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0
check() { if [ "$2" = "ok" ]; then echo "  PASS: $1"; else echo "  FAIL: $1 ($2)"; fail=1; fi; }

python3 "$HERE/scripts/gen_excalidraw.py" --inventory "$HERE/fixtures/sample-inventory.json" \
  --out "$TMP/w.excalidraw" --origin-x 100 --origin-y 50 >/dev/null 2>"$TMP/e1" || check "excalidraw generator runs" "$(cat "$TMP/e1")"
python3 - "$TMP/w.excalidraw" <<'PY' && check "excalidraw scene valid, tags and cards present" ok || check "excalidraw scene valid, tags and cards present" "assertion failed"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["type"] == "excalidraw" and d["elements"]
texts = " ".join(e.get("text", "") for e in d["elements"] if e["type"] == "text")
for needle in ("Cart", "Pay for order", "Offline: needs a connection", "DEBATABLE SPLIT", "GAP-DERIVED PROPOSAL", "From: co1-s01"):
    assert needle in texts, needle
assert min(e["x"] for e in d["elements"]) >= 100
PY

python3 "$HERE/scripts/gen_mermaid.py" --inventory "$HERE/fixtures/sample-inventory.json" \
  --out-dir "$TMP/mm" >/dev/null 2>"$TMP/e2" || check "mermaid generator runs" "$(cat "$TMP/e2")"
files=$(ls "$TMP/mm" 2>/dev/null | tr '\n' ' ')
[ "$files" = "co1.md cross.md hubs.md index.md " ] && check "mermaid writes index plus one file per section" ok || check "mermaid writes index plus one file per section" "got: $files"
blocks=$(cat "$TMP"/mm/co1.md "$TMP"/mm/cross.md "$TMP"/mm/hubs.md | grep -c '^```mermaid')
[ "$blocks" = "6" ] && check "3 sections give 3 flow blocks and 3 screen blocks" ok || check "3 sections give 3 flow blocks and 3 screen blocks" "got $blocks"
grep -q "gap-derived proposal" "$TMP/mm/cross.md" && grep -q "debatable split call" "$TMP/mm/co1.md" && check "mermaid tags debatable and gap-derived screens" ok || check "mermaid tags debatable and gap-derived screens" "tag missing"

[ "$fail" = "0" ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
