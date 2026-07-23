#!/usr/bin/env bash
# scaffold.sh init-gemini testi — Gemini CLI context dosyası üretimi + ezmezlik. Bağımsız (dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD="$ROOT/skills/vibe-setup/scaffold.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
work="$tmp/repo"; mkdir -p "$work"

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

# 1. ilk init-gemini — GEMINI.md düşmeli, CLAUDE.md'yi import etmeli
out1="$(bash "$SCAFFOLD" init-gemini "$work" 2>&1)"
[ -e "$work/GEMINI.md" ] && ok "olustu: GEMINI.md" || bad "yok: GEMINI.md"
grep -q '@CLAUDE.md' "$work/GEMINI.md" 2>/dev/null && ok "GEMINI.md CLAUDE.md'yi import eder" || bad "GEMINI.md @CLAUDE.md import satırı yok"
printf '%s' "$out1" | grep -q 'NEW' && ok "ilk init-gemini NEW basar" || bad "ilk init-gemini NEW basmadi"

# 2. ezmezlik — kullanıcı düzenlemesi ikinci çalıştırmada korunmalı (SKIP)
printf '\n# KULLANICI OZEL KURAL\n' >> "$work/GEMINI.md"
before="$(cksum "$work/GEMINI.md" | awk '{print $1}')"
out2="$(bash "$SCAFFOLD" init-gemini "$work" 2>&1)"
after="$(cksum "$work/GEMINI.md" | awk '{print $1}')"
printf '%s' "$out2" | grep -q 'SKIP' && ok "ikinci init-gemini SKIP basar" || bad "ikinci init-gemini SKIP basmadi"
printf '%s' "$out2" | grep -q 'NEW' && bad "ikinci init-gemini NEW basti (ezme riski)" || ok "ikinci init-gemini NEW basmaz"
grep -q 'KULLANICI OZEL KURAL' "$work/GEMINI.md" && ok "kullanici edit'i korundu" || bad "kullanici edit'i ezildi!"
[ "$before" = "$after" ] && ok "GEMINI.md icerik degismedi (cksum)" || bad "GEMINI.md degisti — ezme!"

echo "init_gemini_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
