#!/usr/bin/env bash
# scaffold.sh remove testi — dry-run varsayılan, --apply ile gerçek silme; created:false asla
# silinmez, elle düzenlenmiş created:true dosyalar korunur. Bağımsız (dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD="$ROOT/skills/vibe-setup/scaffold.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

# A. manifest yok → temiz mesaj, hata yok
a="$tmp/no-manifest"; mkdir -p "$a"
outA="$(bash "$SCAFFOLD" remove "$a" 2>&1)"; codeA=$?
[ "$codeA" -eq 0 ] && ok "manifest yokken exit 0" || bad "manifest yokken exit $codeA"
printf '%s' "$outA" | grep -q 'kurulu değil' && ok "manifest yok mesaji basildi" || bad "manifest yok mesaji basilmadi"

# B. dry-run — hiçbir şey silinmez
b="$tmp/dry-run"; mkdir -p "$b"; echo '{}' > "$b/package.json"
bash "$SCAFFOLD" init "$b" >/dev/null 2>&1
outB="$(bash "$SCAFFOLD" remove "$b" 2>&1)"
[ -e "$b/AGENTS.md" ] && ok "dry-run: AGENTS.md silinmedi" || bad "dry-run: AGENTS.md silinmis!"
[ -e "$b/.vibe-setup.json" ] && ok "dry-run: manifest silinmedi" || bad "dry-run: manifest silinmis!"
printf '%s' "$outB" | grep -q 'AGENTS.md' && ok "dry-run: AGENTS.md SİLİNECEK listesinde" || bad "dry-run: AGENTS.md listede degil"
printf '%s' "$outB" | grep -q 'Dry-run' && ok "dry-run: dry-run notu basildi" || bad "dry-run notu basilmadi"

# C. --apply — vibe-setup'ın yarattığı, değişmemiş dosyalar gerçekten silinir; manifest de silinir;
#    boşalan dizinler (birden fazla iç içe, farklı yollardan) temizlenir
c="$tmp/apply-clean"; mkdir -p "$c"; echo '{}' > "$c/package.json"
bash "$SCAFFOLD" init "$c" >/dev/null 2>&1
bash "$SCAFFOLD" remove "$c" --apply >/dev/null 2>&1
[ ! -e "$c/AGENTS.md" ] && ok "--apply: AGENTS.md silindi" || bad "--apply: AGENTS.md hala duruyor"
[ ! -e "$c/.gitmessage" ] && ok "--apply: .gitmessage silindi" || bad "--apply: .gitmessage hala duruyor"
[ ! -e "$c/.vibe-setup.json" ] && ok "--apply: manifest silindi" || bad "--apply: manifest hala duruyor"
[ -e "$c/vibe-remove-report.md" ] && ok "--apply: rapor yazildi" || bad "--apply: rapor yok"
[ ! -d "$c/.githooks" ] && ok "--apply: bosalan .githooks/ dizini temizlendi" || bad "--apply: .githooks/ hala duruyor"
[ ! -d "$c/docs" ] && ok "--apply: ic ice bosalan docs/ dizini temizlendi" || bad "--apply: docs/ hala duruyor"

# D. --apply — elle düzenlenmiş (created:true ama sha değişmiş) dosya SİLİNMEZ
d="$tmp/apply-edited"; mkdir -p "$d"; echo '{}' > "$d/package.json"
bash "$SCAFFOLD" init "$d" >/dev/null 2>&1
printf '\n# KULLANICI OZEL SATIR\n' >> "$d/AGENTS.md"
bash "$SCAFFOLD" remove "$d" --apply >/dev/null 2>&1
[ -e "$d/AGENTS.md" ] && ok "--apply: elle duzenlenmis AGENTS.md korundu" || bad "--apply: elle duzenlenmis AGENTS.md silindi!"
grep -q 'KULLANICI OZEL SATIR' "$d/AGENTS.md" 2>/dev/null && ok "--apply: kullanici edit'i korundu" || bad "--apply: kullanici edit'i kayboldu"
[ -e "$d/vibe-remove-report.md" ] && grep -q 'AGENTS.md' "$d/vibe-remove-report.md" && ok "--apply: rapor edited dosyayi listeler" || bad "--apply: rapor edited dosyayi listelemiyor"

# E. --apply — vibe-setup'tan ÖNCE var olan (created:false) dosya ASLA silinmez
e="$tmp/apply-preexisting"; mkdir -p "$e"; echo '{}' > "$e/package.json"
printf '# zaten vardi\n' > "$e/.gitmessage"
bash "$SCAFFOLD" init "$e" >/dev/null 2>&1
bash "$SCAFFOLD" remove "$e" --apply >/dev/null 2>&1
[ -e "$e/.gitmessage" ] && grep -q 'zaten vardi' "$e/.gitmessage" && ok "--apply: onceden var olan .gitmessage ASLA silinmedi" || bad "--apply: onceden var olan .gitmessage silindi — CIDDI HATA"
[ ! -e "$e/AGENTS.md" ] && ok "--apply: vibe-setup'in yarattigi AGENTS.md yine de silindi" || bad "--apply: AGENTS.md silinmedi"
grep -q '1 dosya' "$e/vibe-remove-report.md" 2>/dev/null && ok "--apply: rapor pre-existing sayisini dogru yazar" || bad "--apply: rapor pre-existing sayisi yanlis"

# F. --apply — Cursor/Gemini extras da (created:true, değişmemiş) silinir
f="$tmp/apply-extras"; mkdir -p "$f"; echo '{}' > "$f/package.json"
bash "$SCAFFOLD" init "$f" >/dev/null 2>&1
bash "$SCAFFOLD" init-cursor "$f" >/dev/null 2>&1
bash "$SCAFFOLD" init-gemini "$f" >/dev/null 2>&1
bash "$SCAFFOLD" remove "$f" --apply >/dev/null 2>&1
[ ! -e "$f/GEMINI.md" ] && ok "--apply: GEMINI.md silindi" || bad "--apply: GEMINI.md hala duruyor"
[ ! -e "$f/.cursorrules" ] && ok "--apply: .cursorrules silindi" || bad "--apply: .cursorrules hala duruyor"
[ ! -d "$f/.cursor" ] && ok "--apply: bosalan .cursor/ dizini temizlendi" || bad "--apply: .cursor/ hala duruyor"

# G. --apply — .gitignore satırı silinir, dosyanın geri kalanı korunur
g="$tmp/apply-gitignore"; mkdir -p "$g"; printf 'node_modules/\n' > "$g/.gitignore"
bash "$SCAFFOLD" init "$g" >/dev/null 2>&1
grep -q 'settings.local.json' "$g/.gitignore" && ok "on-kosul: satir eklenmis" || bad "on-kosul basarisiz"
bash "$SCAFFOLD" remove "$g" --apply >/dev/null 2>&1
grep -q 'settings.local.json' "$g/.gitignore" && bad "--apply: gitignore satiri silinmedi" || ok "--apply: gitignore satiri silindi"
grep -q 'node_modules/' "$g/.gitignore" && ok "--apply: gitignore'un geri kalani korundu" || bad "--apply: gitignore'un geri kalani da silindi"

echo "remove_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
