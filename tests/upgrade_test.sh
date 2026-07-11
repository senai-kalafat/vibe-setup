#!/usr/bin/env bash
# scaffold.sh upgrade testi — sürümlü drift tespiti: UPDATE/ADD/CONFLICT + manifest + clobber-koruması.
# Bağımsız (dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD="$ROOT/skills/vibe-setup/scaffold.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }
shaf() { cksum < "$1" | awk '{print $1}'; }
field() { printf '%s\n' "$1" | grep "^$2=" | cut -d= -f2-; }     # $1=çıktı $2=anahtar
fresh() { local d="$tmp/$1"; mkdir -p "$d"; echo '{}' > "$d/package.json"; bash "$SCAFFOLD" init "$d" >/dev/null 2>&1; echo "$d"; }
set_msha() { # $1 manifest $2 path $3 newsha
  awk -v p="$2" -v ns="$3" 'index($0,"\""p"\":"){ sub(/"sha": "[0-9]+"/,"\"sha\": \""ns"\"") } {print}' "$1" >"$1.t" && mv "$1.t" "$1"
}

# A. init manifest doğru
d="$(fresh A)"
[ -f "$d/.vibe-setup.json" ] && ok "init manifest yazdı" || bad "manifest yok"
grep -q '"vibeVersion": 3' "$d/.vibe-setup.json" && ok "vibeVersion=3" || bad "vibeVersion yok/yanlış"
grep -q '".githooks/pre-commit": { "v": 2' "$d/.vibe-setup.json" && ok "pre-commit v2 kayıtlı" || bad "pre-commit v kaydı yok"

# B. fresh repo upgrade → drift yok (UPDATE/ADD/CONFLICT boş)
d="$(fresh B)"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
[ -z "$(field "$out" UPDATE)$(field "$out" ADD)$(field "$out" CONFLICT)" ] && ok "fresh upgrade no-op" || bad "fresh upgrade drift bastı: U=$(field "$out" UPDATE) A=$(field "$out" ADD) C=$(field "$out" CONFLICT)"

# C. dokunulmamış + template eski → UPDATE (regen). Eski içerik koy + manifest sha'sını ona eşle.
d="$(fresh C)"
printf '#!/usr/bin/env bash\n# eski v1 pre-commit\nexit 0\n' > "$d/.githooks/pre-commit"
set_msha "$d/.vibe-setup.json" ".githooks/pre-commit" "$(shaf "$d/.githooks/pre-commit")"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
[ "$(field "$out" UPDATE)" = ".githooks/pre-commit" ] && ok "dokunulmamış eski → UPDATE" || bad "UPDATE beklenirken: '$(field "$out" UPDATE)'"
grep -q 'vibe-setup:v2' "$d/.githooks/pre-commit" && grep -qF 'js|ts|jsx|tsx' "$d/.githooks/pre-commit" && ok "pre-commit v2 template'e yenilendi" || bad "regen içeriği yanlış"

# D. elle düzenlenmiş → CONFLICT, EZME yok, ve İKİNCİ upgrade'de hâlâ korunur (sha-preservation fix).
d="$(fresh D)"
orig="$(shaf "$d/.githooks/pre-commit")"
printf '\n# KULLANICI OZEL SATIR\n' >> "$d/.githooks/pre-commit"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
[ "$(field "$out" CONFLICT)" = ".githooks/pre-commit" ] && ok "edited → CONFLICT" || bad "CONFLICT beklenirken: '$(field "$out" CONFLICT)'"
[ -z "$(field "$out" UPDATE)" ] && ok "edited UPDATE basmaz" || bad "edited yanlışlıkla UPDATE: '$(field "$out" UPDATE)'"
grep -q 'KULLANICI OZEL SATIR' "$d/.githooks/pre-commit" && ok "edit korundu (ezilmedi)" || bad "kullanıcı edit'i ezildi!"
grep -q "\"sha\": \"$orig\"" "$d/.vibe-setup.json" && ok "manifest eski sha'yı korudu (blessed değil)" || bad "manifest edited sha'yı blessledi → clobber riski"
out2="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
[ "$(field "$out2" CONFLICT)" = ".githooks/pre-commit" ] && ok "2. upgrade hâlâ CONFLICT" || bad "2. upgrade conflict düştü: U='$(field "$out2" UPDATE)'"
grep -q 'KULLANICI OZEL SATIR' "$d/.githooks/pre-commit" && ok "2. upgrade'de de ezilmedi" || bad "2. upgrade kullanıcı edit'ini ezdi!"

# E. eksik dosya → ADD
d="$(fresh E)"
rm -f "$d/AGENTS.md"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
printf '%s\n' "$(field "$out" ADD)" | grep -q 'AGENTS.md' && ok "eksik dosya → ADD" || bad "ADD beklenirken: '$(field "$out" ADD)'"

# F. seed (settings.json/.gitmessage) elle değişse de CONFLICT değil
d="$(fresh F)"
echo '{ "permissions": { "allow": ["npm test"], "deny": [] } }' > "$d/.claude/settings.json"
printf '\n# proje ozel\n' >> "$d/.gitmessage"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
printf '%s' "$(field "$out" CONFLICT)" | grep -q 'settings.json\|gitmessage' && bad "seed dosya CONFLICT'e düştü" || ok "seed dosyalar yoksayıldı (drift normal)"

# G. legacy (manifest yok) + farklı synced dosya → CONFLICT (provenance yok, güvenli)
d="$(fresh G)"
rm -f "$d/.vibe-setup.json"
printf '\n# legacy ozel\n' >> "$d/.githooks/pre-commit"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
printf '%s' "$out" | grep -q 'legacy' && ok "manifest yok → legacy algılandı" || bad "legacy algılanmadı"
printf '%s\n' "$(field "$out" CONFLICT)" | grep -q 'pre-commit' && ok "legacy farklı dosya → CONFLICT (ezme yok)" || bad "legacy CONFLICT beklenirken: '$(field "$out" CONFLICT)'"

# H. eski manifest sürümü → upgrade sürümü yükseltir; git-repo-değil → v3 migration atlanır (probe-guard)
d="$(fresh H)"
awk '{ sub(/"vibeVersion": 3/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
printf '%s' "$out" | grep -q 'applied=v1' && ok "eski uygulanan sürüm algılandı (v1)" || bad "applied=v1 basılmadı"
grep -q '"vibeVersion": 3' "$d/.vibe-setup.json" && ok "manifest v3'e yükseltildi" || bad "manifest sürümü yükselmedi"
printf '%s\n' "$out" | grep -q '^MIGRATED=' && ok "MIGRATED satırı basıldı" || bad "MIGRATED satırı yok"
[ -z "$(field "$out" MIGRATED)" ] && ok "git-repo-değil → migration atlandı (MIGRATED boş)" || bad "beklenmedik MIGRATED: '$(field "$out" MIGRATED)'"

# I. git repo'da v1→v3 → ticketre migration çalışır (davranış korunur) + idempotent
if command -v git >/dev/null 2>&1; then
  d="$tmp/I"; mkdir -p "$d"; git -C "$d" init -q
  echo '{}' > "$d/package.json"; bash "$SCAFFOLD" init "$d" >/dev/null 2>&1
  awk '{ sub(/"vibeVersion": 3/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
  out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
  printf '%s' "$(field "$out" MIGRATED)" | grep -q 'ticketre' && ok "v3 migration: MIGRATED ticketre bildirir" || bad "MIGRATED ticketre yok: '$(field "$out" MIGRATED)'"
  [ "$(git -C "$d" config --get vibe.ticketre)" = '^[A-Z]{3}-[0-9]{1,4} ' ] && ok "vibe.ticketre eski desene sabitlendi" || bad "vibe.ticketre set edilmedi"
  out2="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
  [ -z "$(field "$out2" MIGRATED)" ] && ok "2. upgrade migration tekrarlamaz (idempotent)" || bad "migration tekrarladı: '$(field "$out2" MIGRATED)'"
else
  echo "  skip: git yok — migration testi atlandı"
fi

echo "upgrade_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
