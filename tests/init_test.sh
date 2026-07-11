#!/usr/bin/env bash
# scaffold.sh init testi — agnostik iskelet üretimi + idempotency (ezmez). Bağımsız (dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD="$ROOT/skills/vibe-setup/scaffold.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
work="$tmp/repo"; mkdir -p "$work"

ok()   { echo "  ok: $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL: $1"; fail=$((fail+1)); }
has()  { [ -e "$work/$1" ] && ok "olustu: $1" || bad "yok: $1"; }

# 1. ilk init — agnostik dosyalar düşmeli (boş repo → unknown stack)
out1="$(bash "$SCAFFOLD" init "$work" 2>&1)"
has AGENTS.md
has docs/README.md
has docs/architecture/decisions/0000-template.md
has .gitmessage
has .githooks/pre-commit
has .githooks/commit-msg
has .claude/settings.json
# git remote/.gitlab yok → GitHub PR şablonu varsayılan
has .github/pull_request_template.md
printf '%s' "$out1" | grep -q 'NEW' && ok "ilk init NEW basar" || bad "ilk init NEW basmadi"

# 2. settings.json geçerli JSON
if command -v jq >/dev/null 2>&1; then
  jq -e . "$work/.claude/settings.json" >/dev/null 2>&1 && ok "settings.json gecerli JSON" || bad "settings.json bozuk JSON"
else
  echo "  skip: jq yok — JSON gecerlilik atlandi"
fi

# 3. idempotency — ikinci init ezmemeli (SKIP) + içerik değişmemeli
before="$(cksum "$work/AGENTS.md" | awk '{print $1}')"
out2="$(bash "$SCAFFOLD" init "$work" 2>&1)"
after="$(cksum "$work/AGENTS.md" | awk '{print $1}')"
printf '%s' "$out2" | grep -q 'SKIP' && ok "ikinci init SKIP basar" || bad "ikinci init SKIP basmadi"
printf '%s' "$out2" | grep -q 'NEW'  && bad "ikinci init NEW basti (ezme riski)" || ok "ikinci init NEW basmaz"
[ "$before" = "$after" ] && ok "AGENTS.md icerik degismedi (cksum)" || bad "AGENTS.md degisti — ezme!"

# 4. hook'lar çalıştırılabilir
[ -x "$work/.githooks/commit-msg" ] && ok "commit-msg +x" || bad "commit-msg +x degil"
[ -x "$work/.githooks/pre-commit" ] && ok "pre-commit +x" || bad "pre-commit +x degil"

# 5. node stack — SRC_RE `\.(js|ts|jsx|tsx)$` `|` içerir; init TAM tamamlanmalı.
#    (regresyon: sed delimiter `|` çakışması init'i yarıda kesiyordu — commit-msg/settings.json düşmüyordu.)
node="$tmp/node"; mkdir -p "$node"; echo '{}' > "$node/package.json"
nout="$(bash "$SCAFFOLD" init "$node" 2>&1)"; ncode=$?
[ "$ncode" -eq 0 ] && ok "node init exit 0" || bad "node init exit $ncode (sed regresyon?)"
printf '%s' "$nout" | grep -qi 'sed:' && bad "node init 'sed:' hatası bastı" || ok "node init sed hatası yok"
[ -e "$node/.githooks/pre-commit" ]   && ok "node pre-commit olustu"   || bad "node pre-commit yok"
[ -e "$node/.githooks/commit-msg" ]   && ok "node commit-msg olustu"   || bad "node commit-msg yok (init yarıda?)"
[ -e "$node/.claude/settings.json" ]  && ok "node settings.json olustu" || bad "node settings.json yok (init yarıda?)"
grep -qF 'js|ts|jsx|tsx' "$node/.githooks/pre-commit" 2>/dev/null && ok "SRC_RE pre-commit'e gömüldü" || bad "SRC_RE gömülmedi"
bash -n "$node/.githooks/pre-commit" 2>/dev/null && ok "node pre-commit gecerli bash" || bad "node pre-commit syntax hatasi"
grep -q '@FMT@\|@SRCRE@\|@STACK@\|@LINT@\|@FMTFILEOK@\|@VER@' "$node/.githooks/pre-commit" 2>/dev/null && bad "ikame edilmemis @marker@ kaldi" || ok "tum @marker@ ikame edildi"

echo "init_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
