#!/usr/bin/env bash
# scaffold.sh init-aider testi — Aider config uretimi + ezmezlik. Bagimsiz (dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD="$ROOT/skills/vibe-setup/scaffold.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
work="$tmp/repo"; mkdir -p "$work"

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

# 1. ilk init-aider — .aider.conf.yml dusmeli, AGENTS.md'yi okumasini soylemeli
out1="$(bash "$SCAFFOLD" init-aider "$work" 2>&1)"
[ -e "$work/.aider.conf.yml" ] && ok "olustu: .aider.conf.yml" || bad "yok: .aider.conf.yml"
grep -q 'read: AGENTS.md' "$work/.aider.conf.yml" 2>/dev/null && ok ".aider.conf.yml AGENTS.md okumasini soyler" || bad ".aider.conf.yml read: AGENTS.md icermiyor"
printf '%s' "$out1" | grep -q 'NEW' && ok "ilk init-aider NEW basar" || bad "ilk init-aider NEW basmadi"
[ -f "$work/.vibe-setup.json" ] && ok "init-aider tek basina manifest yazar" || bad "init-aider manifest yazmadi"
grep -q '".aider.conf.yml": { "sha": "[0-9]*", "created": true' "$work/.vibe-setup.json" 2>/dev/null && ok "extras: .aider.conf.yml created:true kayitli" || bad "extras: .aider.conf.yml manifest kaydi yok/yanlis"

# 2. ezmezlik — kullanicinin kendi .aider.conf.yml ayarlari ikinci calistirmada korunmali (SKIP)
printf '\nmodel: gpt-4\n' >> "$work/.aider.conf.yml"
before="$(cksum "$work/.aider.conf.yml" | awk '{print $1}')"
out2="$(bash "$SCAFFOLD" init-aider "$work" 2>&1)"
after="$(cksum "$work/.aider.conf.yml" | awk '{print $1}')"
printf '%s' "$out2" | grep -q 'SKIP' && ok "ikinci init-aider SKIP basar" || bad "ikinci init-aider SKIP basmadi"
printf '%s' "$out2" | grep -q 'NEW' && bad "ikinci init-aider NEW basti (ezme riski)" || ok "ikinci init-aider NEW basmaz"
grep -q 'model: gpt-4' "$work/.aider.conf.yml" && ok "kullanici ayari korundu" || bad "kullanici ayari ezildi!"
[ "$before" = "$after" ] && ok ".aider.conf.yml icerik degismedi (cksum)" || bad ".aider.conf.yml degisti — ezme!"

echo "init_aider_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
