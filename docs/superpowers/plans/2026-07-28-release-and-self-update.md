# Release & Self-Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give vibe-setup a tag-based release workflow (`scripts/release.sh` + `RELEASE.md`) and a self-update command (`scripts/vibe-update.sh`) that updates the tool's own installed copy — distinct from the existing `scaffold.sh upgrade`, which updates a *target* repo's scaffolded files against `VIBE_VERSION`.

**Architecture:** Three independent pieces. (1) `scripts/release.sh [major|minor|patch] [DIR]` computes the next semver version from `.claude-plugin/plugin.json`'s current `"version"`, writes it, and calls the existing `scripts/version-sync.sh` to propagate — it never commits or tags (ticket-key selection for the commit is a human/LLM judgment call, not mechanical). (2) `RELEASE.md` documents the full manual release process end-to-end (bump → review → commit → tag → push) and the consumer-side self-update flow. (3) `scripts/vibe-update.sh [DIR]` fetches tags for the *installed copy's own repo* and fast-forwards to the latest `v*` tag only when safe — refusing outright if the local copy has diverged (hand-edited), matching this project's "never clobber" ethos already established for `scaffold.sh upgrade`/`remove`.

**Tech Stack:** Bash (both new scripts reuse this codebase's established `awk gsub + tmp-file + mv` idiom, no `sed -i`, no Node), Markdown (`RELEASE.md`, `CLAUDE.md`), bash test harness (`tests/release_test.sh`, `tests/vibe_update_test.sh` — the latter uses local-path git remotes via `git clone`, no real network).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-28-release-and-self-update-design.md` (approved).
- No Node.js, no `sed -i` — reuse the exact `awk '{ gsub(...) }' file > file.tmp && mv file.tmp file` idiom already used in `scripts/version-sync.sh`.
- `scripts/release.sh` **never runs `git commit` or `git tag`** — it only computes the new version and writes/propagates it. Committing (with the required `VIB-N` ticket-key subject) and tagging are manual, human/LLM-driven steps documented in `RELEASE.md`.
- `scripts/vibe-update.sh` is **tag-based, not branch-HEAD-based** — this repo's `main` accumulates intermediate spec/plan/task commits that aren't individually "release-ready"; only explicit `v*` tags mark a safe update target.
- `scripts/vibe-update.sh` **must never auto-merge a diverged local copy** — if the local repo's HEAD is neither an ancestor of the latest tag nor the tag itself an ancestor of HEAD, it exits nonzero with a clear manual-resolution message and touches nothing.
- Both new scripts accept an optional trailing `DIR` argument (default `.`), matching `scripts/version-sync.sh`'s existing convention — this is what makes them testable against synthetic tmp-dir fixtures without operating on the real repo.
- `scripts/release.sh` resolves `scripts/version-sync.sh`'s path via `${BASH_SOURCE[0]}`'s directory (not a hardcoded relative path assumption about the caller's cwd), so it correctly invokes the *real* sibling script even when its own `DIR` argument points at a synthetic test fixture.
- Commit ticket key for this plan's own commits: `VIB-11` (per this repo's `.githooks/commit-msg` convention, `^[A-Z]{3}-[0-9]{1,4} `).
- Test runner: `bash tests/run.sh` from repo root — auto-discovers every `tests/*_test.sh`.
- Current `.claude-plugin/plugin.json` version at time of writing: `0.2.0` (verify before editing anything — this plan's tasks only touch scripts/docs, not this file itself).

---

### Task 1: `scripts/release.sh` + test

**Files:**
- Create: `scripts/release.sh`
- Test: `tests/release_test.sh` (new)

**Interfaces:**
- Consumes: `scripts/version-sync.sh [DIR]` (already exists, unchanged) — `release.sh` shells out to it after writing the new version into `plugin.json`.
- Produces: `bash scripts/release.sh [major|minor|patch] [DIR]` — a CLI script. If the bump-type argument is omitted, it prompts interactively via `read -rp`. `DIR` defaults to `.`. No other task consumes this programmatically; Task 2 (`RELEASE.md`) documents it, Task 4 (`CLAUDE.md`) references it.

- [ ] **Step 1: Write the failing test**

Create `tests/release_test.sh`:

```bash
#!/usr/bin/env bash
# scripts/release.sh testi — bump hesabi (major/minor/patch), plugin.json yazma, version-sync.sh
# cagrisi ile propagation, commit/tag ATMAMA. Bagimsiz (dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE="$ROOT/scripts/release.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

fresh() {  # $1 = alt-dizin adi, $2 = baslangic versiyonu
  local d="$tmp/$1"
  mkdir -p "$d/.claude-plugin" "$d/.cursor-plugin"
  cat > "$d/.claude-plugin/plugin.json" <<EOF
{
  "name": "vibe-setup",
  "version": "$2",
  "description": "test"
}
EOF
  cat > "$d/.claude-plugin/marketplace.json" <<EOF
{
  "name": "vibe-setup",
  "metadata": {
    "description": "vibe-setup — Claude Code plugins",
    "version": "$2"
  },
  "plugins": [
    {
      "name": "vibe-setup",
      "version": "$2"
    }
  ]
}
EOF
  cat > "$d/.cursor-plugin/plugin.json" <<EOF
{
  "name": "vibe-setup",
  "version": "$2",
  "description": "test"
}
EOF
  echo "$d"
}

# 1. patch bump
d="$(fresh patch-case 1.2.3)"
bash "$RELEASE" patch "$d" >/dev/null 2>&1
grep -q '"version": "1.2.4"' "$d/.claude-plugin/plugin.json" && ok "patch: plugin.json 1.2.3 -> 1.2.4" || bad "patch bump yanlis"
grep -q '"version": "1.2.4"' "$d/.cursor-plugin/plugin.json" && ok "patch: cursor-plugin.json yayildi" || bad "patch: cursor-plugin.json yayilmadi"

# 2. minor bump (patch sifirlanmali)
d="$(fresh minor-case 1.2.3)"
bash "$RELEASE" minor "$d" >/dev/null 2>&1
grep -q '"version": "1.3.0"' "$d/.claude-plugin/plugin.json" && ok "minor: 1.2.3 -> 1.3.0 (patch sifirlandi)" || bad "minor bump yanlis"

# 3. major bump (minor+patch sifirlanmali)
d="$(fresh major-case 1.2.3)"
bash "$RELEASE" major "$d" >/dev/null 2>&1
grep -q '"version": "2.0.0"' "$d/.claude-plugin/plugin.json" && ok "major: 1.2.3 -> 2.0.0 (minor+patch sifirlandi)" || bad "major bump yanlis"

# 4. marketplace.json'un IKI occurrence'i da guncellenmis
d="$(fresh marketplace-case 0.5.0)"
bash "$RELEASE" patch "$d" >/dev/null 2>&1
[ "$(grep -c '"version": "0.5.1"' "$d/.claude-plugin/marketplace.json")" = "2" ] && ok "marketplace.json her iki alan da guncellendi" || bad "marketplace.json guncellemesi eksik"

# 5. gecersiz bump tipi -> nonzero exit, hicbir sey degismez
d="$(fresh invalid-case 1.0.0)"
out="$(bash "$RELEASE" nonsense "$d" 2>&1)"; code=$?
[ "$code" -ne 0 ] && ok "gecersiz bump tipi nonzero exit" || bad "gecersiz bump tipi exit 0 (hata vermeliydi)"
grep -q '"version": "1.0.0"' "$d/.claude-plugin/plugin.json" && ok "gecersiz bump'ta plugin.json degismedi" || bad "gecersiz bump'ta plugin.json bozuldu"

# 6. commit/tag ATILMADI (gercek git repo kurup kontrol et)
if command -v git >/dev/null 2>&1; then
  d="$tmp/git-case"; mkdir -p "$d/.claude-plugin" "$d/.cursor-plugin"
  git -C "$d" init -q
  cat > "$d/.claude-plugin/plugin.json" <<'EOF'
{ "name": "vibe-setup", "version": "1.0.0", "description": "test" }
EOF
  cp "$d/.claude-plugin/plugin.json" "$d/.claude-plugin/marketplace.json"
  cp "$d/.claude-plugin/plugin.json" "$d/.cursor-plugin/plugin.json"
  git -C "$d" add -A && git -C "$d" -c user.email=t@t.com -c user.name=t commit -q -m "baseline"
  before_head="$(git -C "$d" rev-parse HEAD)"
  bash "$RELEASE" patch "$d" >/dev/null 2>&1
  after_head="$(git -C "$d" rev-parse HEAD)"
  [ "$before_head" = "$after_head" ] && ok "release.sh commit atmadi (HEAD degismedi)" || bad "release.sh yanlislikla commit atti"
  [ -z "$(git -C "$d" tag --list)" ] && ok "release.sh tag atmadi" || bad "release.sh yanlislikla tag atti"
else
  echo "  skip: git yok — commit/tag-atmama testi atlandi"
fi

echo "release_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

Make it executable-equivalent (matches sibling test files):

```bash
chmod +x tests/release_test.sh
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `bash tests/release_test.sh`
Expected: FAIL — `scripts/release.sh` doesn't exist yet, so every `bash "$RELEASE" ...` call errors with "No such file or directory" and every assertion that depends on its output fails.

- [ ] **Step 3: Implement `scripts/release.sh`**

Create `scripts/release.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# scripts/release.sh [major|minor|patch] [DIR] — yeni surumu hesaplar, .claude-plugin/plugin.json'a
# yazar, scripts/version-sync.sh ile marketplace.json + .cursor-plugin/plugin.json'a yayar.
# Commit/tag ATMAZ — bkz RELEASE.md (ticket-key secimi insan/LLM karari, script'in degil).
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUMP="${1:-}"
DIR="${2:-.}"

if [ -z "$BUMP" ]; then
  read -rp "Bump tipi (major/minor/patch): " BUMP
fi
case "$BUMP" in
  major|minor|patch) ;;
  *) echo "gecersiz bump tipi: '$BUMP' (major|minor|patch olmali)" >&2; exit 1 ;;
esac

cd "$DIR"
PLUGIN_JSON=.claude-plugin/plugin.json
if [ ! -f "$PLUGIN_JSON" ]; then
  echo "kullanim: release.sh [major|minor|patch] [DIR] ($PLUGIN_JSON bulunamadi)" >&2
  exit 1
fi

CURRENT="$(grep -m1 -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$PLUGIN_JSON" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
if [ -z "$CURRENT" ]; then
  echo "$PLUGIN_JSON icinde \"version\" bulunamadi" >&2
  exit 1
fi

IFS='.' read -r major minor patch <<< "$CURRENT"
case "$BUMP" in
  major) major=$((major+1)); minor=0; patch=0 ;;
  minor) minor=$((minor+1)); patch=0 ;;
  patch) patch=$((patch+1)) ;;
esac
NEW="$major.$minor.$patch"

awk -v v="$NEW" '{ gsub(/"version"[[:space:]]*:[[:space:]]*"[^"]+"/, "\"version\": \"" v "\""); print }' "$PLUGIN_JSON" > "$PLUGIN_JSON.tmp" && mv "$PLUGIN_JSON.tmp" "$PLUGIN_JSON"

echo "Surum: $CURRENT -> $NEW ($BUMP)"
bash "$SELF_DIR/version-sync.sh" "$(pwd)"

echo
echo "Dosyalar hazir (commit/tag ATILMADI). Sonraki adimlar icin: RELEASE.md"
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `bash tests/release_test.sh`
Expected: `release_test: N passed, 0 failed`, no `FAIL` lines.

- [ ] **Step 5: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 6: Commit**

```bash
git add scripts/release.sh tests/release_test.sh
git commit -m "$(cat <<'EOF'
VIB-11 scripts/release.sh ekle: surum hesapla+yay, commit/tag atma

Bump tipi (major/minor/patch) argumandan ya da interaktif sorularak
alinir. plugin.json'daki version'u hesaplar+yazar, mevcut
version-sync.sh'i cagirarak diger iki manifeste yayar. Commit/tag
atmaz — ticket-key secimi insan/LLM karari (RELEASE.md'de belgeli).
EOF
)"
```

---

### Task 2: `RELEASE.md`

**Files:**
- Create: `RELEASE.md` (repo root)

**Interfaces:**
- Consumes: `scripts/release.sh` (Task 1) and `scripts/vibe-update.sh` (Task 3) by name/invocation only — this is documentation, no code dependency in either direction. (Task order in this plan puts this before Task 3 for narrative flow, but nothing here breaks if read before Task 3 exists — the doc just describes both scripts.)
- Produces: nothing consumed by other tasks — Task 4 (`CLAUDE.md`) links to this file by name.

- [ ] **Step 1: Create `RELEASE.md`**

Create `RELEASE.md` with exactly this content:

```markdown
# Release süreci

vibe-setup'ın paket versiyonu (`.claude-plugin/plugin.json` / `marketplace.json` /
`.cursor-plugin/plugin.json`'daki `"version"`) elle, aşağıdaki adımlarla çıkarılır. Bu,
`scaffold.sh`'ın kendi `VIBE_VERSION`'ından (hedef repolara üretilen dosya şemasının sürümü)
TAMAMEN AYRI bir kavramdır — bkz `CLAUDE.md` Gotchas.

## Adımlar

1. **Bump tipine karar ver** — semver kuralı:
   - `patch`: geriye uyumlu bug fix / küçük dokümantasyon düzeltmesi.
   - `minor`: geriye uyumlu yeni özellik (ör. yeni bir `scaffold.sh` komutu).
   - `major`: geriye uyumsuz değişiklik (ör. mevcut bir komutun davranışı/argümanları değişti).

2. **Sürümü hesapla + yay:**
   ```bash
   bash scripts/release.sh <major|minor|patch>
   ```
   Argüman vermezsen interaktif sorar. Bu, `.claude-plugin/plugin.json`'ı günceller ve
   `scripts/version-sync.sh` ile `marketplace.json` + `.cursor-plugin/plugin.json`'a yayar.
   **Commit ya da tag atmaz** — sıradaki adımlar senin elinde.

3. **Değişikliği gözden geçir:**
   ```bash
   git diff .claude-plugin/ .cursor-plugin/
   ```

4. **Commit at** (bu repo `VIB-N` ticket-key formatı zorunlu kılıyor — `.githooks/commit-msg`):
   ```bash
   git add .claude-plugin/ .cursor-plugin/
   git commit -m "VIB-N vX.Y.Z sürümü"
   ```

5. **Tag at** (commit'ten SONRA — tag, versiyon-bump commit'ini işaret etmeli):
   ```bash
   git tag vX.Y.Z
   ```

6. **Push et:**
   ```bash
   git push && git push --tags
   ```

## Self-update (tüketici tarafı)

vibe-setup'ın kurulu bir kopyasını (git clone / Claude marketplace cache / Cursor plugin symlink)
en son tag'e güncellemek için:
```bash
bash scripts/vibe-update.sh
```
Bu, **branch-HEAD'e değil git tag'e** göre çalışır — bu repo'nun `main`'i sürekli ara-commit
aldığından (spec/plan/task commit'leri), sadece maintainer'ın açıkça taglediği noktalara güncellenir.
Yerel kopya elle değiştirilmişse (sapmışsa) asla otomatik merge etmez — hata verir, elle çözmeni ister.
```

- [ ] **Step 2: Verify it was created correctly**

Run: `head -5 RELEASE.md`
Expected: `# Release süreci` followed by the intro paragraph, printing cleanly with no errors.

- [ ] **Step 3: Run the full suite as a sanity check**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED` (documentation-only addition, but confirms nothing else broke).

- [ ] **Step 4: Commit**

```bash
git add RELEASE.md
git commit -m "$(cat <<'EOF'
VIB-11 RELEASE.md ekle: tam release + self-update sureci

Bump karari -> release.sh -> gozden gecir -> commit (VIB-N) -> tag ->
push. Tuketici tarafi: vibe-update.sh ile en son tag'e guncelleme.
EOF
)"
```

---

### Task 3: `scripts/vibe-update.sh` + test

**Files:**
- Create: `scripts/vibe-update.sh`
- Test: `tests/vibe_update_test.sh` (new)

**Interfaces:**
- Consumes: nothing from other tasks — pure git operations against whatever `DIR` (default `.`) points at.
- Produces: `bash scripts/vibe-update.sh [DIR]` — a CLI script. No other task consumes this programmatically; Task 2's `RELEASE.md` (already written) documents it, Task 4 (`CLAUDE.md`) references it.

The test uses `git clone` from a local-path "origin" repo (no real network) to exercise fetch/tag-compare/merge behavior deterministically.

- [ ] **Step 1: Write the failing test**

Create `tests/vibe_update_test.sh`:

```bash
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
```

Make it executable-equivalent:

```bash
chmod +x tests/vibe_update_test.sh
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `bash tests/vibe_update_test.sh`
Expected: FAIL — `scripts/vibe-update.sh` doesn't exist yet, so every invocation errors and every assertion depending on its output/exit-code fails.

- [ ] **Step 3: Implement `scripts/vibe-update.sh`**

Create `scripts/vibe-update.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# scripts/vibe-update.sh [DIR] — vibe-setup'in KENDI kurulu kopyasini (git clone / Claude marketplace
# cache / Cursor plugin symlink) en son git TAG'e gunceller (self-update). scaffold.sh upgrade'den
# TAMAMEN AYRI: o hedef repolarin scaffold dosyalarini gunceller (VIBE_VERSION), bu ise ARACIN KENDI
# repo kopyasini (git tag). Branch-HEAD DEGIL tag kullanir: main surekli ara-commit alir
# (spec/plan/task commit'leri), tag ise maintainer'in acikca "bu nokta saglam" dedigi an.
set -euo pipefail
DIR="${1:-.}"
cd "$DIR"

if [ ! -d .git ]; then
  echo "Bu vibe-setup kopyasi bir git repo degil — self-update yapilamaz." >&2
  exit 1
fi

if ! git fetch origin --tags --quiet 2>/dev/null; then
  echo "git fetch basarisiz (ag/remote sorunu?)" >&2
  exit 1
fi

LATEST_TAG="$(git tag --list 'v*' --sort=-version:refname | head -1)"
if [ -z "$LATEST_TAG" ]; then
  echo "Hic tag bulunamadi — self-update icin en az bir 'vX.Y.Z' tag'i gerekli." >&2
  exit 1
fi

LOCAL="$(git rev-parse HEAD)"
TARGET="$(git rev-parse "$LATEST_TAG")"

if [ "$LOCAL" = "$TARGET" ]; then
  echo "Guncel: zaten $LATEST_TAG'desiniz."
  exit 0
fi

if git merge-base --is-ancestor "$TARGET" "$LOCAL"; then
  echo "Kurulu kopya zaten $LATEST_TAG'den daha yeni (henuz taglenmemis local commit'ler icerebilir)."
  exit 0
fi

if ! git merge-base --is-ancestor "$LOCAL" "$TARGET"; then
  echo "Yerel kopya $LATEST_TAG'den SAPMIS (elle degistirilmis olabilir) — otomatik guncelleme GUVENLI DEGIL." >&2
  echo "Elle coz: git status / git diff / gerekirse yedekleyip yeniden klonlayin." >&2
  exit 1
fi

echo "Yeni surum: $LATEST_TAG"
git log --oneline "$LOCAL..$TARGET"
echo
git merge --ff-only "$LATEST_TAG"
echo "Guncellendi: $LATEST_TAG"
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `bash tests/vibe_update_test.sh`
Expected: `vibe_update_test: N passed, 0 failed`, no `FAIL` lines.

- [ ] **Step 5: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 6: Commit**

```bash
git add scripts/vibe-update.sh tests/vibe_update_test.sh
git commit -m "$(cat <<'EOF'
VIB-11 scripts/vibe-update.sh ekle: tag-tabanli self-update

Branch-HEAD degil git tag bazli (bu repo'nun main'i surekli ara-commit
alir). Zaten guncelse no-op; ff-safe ise gunceller; yerel kopya
sapmissa (elle degistirilmisse) ASLA otomatik merge etmez, hata verir.
EOF
)"
```

---

### Task 4: `CLAUDE.md` — document both commands + link `RELEASE.md`

**Files:**
- Modify: `CLAUDE.md` (the `## Komutlar` section and the `## Gotchas` section)

**Interfaces:**
- Consumes: `scripts/release.sh` (Task 1), `scripts/vibe-update.sh` (Task 3), `RELEASE.md` (Task 2) — by name only, documentation.
- Produces: nothing consumed elsewhere — final task in this plan.

- [ ] **Step 1: Add the two command lines**

In `CLAUDE.md`, find:

```markdown
- Versiyon senkron: `bash scripts/version-sync.sh` — `.claude-plugin/plugin.json`'daki `"version"`'ı
  `marketplace.json` + `.cursor-plugin/plugin.json`'a yayar (release'te elle çalıştır).
- Lint (ops): `shellcheck skills/vibe-setup/scaffold.sh` — kurulu değilse atla
```

Replace with:

```markdown
- Versiyon senkron: `bash scripts/version-sync.sh` — `.claude-plugin/plugin.json`'daki `"version"`'ı
  `marketplace.json` + `.cursor-plugin/plugin.json`'a yayar (release'te elle çalıştır).
- Release çıkar: `bash scripts/release.sh <major|minor|patch>` — sürümü hesaplar + yayar (commit/tag
  atmaz); tam süreç: `RELEASE.md`.
- Self-update (tüketici tarafı): `bash scripts/vibe-update.sh` — kurulu kopyayı en son git tag'e
  günceller (branch-HEAD değil; sapma varsa asla otomatik merge etmez).
- Lint (ops): `shellcheck skills/vibe-setup/scaffold.sh` — kurulu değilse atla
```

- [ ] **Step 2: Extend the "Paket versiyonu ≠ VIBE_VERSION" gotcha with a `RELEASE.md` pointer**

In `CLAUDE.md`, find:

```markdown
- **Paket versiyonu ≠ `VIBE_VERSION`.** `.claude-plugin/plugin.json` / `marketplace.json` /
  `.cursor-plugin/plugin.json`'daki `"version"` bu PLUGIN'in kendi sürümü — `scripts/version-sync.sh`
  ile senkron tutulur, `plugin.json` tek kaynak. `scaffold.sh`'taki `VIBE_VERSION` TAMAMEN AYRI bir
  kavram: scaffold.sh'ın hedef repolara ÜRETTİĞİ dosya şemasının sürümü (upgrade'in drift tespiti
  için). Biri artınca diğeri otomatik artmaz — ikisini karıştırma.

## Git workflow
```

Replace with:

```markdown
- **Paket versiyonu ≠ `VIBE_VERSION`.** `.claude-plugin/plugin.json` / `marketplace.json` /
  `.cursor-plugin/plugin.json`'daki `"version"` bu PLUGIN'in kendi sürümü — `scripts/version-sync.sh`
  ile senkron tutulur, `plugin.json` tek kaynak. `scaffold.sh`'taki `VIBE_VERSION` TAMAMEN AYRI bir
  kavram: scaffold.sh'ın hedef repolara ÜRETTİĞİ dosya şemasının sürümü (upgrade'in drift tespiti
  için). Biri artınca diğeri otomatik artmaz — ikisini karıştırma. Release çıkarma + self-update tam
  süreci: `RELEASE.md`. `scripts/vibe-update.sh` de bu ayrımı miras alır — `scaffold.sh upgrade`
  (hedef repo, VIBE_VERSION) değil, git TAG bazlı (bu repo'nun kendi kopyası) çalışır.

## Git workflow
```

- [ ] **Step 3: Verify both edits**

Run: `grep -n "release.sh\|vibe-update.sh\|RELEASE.md" CLAUDE.md`
Expected: at least 5 matching lines (two in the Komutlar block, at least three references — `release.sh`, `vibe-update.sh`, `RELEASE.md` — spread across the Komutlar and Gotchas sections).

- [ ] **Step 4: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
VIB-11 CLAUDE.md: release.sh + vibe-update.sh komutlari + RELEASE.md linki

Komutlar'a iki yeni satir eklendi. Mevcut "Paket versiyonu != VIBE_VERSION"
gotcha'sina RELEASE.md pointer'i + vibe-update.sh'in ayni ayrimi miras
aldigi notu eklendi.
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:** every kapsam kararı in the spec (`release.sh`'s bump-arg-or-prompt interface, semver computation with correct component-reset rules, no commit/no tag, calling the existing `version-sync.sh`; `RELEASE.md`'s full step list including the self-update pointer; `vibe-update.sh`'s tag-based comparison, ff-only safety, divergence refusal, no-`.git` handling; `CLAUDE.md`'s command lines + gotcha pointer) has a corresponding task/step. The spec's "kapsam dışı" exclusions (no automatic commit/tag/push, no SKILL.md/audit integration, no CI pipeline) are honored by construction — no task does any of those things.

**Placeholder scan:** no TBD/TODO; every step shows complete file content or exact find/replace text.

**Type/name consistency:** `scripts/release.sh [major|minor|patch] [DIR]` (Task 1) and `scripts/vibe-update.sh [DIR]` (Task 3) both follow the exact `[DIR]`-defaults-to-`.` convention already established by `scripts/version-sync.sh` (merged in a prior plan) — Task 1's `release.sh` explicitly shells out to `scripts/version-sync.sh` using the same argument convention it consumes. `RELEASE.md` (Task 2) references both scripts by their exact final names/invocations, matching what Tasks 1 and 3 actually create. `CLAUDE.md` (Task 4) references all three by the same names.
