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

# 2. settings.json + manifest geçerli JSON
if command -v jq >/dev/null 2>&1; then
  jq -e . "$work/.claude/settings.json" >/dev/null 2>&1 && ok "settings.json gecerli JSON" || bad "settings.json bozuk JSON"
  jq -e . "$work/.vibe-setup.json" >/dev/null 2>&1 && ok ".vibe-setup.json gecerli JSON" || bad ".vibe-setup.json bozuk JSON"
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
grep -q '@FMT@\|@SRCRE@\|@STACK@\|@LINT@\|@FMTFILEOK@\|@LINTFILEOK@\|@VER@' "$node/.githooks/pre-commit" 2>/dev/null && bad "ikame edilmemis @marker@ kaldi" || ok "tum @marker@ ikame edildi"

# 6. created flag — yeni yazılan dosya true, önceden var olan (SKIP'lenen) dosya false
pre="$tmp/pre-existing"; mkdir -p "$pre"
echo '# zaten vardı' > "$pre/.gitmessage"
bash "$SCAFFOLD" init "$pre" >/dev/null 2>&1
grep -q '"AGENTS.md": { "v": 4, "sha": "[0-9]*", "created": true' "$pre/.vibe-setup.json" && ok "yeni yazilan AGENTS.md created:true" || bad "AGENTS.md created:true degil"
grep -q '".gitmessage": { "v": 3, "sha": "[0-9]*", "created": false' "$pre/.vibe-setup.json" && ok "onceden var olan .gitmessage created:false" || bad ".gitmessage created:false degil"

# 7. gitignoreLine — init'in .gitignore'a eklediği satır manifestte kayıtlı, upgrade'de de korunur
gi1="$tmp/gitignore-append"; mkdir -p "$gi1"; printf 'node_modules/\n' > "$gi1/.gitignore"
bash "$SCAFFOLD" init "$gi1" >/dev/null 2>&1
grep -q 'settings.local.json' "$gi1/.gitignore" && ok "gitignore satiri eklendi" || bad "gitignore satiri eklenmedi"
grep -q '"gitignoreLine": ".claude/settings.local.json"' "$gi1/.vibe-setup.json" && ok "gitignoreLine manifestte kayitli" || bad "gitignoreLine manifestte yok"
bash "$SCAFFOLD" upgrade "$gi1" >/dev/null 2>&1
grep -q '"gitignoreLine": ".claude/settings.local.json"' "$gi1/.vibe-setup.json" && ok "gitignoreLine upgrade sonrasi da korunur" || bad "gitignoreLine upgrade'de kayboldu"

# 8. gitignoreLine — satır zaten varsa hiçbir şey eklenmez/kaydedilmez
gi2="$tmp/gitignore-preexisting"; mkdir -p "$gi2"; printf 'node_modules/\n.claude/settings.local.json\n' > "$gi2/.gitignore"
bash "$SCAFFOLD" init "$gi2" >/dev/null 2>&1
grep -q 'gitignoreLine' "$gi2/.vibe-setup.json" && bad "onceden var olan satir yanlislikla kaydedildi" || ok "onceden var olan satir kaydedilmedi"

# 9. gitignoreLine — .gitignore hiç yoksa sorun çıkarmaz, alan basılmaz
gi3="$tmp/no-gitignore"; mkdir -p "$gi3"
bash "$SCAFFOLD" init "$gi3" >/dev/null 2>&1
grep -q 'gitignoreLine' "$gi3/.vibe-setup.json" && bad ".gitignore yokken gitignoreLine basildi" || ok ".gitignore yokken gitignoreLine basilmadi"

echo "init_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
