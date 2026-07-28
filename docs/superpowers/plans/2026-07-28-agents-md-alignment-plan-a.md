# AGENTS.md Alignment — Plan A (init-aider + docs + legacy migration) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close 3 of the 4 gaps found against the official AGENTS.md standard: add Aider support (`init-aider`), expand the "which tools already work" documentation, and auto-migrate a legacy singular `AGENT.md` into the standard `AGENTS.md` (+ back-compat symlink) without ever risking its deletion.

**Architecture:** Two small, independent additions to `scaffold.sh`'s deterministic engine — `init_aider()` (mirrors the existing `init_cursor()`/`init_gemini()` pattern exactly: an opt-in adapter file via `write_extra`, never overwritten) and `migrate_legacy_agent_md()` (a narrow interceptor inside `init()`'s `AGENTS.md` handling) — followed by one bundled documentation task touching `CLAUDE.md`, `README.md`, and `SKILL.md` once both mechanisms exist to document accurately.

**Tech Stack:** Pure bash (matches `scaffold.sh`'s existing style exactly — no new dependencies, no `sed -i`, `awk`/`mv` idiom not needed here since this task only adds `mv`+`ln -s`+heredocs). Bash test harness (`tests/*_test.sh`, auto-discovered by `tests/run.sh`).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-28-agents-md-alignment-design.md` (Madde 2, 3, 4 — Madde 1/init-nested is explicitly OUT of this plan, it gets its own separate plan later).
- `.aider.conf.yml` is `extra_paths()` class, same as `.cursorrules`/`GEMINI.md`: never added to `managed_paths()`, no drift/upgrade tracking, no audit row, dropped via `write_extra` which never overwrites an existing file.
- The legacy-migration path (`migrate_legacy_agent_md`) must add the migrated `AGENTS.md` path to `WRITTEN_PATHS` (so its `sha` refreshes in the manifest) but **must NOT** add it to `NEW_PATHS` (so `created_for_manifest` reports `false`) — this is the exact provenance rule that keeps `remove --apply` from ever deleting real user content, per the `WRITTEN_PATHS`/`NEW_PATHS` split already documented in `CLAUDE.md`'s "`.vibe-setup.json` jq-suz" gotcha and enforced everywhere else in this codebase (fixed for real in VIB-7, reinforced in VIB-9).
- No `sed -i` anywhere (BSD/GNU incompatibility) — not needed for this plan's changes, but don't introduce any.
- All new user-facing script output (`echo` messages) is Turkish, matching every existing message in `scaffold.sh`.
- Test runner: `bash tests/run.sh` from repo root — auto-discovers every `tests/*_test.sh`; no test-file registration needed.
- Commit ticket key: `VIB-12` (this repo's `.githooks/commit-msg` enforces `^[A-Z]{3}-[0-9]{1,4} `).
- Task order matters: Task 3 (documentation) is written last because it needs to accurately describe both `init-aider` and the legacy-migration behavior, which must exist first.

---

### Task 1: `init-aider` command

**Files:**
- Modify: `skills/vibe-setup/scaffold.sh` (header comment, `extra_paths()`, new `init_aider()` function, `case "$CMD"` statement)
- Test: `tests/init_aider_test.sh` (new)

**Interfaces:**
- Consumes: existing `write_extra()` (unchanged — `$1` = path, content on stdin, never overwrites, appends to `NEW_PATHS`/`WRITTEN_PATHS`, prints `NEW`/`SKIP`) and `write_manifest()` (unchanged).
- Produces: `scaffold.sh init-aider [DIR]` CLI command. `.aider.conf.yml` added to `extra_paths()`'s output — Task 3's documentation references this by name; no other task consumes `init_aider()` programmatically.

- [ ] **Step 1: Write the failing test**

Create `tests/init_aider_test.sh`:

```bash
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
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `bash tests/init_aider_test.sh`
Expected: FAIL — `init-aider` isn't a recognized command yet, so `scaffold.sh` hits its `*)` usage-error branch, exits 2, no `.aider.conf.yml` is written, and every assertion depending on it fails.

- [ ] **Step 3: Add `init-aider` to the header comment**

In `skills/vibe-setup/scaffold.sh`, find:

```bash
#   scaffold.sh init-gemini [DIR] → drop Gemini CLI context file (GEMINI.md → @CLAUDE.md import)
#   scaffold.sh upgrade [DIR]     → re-apply changed managed templates to an already-set-up repo
```

Replace with:

```bash
#   scaffold.sh init-gemini [DIR] → drop Gemini CLI context file (GEMINI.md → @CLAUDE.md import)
#   scaffold.sh init-aider [DIR]  → drop Aider config (.aider.conf.yml → read: AGENTS.md)
#   scaffold.sh upgrade [DIR]     → re-apply changed managed templates to an already-set-up repo
```

- [ ] **Step 4: Add `.aider.conf.yml` to `extra_paths()`**

Find:

```bash
extra_paths() {
  printf '%s\n' .cursor/rules/project.mdc .cursorrules GEMINI.md
}
```

Replace with:

```bash
extra_paths() {
  printf '%s\n' .cursor/rules/project.mdc .cursorrules GEMINI.md .aider.conf.yml
}
```

- [ ] **Step 5: Add `init_aider()` function**

Find:

```bash
init_gemini() {
  echo "vibe-setup init-gemini — $(pwd)"
  write_extra GEMINI.md <<'EOF'
# Gemini CLI context — tek doğruluk kaynağı CLAUDE.md
@CLAUDE.md
EOF
  write_manifest
}

# ---------------------------------------------------------------- remove (dry-run varsayılan; --apply gerçek siler)
```

Replace with:

```bash
init_gemini() {
  echo "vibe-setup init-gemini — $(pwd)"
  write_extra GEMINI.md <<'EOF'
# Gemini CLI context — tek doğruluk kaynağı CLAUDE.md
@CLAUDE.md
EOF
  write_manifest
}

init_aider() {
  echo "vibe-setup init-aider — $(pwd)"
  write_extra .aider.conf.yml <<'EOF'
# vibe-setup — Aider AGENTS.md'yi native okumaz; acikca isaretle.
read: AGENTS.md
EOF
  write_manifest
}

# ---------------------------------------------------------------- remove (dry-run varsayılan; --apply gerçek siler)
```

- [ ] **Step 6: Wire `init-aider` into the command dispatcher**

Find:

```bash
case "$CMD" in
  audit)   audit ;;
  init)    init ;;
  init-cursor) init_cursor ;;
  init-gemini) init_gemini ;;
  upgrade) upgrade ;;
  remove)  remove ;;
  profile) printf 'STACK=%s\nMODULE_DIR=%s\nFMT=%s\nLINT=%s\nTEST=%s\nBUILD=%s\nSRC_RE=%s\nTEST_FIND=%s\nFMT_FILE_OK=%s\nVIBE_VERSION=%s\n' "$STACK" "$MODULE_DIR" "$FMT" "$LINT" "$TEST" "$BUILD" "$SRC_RE" "$TEST_FIND" "$FMT_FILE_OK" "$VIBE_VERSION" ;;
  *) echo "kullanım: scaffold.sh {audit|init|init-cursor|init-gemini|upgrade|remove|profile} [DIR] [--apply]" >&2; exit 2 ;;
esac
```

Replace with:

```bash
case "$CMD" in
  audit)   audit ;;
  init)    init ;;
  init-cursor) init_cursor ;;
  init-gemini) init_gemini ;;
  init-aider) init_aider ;;
  upgrade) upgrade ;;
  remove)  remove ;;
  profile) printf 'STACK=%s\nMODULE_DIR=%s\nFMT=%s\nLINT=%s\nTEST=%s\nBUILD=%s\nSRC_RE=%s\nTEST_FIND=%s\nFMT_FILE_OK=%s\nVIBE_VERSION=%s\n' "$STACK" "$MODULE_DIR" "$FMT" "$LINT" "$TEST" "$BUILD" "$SRC_RE" "$TEST_FIND" "$FMT_FILE_OK" "$VIBE_VERSION" ;;
  *) echo "kullanım: scaffold.sh {audit|init|init-cursor|init-gemini|init-aider|upgrade|remove|profile} [DIR] [--apply]" >&2; exit 2 ;;
esac
```

- [ ] **Step 7: Run the test to confirm it passes**

Run: `bash tests/init_aider_test.sh`
Expected: `init_aider_test: 9 passed, 0 failed`, no `FAIL` lines.

- [ ] **Step 8: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 9: Commit**

```bash
git add skills/vibe-setup/scaffold.sh tests/init_aider_test.sh
git commit -m "$(cat <<'EOF'
VIB-12 scaffold.sh: init-aider komutu ekle (.aider.conf.yml)

Aider AGENTS.md'yi native okumaz; .aider.conf.yml icine `read:
AGENTS.md` dusurur. init-cursor/init-gemini ile ayni kalip:
write_extra (asla ezmez), extra_paths'e ekli (managed_paths'e girmez,
drift takibi yok).
EOF
)"
```

---

### Task 2: Legacy singular `AGENT.md` → `AGENTS.md` migration

**Files:**
- Modify: `skills/vibe-setup/scaffold.sh` (`audit()`'s `AGENTS.md` row, new `migrate_legacy_agent_md()` function, `init()`'s managed-paths loop)
- Test: `tests/agent_migration_test.sh` (new)

**Interfaces:**
- Consumes: existing `WRITTEN_PATHS` global (string, space-separated paths — appending to it is the exact mechanism `write_managed()`/`write_extra()` already use to mark "this run touched this path" for `sha_for_manifest()`/`v_for_manifest()`), existing `NEW_PATHS` global (same shape, drives `created_for_manifest()`), existing `managed_paths()` (unchanged, still yields `AGENTS.md` among others).
- Produces: `migrate_legacy_agent_md()` — no args, returns 0 (migration happened) or 1 (nothing to migrate) via exit status; on success leaves `AGENTS.md` as a real file (former `AGENT.md` content) and `AGENT.md` as a symlink to it. `init()`'s loop is the only caller; no other task calls this function directly.

- [ ] **Step 1: Write the failing test**

Create `tests/agent_migration_test.sh`:

```bash
#!/usr/bin/env bash
# scaffold.sh legacy AGENT.md -> AGENTS.md migrasyon testi. Bagimsiz (dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD="$ROOT/skills/vibe-setup/scaffold.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

# 1. AGENT.md (tekil) var, AGENTS.md yok -> audit bunu tespit etsin (init'ten ONCE bile)
work="$tmp/repo"; mkdir -p "$work"
printf '# Benim eski agent notlarim\nBu icerik onemli, kaybolmamali.\n' > "$work/AGENT.md"
audit_out="$(bash "$SCAFFOLD" audit "$work" 2>&1)"
printf '%s' "$audit_out" | grep -qi 'legacy AGENT.md' && ok "audit: legacy AGENT.md tespiti (init'ten once)" || bad "audit: legacy tespiti yok"

# 2. init calistir -> migrate etmeli: AGENTS.md icerik tasinir, AGENT.md symlink olur
init_out="$(bash "$SCAFFOLD" init "$work" 2>&1)"
printf '%s' "$init_out" | grep -q 'MIGRATE' && ok "init: MIGRATE mesaji basildi" || bad "init: MIGRATE mesaji yok"
[ -f "$work/AGENTS.md" ] && ok "AGENTS.md olustu" || bad "AGENTS.md yok"
grep -q 'Benim eski agent notlarim' "$work/AGENTS.md" && ok "eski icerik korundu (tasindi, sablonla EZILMEDI)" || bad "icerik kayboldu/ezildi"
[ -L "$work/AGENT.md" ] && ok "AGENT.md simdi symlink" || bad "AGENT.md symlink degil"
[ "$(readlink "$work/AGENT.md")" = "AGENTS.md" ] && ok "symlink AGENTS.md'yi gosteriyor" || bad "symlink hedefi yanlis"

# 3. manifest: AGENTS.md created:false olarak kayitli (vibe-setup'in urettigi icerik DEGIL)
grep -q '"AGENTS.md": { "v": [0-9]*, "sha": "[0-9]*", "created": false' "$work/.vibe-setup.json" 2>/dev/null \
  && ok "manifest: AGENTS.md created:false" || bad "manifest: AGENTS.md created:false degil (VERI KAYBI RISKI)"

# 4. KRITIK guvenlik testi: remove --apply migrasyonla gelen AGENTS.md'yi ASLA silmemeli
bash "$SCAFFOLD" remove "$work" --apply >/dev/null 2>&1
[ -f "$work/AGENTS.md" ] && ok "remove --apply: migrasyonla gelen AGENTS.md SILINMEDI" || bad "remove --apply: AGENTS.md SILINDI — VERI KAYBI, created:false ihlali"
grep -q 'Benim eski agent notlarim' "$work/AGENTS.md" 2>/dev/null && ok "remove sonrasi icerik hala duruyor" || bad "remove sonrasi icerik kayip"

# 5. sanity: legacy AGENT.md YOKSA normal davranis degismemis (AGENTS.md sablonla dusuyor, created:true)
normal="$tmp/normal-repo"; mkdir -p "$normal"
bash "$SCAFFOLD" init "$normal" >/dev/null 2>&1
grep -q '"AGENTS.md": { "v": [0-9]*, "sha": "[0-9]*", "created": true' "$normal/.vibe-setup.json" 2>/dev/null \
  && ok "sanity: legacy yokken AGENTS.md hala created:true" || bad "sanity: normal init davranisi bozuldu"

echo "agent_migration_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `bash tests/agent_migration_test.sh`
Expected: FAIL — `audit()` doesn't detect legacy `AGENT.md` yet (no "legacy AGENT.md" string anywhere), and `init()` renders a fresh empty `AGENTS.md` template instead of migrating (overwriting nothing since `AGENTS.md` doesn't exist yet, but the ORIGINAL `AGENT.md` content is never moved in, and `AGENT.md` stays a plain file, not a symlink) — so most assertions fail.

- [ ] **Step 3: Add legacy detection to `audit()`**

Find:

```bash
  echo "BAĞLAM"
  has_file CLAUDE.md   && row "$OK" "CLAUDE.md" || row "$NO" "CLAUDE.md" "LLM: oluştur (komut+mimari+gotchas)"
  has_file AGENTS.md   && row "$OK" "AGENTS.md" || row "$NO" "AGENTS.md" "init düşürür"
  has_file llms.txt    && row "$OK" "llms.txt (ops)" || row "$NA" "llms.txt (ops)" "opsiyonel: dış LLM tüketicisi varsa"
```

Replace with:

```bash
  echo "BAĞLAM"
  has_file CLAUDE.md   && row "$OK" "CLAUDE.md" || row "$NO" "CLAUDE.md" "LLM: oluştur (komut+mimari+gotchas)"
  if has_file AGENTS.md; then row "$OK" "AGENTS.md"
  elif has_file AGENT.md; then row "$NO" "AGENTS.md" "legacy AGENT.md bulundu — init migrate eder (mv+symlink)"
  else row "$NO" "AGENTS.md" "init düşürür"; fi
  has_file llms.txt    && row "$OK" "llms.txt (ops)" || row "$NA" "llms.txt (ops)" "opsiyonel: dış LLM tüketicisi varsa"
```

- [ ] **Step 4: Add `migrate_legacy_agent_md()` and wire it into `init()`**

Find:

```bash
write_managed() {  # $1 = managed path
  if [ -e "$1" ]; then echo "  SKIP  $1 (var)"; return; fi
  mkdir -p "$(dirname "$1")"
  render_artifact "$1" > "$1"
  case "$1" in .githooks/*) chmod +x "$1" ;; esac
  NEW_PATHS="$NEW_PATHS $1"
  WRITTEN_PATHS="$WRITTEN_PATHS $1"
  echo "  NEW   $1"
}

init() {
  echo "vibe-setup init — $(pwd)  (stack: $STACK, engine v$VIBE_VERSION)"
  STAMP_VERSION=1
  local p; for p in $(managed_paths); do write_managed "$p"; done
```

Replace with:

```bash
write_managed() {  # $1 = managed path
  if [ -e "$1" ]; then echo "  SKIP  $1 (var)"; return; fi
  mkdir -p "$(dirname "$1")"
  render_artifact "$1" > "$1"
  case "$1" in .githooks/*) chmod +x "$1" ;; esac
  NEW_PATHS="$NEW_PATHS $1"
  WRITTEN_PATHS="$WRITTEN_PATHS $1"
  echo "  NEW   $1"
}

# Resmi AGENTS.md migrasyon tavsiyesi: eski tekil AGENT.md → AGENTS.md + geriye-uyumlu symlink.
# Bu vibe-setup'ın ÜRETTİĞİ içerik DEĞİL (kullanıcının taşınmış içeriği) → NEW_PATHS'e EKLENMEZ,
# böylece created_for_manifest false kalır (remove asla silmeye kalkışmaz). WRITTEN_PATHS'e eklenir
# ki sha güncel kalsın (manifest "bu içerik bu" der, ama "bunu ben ürettim" demez).
migrate_legacy_agent_md() {
  if [ ! -e AGENTS.md ] && [ -e AGENT.md ]; then
    mv AGENT.md AGENTS.md
    ln -s AGENTS.md AGENT.md
    WRITTEN_PATHS="$WRITTEN_PATHS AGENTS.md"
    echo "  MIGRATE AGENTS.md (eski AGENT.md taşındı + geriye-uyumlu symlink bırakıldı)"
    return 0
  fi
  return 1
}

init() {
  echo "vibe-setup init — $(pwd)  (stack: $STACK, engine v$VIBE_VERSION)"
  STAMP_VERSION=1
  local p
  for p in $(managed_paths); do
    if [ "$p" = "AGENTS.md" ] && migrate_legacy_agent_md; then continue; fi
    write_managed "$p"
  done
```

- [ ] **Step 5: Run the test to confirm it passes**

Run: `bash tests/agent_migration_test.sh`
Expected: `agent_migration_test: 9 passed, 0 failed`, no `FAIL` lines. Pay special attention to the Step-4 assertions (`remove --apply` must not delete the migrated `AGENTS.md`) — this is the load-bearing regression test.

- [ ] **Step 6: Add a case to `tests/audit_test.sh` for the new legacy-detection row**

Open `tests/audit_test.sh`. Find the final block before the closing summary:

```bash
# 5. context-mode satırı: makinede kuruluysa ✅, değilse ❌ — hangisi doğruysa onu doğrula
out5="$(bash "$SCAFFOLD" audit "$work" 2>/dev/null)"
if command -v context-mode >/dev/null 2>&1; then
  printf '%s' "$out5" | grep -qE '✅ +context-mode' && ok "context-mode kurulu → ✅ basıyor" || bad "context-mode kurulu ama ✅ basmadı"
else
  printf '%s' "$out5" | grep -qE '❌ +context-mode' && ok "context-mode eksik → ❌ basıyor" || bad "context-mode eksik ama ❌ basmadı"
fi

echo "audit_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

Replace with:

```bash
# 5. context-mode satırı: makinede kuruluysa ✅, değilse ❌ — hangisi doğruysa onu doğrula
out5="$(bash "$SCAFFOLD" audit "$work" 2>/dev/null)"
if command -v context-mode >/dev/null 2>&1; then
  printf '%s' "$out5" | grep -qE '✅ +context-mode' && ok "context-mode kurulu → ✅ basıyor" || bad "context-mode kurulu ama ✅ basmadı"
else
  printf '%s' "$out5" | grep -qE '❌ +context-mode' && ok "context-mode eksik → ❌ basıyor" || bad "context-mode eksik ama ❌ basmadı"
fi

# 6. legacy tekil AGENT.md: ayrı bir tmp repo'da (mevcut $work'e karışmasın) — audit init'ten önce
#    bile bunu tespit etmeli (bkz tests/agent_migration_test.sh — burada sadece audit satırı doğrulanır)
legacy="$tmp/legacy-repo"; mkdir -p "$legacy"
printf 'eski notlar\n' > "$legacy/AGENT.md"
out6="$(bash "$SCAFFOLD" audit "$legacy" 2>/dev/null)"
printf '%s' "$out6" | grep -qi 'legacy AGENT.md' && ok "legacy AGENT.md → audit tespit satırı basıyor" || bad "legacy AGENT.md tespit satırı yok"

echo "audit_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 7: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 8: Commit**

```bash
git add skills/vibe-setup/scaffold.sh tests/agent_migration_test.sh tests/audit_test.sh
git commit -m "$(cat <<'EOF'
VIB-12 scaffold.sh: legacy tekil AGENT.md -> AGENTS.md migrasyonu

Resmi AGENTS.md migrasyon tavsiyesi (mv + geriye-uyumlu symlink).
init() calisirken AGENTS.md yok + AGENT.md varsa template render
ETMEZ, tasir. Kritik: NEW_PATHS'e eklenmez (created:false kalir) ->
remove bunu ASLA silmeye kalkismaz. audit de bunu init'ten once
sinyal verir. Regresyon testi: remove --apply sonrasi icerik hala
duruyor.
EOF
)"
```

---

### Task 3: Documentation — `CLAUDE.md` + `README.md` + `SKILL.md`

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `skills/vibe-setup/SKILL.md`

**Interfaces:**
- Consumes: `init-aider` (Task 1) and the legacy-migration behavior (Task 2) by name/description only — pure documentation, no code dependency.
- Produces: nothing consumed by other tasks — final task in this plan.

- [ ] **Step 1: `CLAUDE.md` — update the file list to mention `init-aider`**

Find:

```markdown
- `skills/vibe-setup/scaffold.sh` — motor (`audit|init|init-cursor|init-gemini|upgrade|remove|profile`)
```

Replace with:

```markdown
- `skills/vibe-setup/scaffold.sh` — motor (`audit|init|init-cursor|init-gemini|init-aider|upgrade|remove|profile`)
```

- [ ] **Step 2: `CLAUDE.md` — expand the "Araç desteği" gotcha and add a new "Legacy tekil AGENT.md" gotcha**

Find:

```markdown
- **Araç desteği:** Codex ve Kimi Code `AGENTS.md`'yi native okur (`init` zaten düşürür, ekstra dosya
  yok). Cursor (`init-cursor`) ve Gemini CLI (`init-gemini` → `GEMINI.md`, `@CLAUDE.md` importu) ayrı
  context dosyası ister — bunlar `managed_paths`'e GİRMEZ (Cursor ile aynı sınıf: bir kez düşer,
  drift/upgrade takibi yok, audit satırı yok). AGENTS.md'nin metni v4'te değişti (Gemini'nin AGENTS.md
  okuduğu yanlış iddiası düzeltildi) → bkz `VIBE_VERSION`.
```

Replace with:

```markdown
- **Araç desteği:** AGENTS.md'yi native okuyan geniş bir ekosistem var — Codex, Kimi Code, Zed, Warp,
  VS Code, Devin, Amp, RooCode, Kilo Code, GitHub Copilot coding agent, Windsurf, Augment Code, goose,
  opencode, Junie, Phoenix, Semgrep, Ona, Factory, Jules — hiçbiri ekstra dosya istemez (`init` zaten
  yeterli). Cursor (`init-cursor`), Gemini CLI (`init-gemini` → `GEMINI.md`, `@CLAUDE.md` importu) ve
  Aider (`init-aider` → `.aider.conf.yml`, `read: AGENTS.md`) ayrı context dosyası ister — bunlar
  `managed_paths`'e GİRMEZ (aynı sınıf: bir kez düşer, drift/upgrade takibi yok, audit satırı yok; var
  olan `.cursorrules`/`GEMINI.md`/`.aider.conf.yml` varsa asla ezilmez). AGENTS.md'nin metni v4'te
  değişti (Gemini'nin AGENTS.md okuduğu yanlış iddiası düzeltildi) → bkz `VIBE_VERSION`.
- **Legacy tekil `AGENT.md`:** `init` çalışırken `AGENTS.md` yok + `AGENT.md` (tekil) varsa, template
  render ETMEZ — `mv AGENT.md AGENTS.md && ln -s AGENTS.md AGENT.md` yapar (resmi AGENTS.md migrasyon
  tavsiyesi). Bu vibe-setup'ın ÜRETTİĞİ içerik DEĞİL — manifestte `created:false` işaretlenir (aynı
  "önceden vardı" sınıfı), yani `remove` bunu ASLA silmeye kalkışmaz (`migrate_legacy_agent_md`
  `NEW_PATHS`'e eklemez, sadece `WRITTEN_PATHS`'e — sha tazelenir ama provenance "ben ürettim" demez).
  `audit` da bunu init'ten önce sinyal verir.
```

- [ ] **Step 3: `README.md` — intro paragraph mentions Aider**

Find:

```markdown
Ne kurar: `CLAUDE.md`, `AGENTS.md`, `docs/` + ADR, test harness, herkesi bağlayan git
pre-commit hook (fmt/lint/doc-sync), `.claude/settings.json` izinleri, commit/PR(MR) şablonları, opsiyonel
Cursor/Gemini CLI kuralları, (ops) `llms.txt` ve tekrar kullanılabilir vibe checklist. context-mode'u
```

Replace with:

```markdown
Ne kurar: `CLAUDE.md`, `AGENTS.md`, `docs/` + ADR, test harness, herkesi bağlayan git
pre-commit hook (fmt/lint/doc-sync), `.claude/settings.json` izinleri, commit/PR(MR) şablonları, opsiyonel
Cursor/Gemini CLI/Aider kuralları, (ops) `llms.txt` ve tekrar kullanılabilir vibe checklist. context-mode'u
```

- [ ] **Step 4: `README.md` — "Yedi komut" → "Sekiz komut", add `init-aider` + legacy-migration mention**

Find:

```markdown
  substitüsyonu, sürümlü drift tespiti. Yedi komut:
  - `audit` — hazırlık tablosu (✅/❌/—) + makine-okur `SCORE=N/M` footer
  - `init` — eksik agnostik dosyaları düşürür; **var olanı asla ezmez** (SKIP, idempotent)
  - `init-cursor` — Cursor kural dosyaları (`.cursor/rules/project.mdc` + `.cursorrules` → CLAUDE.md)
  - `init-gemini` — Gemini CLI context dosyası (`GEMINI.md` → `@CLAUDE.md` importu)
  - `upgrade` — zaten kurulu repoyu yeni sürüme taşır (sha-drift → UPDATE/ADD/CONFLICT; asla ezmez)
  - `remove` — vibe-setup'ın yarattığı, hâlâ değişmemiş dosyaları kaldırır (dry-run varsayılan, `--apply` gerçek siler)
  - `profile` — tespit edilen stack profilini basar (9 alan + `VIBE_VERSION`, makine-okur)
```

Replace with:

```markdown
  substitüsyonu, sürümlü drift tespiti. Sekiz komut:
  - `audit` — hazırlık tablosu (✅/❌/—) + makine-okur `SCORE=N/M` footer
  - `init` — eksik agnostik dosyaları düşürür; **var olanı asla ezmez** (SKIP, idempotent); legacy tekil
    `AGENT.md` varsa `AGENTS.md`'ye migrate eder (mv + geriye-uyumlu symlink)
  - `init-cursor` — Cursor kural dosyaları (`.cursor/rules/project.mdc` + `.cursorrules` → CLAUDE.md)
  - `init-gemini` — Gemini CLI context dosyası (`GEMINI.md` → `@CLAUDE.md` importu)
  - `init-aider` — Aider config dosyası (`.aider.conf.yml` → `read: AGENTS.md`)
  - `upgrade` — zaten kurulu repoyu yeni sürüme taşır (sha-drift → UPDATE/ADD/CONFLICT; asla ezmez)
  - `remove` — vibe-setup'ın yarattığı, hâlâ değişmemiş dosyaları kaldırır (dry-run varsayılan, `--apply` gerçek siler)
  - `profile` — tespit edilen stack profilini basar (9 alan + `VIBE_VERSION`, makine-okur)
```

- [ ] **Step 5: `README.md` — Skill akışı Faz 2 description**

Find:

```markdown
2. **Rapor + onay** → eksikler agnostik / stack-bağımlı diye gruplanır; AGENTS.md zaten Codex/Kimi Code'u
   kapsar (ekstra dosya gerekmez) — hedef araç sorusu sadece Cursor ve/veya Gemini CLI için ayrı context
   dosyası (`init-cursor`/`init-gemini`) ve hangi maddeler kurulacak sorulur. **Kullanıcı seçmeden dosya üretilmez**; tehlikeli/dışa-dönük
   olanlar (plugin enable, harici repo, izin genişletme) ayrıca onay ister.
```

Replace with:

```markdown
2. **Rapor + onay** → eksikler agnostik / stack-bağımlı diye gruplanır; AGENTS.md geniş bir ekosistemi
   (Codex, Kimi Code, Zed, Warp, VS Code, Devin, Amp, RooCode, Kilo Code, GitHub Copilot coding agent,
   Windsurf, Augment Code, goose, opencode, Junie, Phoenix, Semgrep, Ona, Factory, Jules) zaten kapsar
   (ekstra dosya gerekmez) — hedef araç sorusu sadece Cursor ve/veya Gemini CLI ve/veya Aider için ayrı
   context dosyası (`init-cursor`/`init-gemini`/`init-aider`) ve hangi maddeler kurulacak sorulur.
   **Kullanıcı seçmeden dosya üretilmez**; tehlikeli/dışa-dönük olanlar (plugin enable, harici repo,
   izin genişletme) ayrıca onay ister.
```

- [ ] **Step 6: `README.md` — Cursor section's command list mentions `init-aider`**

Find:

````markdown
   ```
   bash /yol/vibe-setup/skills/vibe-setup/scaffold.sh audit .   # audit | init | init-cursor | init-gemini | upgrade | remove | profile
   ```
   `init-cursor` hedef repoya `.cursor/rules/project.mdc` + `.cursorrules` düşürür (CLAUDE.md'ye yönlendirir);
   `init-gemini` aynı şekilde `GEMINI.md` düşürür. `remove` kurulanları geri alır (önce dry-run, sonra `--apply`).
````

Replace with:

````markdown
   ```
   bash /yol/vibe-setup/skills/vibe-setup/scaffold.sh audit .   # audit | init | init-cursor | init-gemini | init-aider | upgrade | remove | profile
   ```
   `init-cursor` hedef repoya `.cursor/rules/project.mdc` + `.cursorrules` düşürür (CLAUDE.md'ye yönlendirir);
   `init-gemini` aynı şekilde `GEMINI.md` düşürür; `init-aider` `.aider.conf.yml` düşürür (Aider AGENTS.md'yi
   native okumaz, `read: AGENTS.md` ile açıkça işaretler). `remove` kurulanları geri alır (önce dry-run,
   sonra `--apply`).
````

- [ ] **Step 7: `SKILL.md` — Faz 2 "hedef araç sorusu" adds Aider**

Find:

```markdown
- **Hedef araç sorusu:** Claude varsayılan. AGENTS.md zaten Codex ve Kimi Code'u kapsar — bu ikisi
  ekstra dosya istemez, hiçbir şey yapma. Kullanıcıya sor: **"Cursor ve/veya Gemini CLI için ayrı
  context dosyası ister misin?"** Evet ise Faz 3'te ilgili `init-cursor` / `init-gemini`'yi çalıştır.
```

Replace with:

```markdown
- **Hedef araç sorusu:** Claude varsayılan. AGENTS.md geniş bir ekosistemi zaten kapsar (Codex, Kimi
  Code, Zed, Warp, VS Code, Devin, Amp, RooCode, Kilo Code, GitHub Copilot coding agent, Windsurf,
  Augment Code, goose, opencode, Junie, Phoenix, Semgrep, Ona, Factory, Jules) — bunların hiçbiri ekstra
  dosya istemez, hiçbir şey yapma. Kullanıcıya sor: **"Cursor ve/veya Gemini CLI ve/veya Aider için ayrı
  context dosyası ister misin?"** Evet ise Faz 3'te ilgili `init-cursor` / `init-gemini` / `init-aider`'i
  çalıştır.
```

- [ ] **Step 8: `SKILL.md` — Faz 3 adds the `init-aider` call**

Find:

```markdown
- Kullanıcı **Gemini** dediyse: `bash "$SKILL_DIR/scaffold.sh" init-gemini .` → `GEMINI.md`
  (`@CLAUDE.md` importu — Gemini CLI içeriği doğrudan çeker, pointer değil).
- **context-mode kurulumu (HER ZAMAN, sorulmadan — zorunlu bağımlılık, artık opsiyonel değil):**
```

Replace with:

```markdown
- Kullanıcı **Gemini** dediyse: `bash "$SKILL_DIR/scaffold.sh" init-gemini .` → `GEMINI.md`
  (`@CLAUDE.md` importu — Gemini CLI içeriği doğrudan çeker, pointer değil).
- Kullanıcı **Aider** dediyse: `bash "$SKILL_DIR/scaffold.sh" init-aider .` → `.aider.conf.yml`
  (`read: AGENTS.md` — Aider AGENTS.md'yi native okumaz, açıkça işaretlenmesi gerekir).
- **context-mode kurulumu (HER ZAMAN, sorulmadan — zorunlu bağımlılık, artık opsiyonel değil):**
```

- [ ] **Step 9: Verify all edits landed**

Run: `grep -n "init-aider\|Legacy tekil\|Sekiz komut" CLAUDE.md README.md skills/vibe-setup/SKILL.md`
Expected: at least 7 matching lines spread across the three files (CLAUDE.md: file list + gotcha header;
README.md: "Sekiz komut" + command bullet + Cursor-section mention; SKILL.md: Faz 2 + Faz 3 mentions).

- [ ] **Step 10: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED` (documentation-only task, but confirms nothing else broke).

- [ ] **Step 11: Commit**

```bash
git add CLAUDE.md README.md skills/vibe-setup/SKILL.md
git commit -m "$(cat <<'EOF'
VIB-12 CLAUDE.md/README/SKILL.md: init-aider + genis arac ekosistemi + legacy migrasyon dokumante et

Arac destegi gotcha'si Codex/Kimi Code'un yanina agents.md'nin
listeledigi ~17 native-okuyan araci ekledi (Zed, Warp, VS Code, Devin,
Amp, RooCode, Kilo Code, GitHub Copilot coding agent, Windsurf,
Augment Code, goose, opencode, Junie, Phoenix, Semgrep, Ona, Factory,
Jules). Yeni "Legacy tekil AGENT.md" gotcha'si migrasyon provenance
kuralini belgeliyor. README/SKILL.md init-aider'i akisa ve komut
listelerine ekledi.
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:** Madde 2 (init-aider: scaffold.sh command + write_extra pattern + extra_paths + SKILL.md flow + CLAUDE.md gotcha + README mention) → Task 1 + Task 3. Madde 3 (documentation expansion of the native-reader tool list) → Task 3. Madde 4 (legacy AGENT.md migration: detection in `audit()`, migration in `init()`, provenance rule `created:false`, remove-safety regression test) → Task 2. Madde 1 (init-nested/monorepo) is explicitly excluded per the spec's "Plan bölünmesi" section — no task here implements it, by design.

**Placeholder scan:** no TBD/TODO; every step shows complete file content or exact find/replace text; every test file is fully written out, not described.

**Type/name consistency:** `init_aider()` (Task 1) matches the `case "$CMD"` dispatch entry `init-aider) init_aider ;;` (Task 1) and every doc reference to it (Task 3) uses the same `init-aider` / `init_aider` spelling. `migrate_legacy_agent_md()` (Task 2) is called exactly once, from `init()`'s loop, with no other consumer — matches its "Interfaces" block. `.aider.conf.yml` (Task 1's `extra_paths()` entry) matches the exact filename used in Task 1's test, Task 3's `CLAUDE.md`/`README.md`/`SKILL.md` mentions, and the spec's Madde 2 description.
