#!/usr/bin/env bash
# scaffold.sh audit testi — SCORE formatı + audit→init→audit döngüsü skoru artırır. Bağımsız (dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD="$ROOT/skills/vibe-setup/scaffold.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
work="$tmp/repo"; mkdir -p "$work"

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }
score_of() { bash "$SCAFFOLD" audit "$work" 2>/dev/null | grep -oE 'SCORE=[0-9]+/[0-9]+' | head -1; }
num_of()   { printf '%s' "$1" | sed -E 's#SCORE=([0-9]+)/[0-9]+#\1#'; }

# 1. boş repo audit → SCORE=N/M formatı var
before="$(score_of)"
if printf '%s' "$before" | grep -qE '^SCORE=[0-9]+/[0-9]+$'; then ok "SCORE=N/M formatı ($before)"
else bad "SCORE formatı yok — gelen '$before'"; fi

# 2. boş repo skoru 0 (hiçbir artefakt yok)
[ "$(num_of "$before")" = "0" ] && ok "boş repo SCORE payı 0" || bad "boş repo payı 0 değil ($before)"

# 3. init sonrası audit → skor artmalı (agnostik iskeletler ✅ olur)
bash "$SCAFFOLD" init "$work" >/dev/null 2>&1
after="$(score_of)"
b="$(num_of "$before")"; a="$(num_of "$after")"
[ "$a" -gt "$b" ] && ok "init skoru artırdı ($before → $after)" || bad "skor artmadı ($before → $after)"

echo "audit_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
