#!/usr/bin/env bash
# scaffold.sh init-cursor testi — Cursor kural dosyaları üretimi + ezmezlik. Bağımsız (dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD="$ROOT/skills/vibe-setup/scaffold.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
work="$tmp/repo"; mkdir -p "$work"

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

# 1. ilk init-cursor — iki kural dosyası düşmeli, ikisi de CLAUDE.md'ye yönlendirmeli
out1="$(bash "$SCAFFOLD" init-cursor "$work" 2>&1)"
[ -e "$work/.cursor/rules/project.mdc" ] && ok "olustu: .cursor/rules/project.mdc" || bad "yok: .cursor/rules/project.mdc"
[ -e "$work/.cursorrules" ] && ok "olustu: .cursorrules" || bad "yok: .cursorrules"
grep -q 'CLAUDE.md' "$work/.cursor/rules/project.mdc" 2>/dev/null && ok "project.mdc CLAUDE.md'ye yonlendirir" || bad "project.mdc CLAUDE.md referansi yok"
grep -q 'CLAUDE.md' "$work/.cursorrules" 2>/dev/null && ok ".cursorrules CLAUDE.md'ye yonlendirir" || bad ".cursorrules CLAUDE.md referansi yok"
grep -q 'alwaysApply: true' "$work/.cursor/rules/project.mdc" 2>/dev/null && ok "project.mdc frontmatter alwaysApply" || bad "project.mdc frontmatter eksik"
printf '%s' "$out1" | grep -q 'NEW' && ok "ilk init-cursor NEW basar" || bad "ilk init-cursor NEW basmadi"

# 2. ezmezlik — kullanıcı düzenlemesi ikinci çalıştırmada korunmalı (SKIP)
printf '\n# KULLANICI OZEL KURAL\n' >> "$work/.cursorrules"
before="$(cksum "$work/.cursor/rules/project.mdc" | awk '{print $1}')"
out2="$(bash "$SCAFFOLD" init-cursor "$work" 2>&1)"
after="$(cksum "$work/.cursor/rules/project.mdc" | awk '{print $1}')"
printf '%s' "$out2" | grep -q 'SKIP' && ok "ikinci init-cursor SKIP basar" || bad "ikinci init-cursor SKIP basmadi"
printf '%s' "$out2" | grep -q 'NEW' && bad "ikinci init-cursor NEW basti (ezme riski)" || ok "ikinci init-cursor NEW basmaz"
grep -q 'KULLANICI OZEL KURAL' "$work/.cursorrules" && ok "kullanici edit'i korundu" || bad "kullanici edit'i ezildi!"
[ "$before" = "$after" ] && ok "project.mdc icerik degismedi (cksum)" || bad "project.mdc degisti — ezme!"

echo "init_cursor_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
