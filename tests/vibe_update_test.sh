#!/usr/bin/env bash
# scripts/vibe-update.sh testi — tag bazli self-update: guncel/ff-safe/sapma/git-yok senaryolari.
# Gercek network YOK — local path-tabanli git remote (git clone) kullanir.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPDATE_SCRIPT="$ROOT/scripts/vibe-update.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

if ! command -v git >/dev/null 2>&1; then
  echo "  skip: git yok — vibe-update testleri atlandi"
  echo "vibe_update_test: 0 passed, 0 failed (skip)"
  exit 0
fi

git_c() { git -c user.email=t@t.com -c user.name=t "$@"; }

# ortak "origin" reposu: baseline commit + v1.0.0 tag
origin="$tmp/origin"; mkdir -p "$origin"
git -C "$origin" init -q
echo "baseline" > "$origin/f.txt"
git_c -C "$origin" add -A && git_c -C "$origin" commit -q -m "baseline"
git_c -C "$origin" tag v1.0.0

# HER UC klonu da v1.0.0 durumundayken simdi olustur (origin daha degismeden)
already_current="$tmp/already-current"; git clone -q "$origin" "$already_current" 2>/dev/null
ff_case="$tmp/ff-case"; git clone -q "$origin" "$ff_case" 2>/dev/null
diverged_case="$tmp/diverged-case"; git clone -q "$origin" "$diverged_case" 2>/dev/null

# 1. zaten en son tag'de -> "guncel" mesaji, exit 0 (origin henuz degismedi)
out="$(bash "$UPDATE_SCRIPT" "$already_current" 2>&1)"; code=$?
[ "$code" -eq 0 ] && ok "zaten guncelken exit 0" || bad "zaten guncelken exit $code"
printf '%s' "$out" | grep -qi 'guncel' && ok "zaten guncel mesaji basildi" || bad "guncel mesaji yok"

# 2. diverged-case KENDI lokal commit'ini simdi atar — v1.1.0'dan ONCE, v1.0.0'dan CATALLANIR
echo "kullanici edit" >> "$diverged_case/f.txt"
git_c -C "$diverged_case" add -A && git_c -C "$diverged_case" commit -q -m "kullanici kendi degisikligi"

# 3. origin'e yeni commit + v1.1.0 tag eklenir (diverged-case'in catalindan BAGIMSIZ, origin'in
#    kendi mainline'inda ilerler)
echo "yeni satir" >> "$origin/f.txt"
git_c -C "$origin" add -A && git_c -C "$origin" commit -q -m "yeni ozellik"
git_c -C "$origin" tag v1.1.0

# 4. ff-case: hala tam v1.0.0'da, temiz — ff-only guncelleme beklenir
out="$(bash "$UPDATE_SCRIPT" "$ff_case" 2>&1)"; code=$?
[ "$code" -eq 0 ] && ok "ff-safe guncelleme exit 0" || bad "ff-safe guncelleme exit $code: $out"
grep -q "yeni satir" "$ff_case/f.txt" && ok "ff-safe: dosya guncellendi" || bad "ff-safe: dosya guncellenmedi"
[ "$(git -C "$ff_case" describe --tags --exact-match 2>/dev/null)" = "v1.1.0" ] && ok "ff-safe: v1.1.0'a tasindi" || bad "ff-safe: dogru tag'e tasinmadi"

# 5. diverged-case: v1.0.0'dan catallanmis kendi commit'i var, v1.1.0 onun ne atasi ne torunu ->
#    otomatik merge YOK, hata, HEAD degismemeli
before="$(git -C "$diverged_case" rev-parse HEAD)"
out="$(bash "$UPDATE_SCRIPT" "$diverged_case" 2>&1)"; code=$?
[ "$code" -ne 0 ] && ok "sapmis kopyada nonzero exit" || bad "sapmis kopyada exit 0 (hata vermeliydi)"
after="$(git -C "$diverged_case" rev-parse HEAD)"
[ "$before" = "$after" ] && ok "sapmis kopyada HEAD degismedi (otomatik merge yok)" || bad "sapmis kopyada HEAD degisti — GUVENLIK IHLALI"

# 6. .git yoksa net hata
nogit="$tmp/no-git"; mkdir -p "$nogit"
out="$(bash "$UPDATE_SCRIPT" "$nogit" 2>&1)"; code=$?
[ "$code" -ne 0 ] && ok ".git yokken nonzero exit" || bad ".git yokken exit 0 (hata vermeliydi)"

echo "vibe_update_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
