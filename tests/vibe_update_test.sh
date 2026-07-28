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

# 7. ahead-case: origin v1.1.0'i taglemis DURUMDAYKEN klonlanir (N2 zaten HEAD'de), sonra kendi
#    lokal commit'ini N2'nin USTUNE atar -> local, tag'in (v1.1.0=N2) torunu -> "zaten daha yeni"
#    no-op beklenir, exit 0, HEAD DEGISMEMELI (guncelleme yapilmamali)
ahead_case="$tmp/ahead-case"; git clone -q "$origin" "$ahead_case" 2>/dev/null
echo "ahead lokal commit" >> "$ahead_case/f.txt"
git_c -C "$ahead_case" add -A && git_c -C "$ahead_case" commit -q -m "henuz taglenmemis lokal commit"
before_ahead="$(git -C "$ahead_case" rev-parse HEAD)"
out="$(bash "$UPDATE_SCRIPT" "$ahead_case" 2>&1)"; code=$?
[ "$code" -eq 0 ] && ok "tag'den ileri kopyada exit 0" || bad "tag'den ileri kopyada exit $code"
printf '%s' "$out" | grep -qi 'daha yeni' && ok "tag'den ileri: bilgilendirici mesaj basildi" || bad "tag'den ileri: mesaj yok"
after_ahead="$(git -C "$ahead_case" rev-parse HEAD)"
[ "$before_ahead" = "$after_ahead" ] && ok "tag'den ileri kopyada HEAD degismedi (no-op)" || bad "tag'den ileri kopyada HEAD degisti"

# 8. self-anchor: DIR verilmezse script'in KENDI kurulu kopyasina (BASH_SOURCE ile repo koku) gider,
#    cagiranin cwd'sindeki BASKA bir repoya DEGIL. "install" scripts/vibe-update.sh'in bir kopyasini
#    barindiran ayri bir repo; "victim" cagiranin cwd'sinde duran, ILGISIZ ama sömürülebilir gorunen
#    bir repo (origin + kendinden ileri bir tag). Eski (fix-oncesi) script cwd'ye bakardi ve victim'i
#    fetch+ff-merge ederdi — bu, gercek review'de repro edilen veri-kaybi senaryosu.
install_origin="$tmp/install-origin"; mkdir -p "$install_origin"
git -C "$install_origin" init -q
echo "install-base" > "$install_origin/i.txt"
git_c -C "$install_origin" add -A && git_c -C "$install_origin" commit -q -m "install baseline"
install_dir="$tmp/install"; git clone -q "$install_origin" "$install_dir" 2>/dev/null
mkdir -p "$install_dir/scripts"
cp "$UPDATE_SCRIPT" "$install_dir/scripts/vibe-update.sh"
echo "install-yeni" > "$install_origin/i.txt"
git_c -C "$install_origin" add -A && git_c -C "$install_origin" commit -q -m "install yeni surum"
git_c -C "$install_origin" tag v2.0.0

victim_origin="$tmp/victim-origin"; mkdir -p "$victim_origin"
git -C "$victim_origin" init -q
echo "victim-base" > "$victim_origin/v.txt"
git_c -C "$victim_origin" add -A && git_c -C "$victim_origin" commit -q -m "victim baseline"
victim="$tmp/victim"; git clone -q "$victim_origin" "$victim" 2>/dev/null
echo "victim-yeni-SOMURULDU" > "$victim_origin/v.txt"
git_c -C "$victim_origin" add -A && git_c -C "$victim_origin" commit -q -m "victim yeni surum"
git_c -C "$victim_origin" tag v9.9.9

victim_before="$(git -C "$victim" rev-parse HEAD)"
out="$(cd "$victim" && bash "$install_dir/scripts/vibe-update.sh" 2>&1)"; code=$?
victim_after="$(git -C "$victim" rev-parse HEAD)"
[ "$victim_before" = "$victim_after" ] && ok "self-anchor: cagiranin cwd'sindeki victim repo dokunulmadi" || bad "self-anchor: victim repo GUNCELLENDI — GUVENLIK IHLALI"
grep -q "SOMURULDU" "$victim/v.txt" && bad "self-anchor: victim dosyasi somuruldu — GUVENLIK IHLALI" || ok "self-anchor: victim dosyasi degismedi"
[ "$(git -C "$install_dir" rev-parse HEAD)" = "$(git -C "$install_origin" rev-parse HEAD)" ] && ok "self-anchor: kendi kurulu kopyasi (install_dir) guncellendi" || bad "self-anchor: kendi kurulu kopyasi guncellenmedi (kod $code, cikti: $out)"

# 9. worktree kurulumu: .git bir DOSYAdir (dizin degil) — bu asla yanlislikla reddedilmemeli
worktree_origin="$tmp/wt-origin"; mkdir -p "$worktree_origin"
git -C "$worktree_origin" init -q
echo "wt-base" > "$worktree_origin/w.txt"
git_c -C "$worktree_origin" add -A && git_c -C "$worktree_origin" commit -q -m "wt baseline"
git_c -C "$worktree_origin" tag v3.0.0
wt="$tmp/wt-worktree"
git -C "$worktree_origin" worktree add -q "$wt" -b wt-branch >/dev/null 2>&1
[ -f "$wt/.git" ] && ok "worktree kurulumu: .git bir dosya (on-kosul dogrulandi)" || bad "worktree on-kosulu kurulamadi (.git dosya degil)"
out="$(bash "$UPDATE_SCRIPT" "$wt" 2>&1)"; code=$?
printf '%s' "$out" | grep -q "git repo koku degil" && bad "worktree: yanlislikla reddedildi (.git dosyasi false-negative)" || ok "worktree: repo-degil hatasi basilmadi (kabul edildi)"

# 10. git repo icine GOMULU, KENDISI git-olmayan bir kopya — REDDEDILMELI (repo-koku degil ic-ice dizin)
outer_origin="$tmp/outer-origin"; mkdir -p "$outer_origin"
git -C "$outer_origin" init -q
echo "outer-base" > "$outer_origin/o.txt"
git_c -C "$outer_origin" add -A && git_c -C "$outer_origin" commit -q -m "outer baseline"
git_c -C "$outer_origin" tag v4.0.0
outer="$tmp/outer"; git clone -q "$outer_origin" "$outer" 2>/dev/null
echo "outer-yeni-SOMURULDU" > "$outer_origin/o.txt"
git_c -C "$outer_origin" add -A && git_c -C "$outer_origin" commit -q -m "outer yeni surum"
git_c -C "$outer_origin" tag v5.0.0
nested="$outer/plugins/vibe-setup"; mkdir -p "$nested"
outer_before="$(git -C "$outer" rev-parse HEAD)"
out="$(bash "$UPDATE_SCRIPT" "$nested" 2>&1)"; code=$?
outer_after="$(git -C "$outer" rev-parse HEAD)"
[ "$code" -ne 0 ] && ok "ic-ice git-olmayan kopya: nonzero exit" || bad "ic-ice git-olmayan kopya: exit 0 (reddetmeliydi)"
[ "$outer_before" = "$outer_after" ] && ok "ic-ice git-olmayan kopya: DIS repo dokunulmadi" || bad "ic-ice git-olmayan kopya: DIS repo GUNCELLENDI — GUVENLIK IHLALI"

# 11. cagiranin ortaminda GIT_DIR set edilmisse (git hook/rebase --exec/submodule foreach miras
#     birakabilir), plain git-olmayan bir dizin YANLISLIKLA kabul edilip BASKA repo fetch+ff-merge
#     EDILMEMELI. GIT_WORK_TREE olmadan GIT_DIR tek basina show-toplevel'i cwd'ye "yapistirir" —
#     script bunu ACIKCA unset etmeli.
gitdir_victim_origin="$tmp/gitdir-victim-origin"; mkdir -p "$gitdir_victim_origin"
git -C "$gitdir_victim_origin" init -q
echo "gitdir-victim-base" > "$gitdir_victim_origin/g.txt"
git_c -C "$gitdir_victim_origin" add -A && git_c -C "$gitdir_victim_origin" commit -q -m "gitdir victim baseline"
git_c -C "$gitdir_victim_origin" tag v6.0.0
gitdir_victim="$tmp/gitdir-victim"; git clone -q "$gitdir_victim_origin" "$gitdir_victim" 2>/dev/null
echo "gitdir-victim-yeni-SOMURULDU" > "$gitdir_victim_origin/g.txt"
git_c -C "$gitdir_victim_origin" add -A && git_c -C "$gitdir_victim_origin" commit -q -m "gitdir victim yeni surum"
git_c -C "$gitdir_victim_origin" tag v7.0.0
plainnongit="$tmp/plain-non-git"; mkdir -p "$plainnongit"
echo "kullanicinin degerli dosyasi" > "$plainnongit/important.txt"
gitdir_victim_before="$(git -C "$gitdir_victim" rev-parse HEAD)"
out="$(GIT_DIR="$gitdir_victim/.git" bash "$UPDATE_SCRIPT" "$plainnongit" 2>&1)"; code=$?
gitdir_victim_after="$(git -C "$gitdir_victim" rev-parse HEAD)"
[ "$code" -ne 0 ] && ok "GIT_DIR ortam degiskeni ile: nonzero exit" || bad "GIT_DIR ortam degiskeni ile: exit 0 (reddetmeliydi)"
[ "$gitdir_victim_before" = "$gitdir_victim_after" ] && ok "GIT_DIR ortam degiskeni ile: victim repo dokunulmadi" || bad "GIT_DIR ortam degiskeni ile: victim repo GUNCELLENDI — GUVENLIK IHLALI"
grep -q "kullanicinin degerli dosyasi" "$plainnongit/important.txt" && ok "GIT_DIR ortam degiskeni ile: plain dizindeki dosya bozulmadi" || bad "GIT_DIR ortam degiskeni ile: plain dizin BOZULDU"

# 12. case-insensitive dosya sistemi (macOS/APFS varsayilan): DIR farkli buyuk/kucuk harfle
#     verilse bile ayni fiziksel dizine cozulmeli, YANLISLIKLA reddedilmemeli. Case-sensitive
#     dosya sisteminde (cogu Linux) bu senaryo kurulamaz — o zaman atlanir.
casetest="$tmp/CaseProbe"; mkdir -p "$casetest"
if [ -d "$tmp/caseprobe" ]; then
  case_origin="$tmp/CaseInstall-origin"; mkdir -p "$case_origin"
  git -C "$case_origin" init -q
  echo "case-base" > "$case_origin/c.txt"
  git_c -C "$case_origin" add -A && git_c -C "$case_origin" commit -q -m "case baseline"
  git_c -C "$case_origin" tag v8.0.0
  case_install="$tmp/CaseInstall"; git clone -q "$case_origin" "$case_install" 2>/dev/null
  case_lower="$(dirname "$case_install")/$(basename "$case_install" | tr 'A-Z' 'a-z')"
  out="$(bash "$UPDATE_SCRIPT" "$case_lower" 2>&1)"; code=$?
  [ "$code" -eq 0 ] && ok "case-variant yol: kabul edildi (dosya sistemi case-insensitive)" || bad "case-variant yol: reddedildi (kod $code): $out"
else
  echo "  skip: dosya sistemi case-sensitive — case-variant testi atlandi"
fi

echo "vibe_update_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
