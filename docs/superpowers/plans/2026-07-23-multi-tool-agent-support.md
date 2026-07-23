# Codex/Gemini/Kimi Multi-Tool Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make vibe-setup's scaffold engine correctly support Codex CLI, Kimi Code CLI, and Gemini CLI alongside the existing Claude Code / Cursor support.

**Architecture:** Codex and Kimi Code already read `AGENTS.md` natively — no new file, just fix AGENTS.md's own (currently wrong) claim that Gemini reads it too, and name Codex/Kimi Code explicitly. Gemini CLI reads a separate `GEMINI.md` (with `@file.md` import support) — add a new `init-gemini` scaffold.sh subcommand that drops it, following the exact never-overwrite pattern `init-cursor` already uses. AGENTS.md's content change bumps the engine's existing sha-drift version machinery (VIBE_VERSION 3→4) — no new drift logic needed, the engine already handles UPDATE/CONFLICT for content changes to synced artifacts.

**Tech Stack:** Bash (scaffold.sh), Markdown (SKILL.md, CLAUDE.md), bash test harness (`tests/*_test.sh`, no external deps).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-23-multi-tool-agent-support-design.md` (approved).
- All generated file content stays Turkish (existing repo convention — see CLAUDE.md "Üretilen dosyalar Türkçe").
- `GEMINI.md` must NOT be added to `managed_paths()` — it follows the Cursor-extras pattern: dropped once by its own `init-*` subcommand, never version/upgrade-tracked, no audit row.
- Any change to `render_artifact`'s AGENTS.md template is a content change to an existing **synced** managed artifact → requires `VIBE_VERSION` bump + matching `artifact_changed_in` entry (per this repo's own documented rule in CLAUDE.md).
- Commit subjects in this repo must match `^[A-Z]{3}-[0-9]{1,4} ` (enforced by `.githooks/commit-msg` via local `vibe.ticketre` config in this repo). Use ticket key `VIB-5` for every commit in this plan (next after `VIB-4`, the spec commit).
- Test runner: `bash tests/run.sh` from repo root — auto-discovers every `tests/*_test.sh`, no registration step needed.

---

### Task 1: Rename `write_managed_cursor` → `write_extra`

**Files:**
- Modify: `skills/vibe-setup/scaffold.sh:441-459`

**Interfaces:**
- Produces: `write_extra` — function signature unchanged from `write_managed_cursor`: `write_extra <path>` (content on stdin), never overwrites an existing file, prints `SKIP <path> (var)` or `NEW <path>`. Task 2's `init_gemini()` will call this.

This is a pure rename (no behavior change) — the function is about to be shared by a second tool (Gemini) in Task 2, so it shouldn't carry Cursor's name anymore.

- [ ] **Step 1: Rename the function definition and both call sites**

In `skills/vibe-setup/scaffold.sh`, find:

```bash
init_cursor() {
  echo "vibe-setup init-cursor — $(pwd)"
  write_managed_cursor .cursor/rules/project.mdc <<'EOF'
---
description: Proje kuralları — tek doğruluk kaynağı CLAUDE.md
alwaysApply: true
---
Bu projenin kuralları, komutları, mimarisi ve gotchas'ı **CLAUDE.md**'dedir; onu izle.
Ek doküman: `docs/`.
EOF
  write_managed_cursor .cursorrules <<'EOF'
# Cursor — tek doğruluk kaynağı CLAUDE.md. Docs: docs/.
# (Modern format: .cursor/rules/*.mdc — bu dosya geriye dönük uyumluluk için.)
EOF
}
write_managed_cursor() {  # $1 path (content on stdin) — never overwrite
  if [ -e "$1" ]; then echo "  SKIP  $1 (var)"; return; fi
  mkdir -p "$(dirname "$1")"; cat > "$1"; echo "  NEW   $1"
}
```

Replace with:

```bash
init_cursor() {
  echo "vibe-setup init-cursor — $(pwd)"
  write_extra .cursor/rules/project.mdc <<'EOF'
---
description: Proje kuralları — tek doğruluk kaynağı CLAUDE.md
alwaysApply: true
---
Bu projenin kuralları, komutları, mimarisi ve gotchas'ı **CLAUDE.md**'dedir; onu izle.
Ek doküman: `docs/`.
EOF
  write_extra .cursorrules <<'EOF'
# Cursor — tek doğruluk kaynağı CLAUDE.md. Docs: docs/.
# (Modern format: .cursor/rules/*.mdc — bu dosya geriye dönük uyumluluk için.)
EOF
}
write_extra() {  # $1 path (content on stdin) — never overwrite. Shared by init-cursor, init-gemini.
  if [ -e "$1" ]; then echo "  SKIP  $1 (var)"; return; fi
  mkdir -p "$(dirname "$1")"; cat > "$1"; echo "  NEW   $1"
}
```

- [ ] **Step 2: Run the existing Cursor test to confirm the rename didn't change behavior**

Run: `bash tests/init_cursor_test.sh`
Expected: `init_cursor_test: 10 passed, 0 failed` (all `ok`, no `FAIL`)

- [ ] **Step 3: Run the full suite as a sanity check**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED` (exit 0)

- [ ] **Step 4: Commit**

```bash
git add skills/vibe-setup/scaffold.sh
git commit -m "$(cat <<'EOF'
VIB-5 scaffold.sh: write_managed_cursor'ı write_extra olarak yeniden adlandır

Fonksiyon artık Cursor'a özel değil — Gemini de kullanacak (bir sonraki commit).
EOF
)"
```

---

### Task 2: Add `init-gemini` subcommand

**Files:**
- Modify: `skills/vibe-setup/scaffold.sh:4-9` (header comment), `:461-468` (dispatch + usage)
- Create (at runtime by the tool, not by hand): none — `init_gemini()` is added to scaffold.sh
- Test: `tests/init_gemini_test.sh` (new)

**Interfaces:**
- Consumes: `write_extra <path>` from Task 1.
- Produces: `init_gemini()` — no args, writes `GEMINI.md` at the target repo root via `write_extra`. Invoked via `scaffold.sh init-gemini [DIR]`.

TDD: write the test first against the not-yet-existing `init-gemini` subcommand, confirm it fails, then implement.

- [ ] **Step 1: Write the failing test**

Create `tests/init_gemini_test.sh`:

```bash
#!/usr/bin/env bash
# scaffold.sh init-gemini testi — Gemini CLI context dosyası üretimi + ezmezlik. Bağımsız (dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD="$ROOT/skills/vibe-setup/scaffold.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
work="$tmp/repo"; mkdir -p "$work"

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

# 1. ilk init-gemini — GEMINI.md düşmeli, CLAUDE.md'yi import etmeli
out1="$(bash "$SCAFFOLD" init-gemini "$work" 2>&1)"
[ -e "$work/GEMINI.md" ] && ok "olustu: GEMINI.md" || bad "yok: GEMINI.md"
grep -q '@CLAUDE.md' "$work/GEMINI.md" 2>/dev/null && ok "GEMINI.md CLAUDE.md'yi import eder" || bad "GEMINI.md @CLAUDE.md import satırı yok"
printf '%s' "$out1" | grep -q 'NEW' && ok "ilk init-gemini NEW basar" || bad "ilk init-gemini NEW basmadi"

# 2. ezmezlik — kullanıcı düzenlemesi ikinci çalıştırmada korunmalı (SKIP)
printf '\n# KULLANICI OZEL KURAL\n' >> "$work/GEMINI.md"
before="$(cksum "$work/GEMINI.md" | awk '{print $1}')"
out2="$(bash "$SCAFFOLD" init-gemini "$work" 2>&1)"
after="$(cksum "$work/GEMINI.md" | awk '{print $1}')"
printf '%s' "$out2" | grep -q 'SKIP' && ok "ikinci init-gemini SKIP basar" || bad "ikinci init-gemini SKIP basmadi"
printf '%s' "$out2" | grep -q 'NEW' && bad "ikinci init-gemini NEW basti (ezme riski)" || ok "ikinci init-gemini NEW basmaz"
grep -q 'KULLANICI OZEL KURAL' "$work/GEMINI.md" && ok "kullanici edit'i korundu" || bad "kullanici edit'i ezildi!"
[ "$before" = "$after" ] && ok "GEMINI.md icerik degismedi (cksum)" || bad "GEMINI.md degisti — ezme!"

echo "init_gemini_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

Make it executable-equivalent (the runner invokes via `bash`, chmod not required, but match sibling files):

```bash
chmod +x tests/init_gemini_test.sh
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `bash tests/init_gemini_test.sh`
Expected: FAIL — `scaffold.sh` doesn't recognize `init-gemini` yet, so it hits the `*) echo "kullanım: ..." >&2; exit 2` branch, no `GEMINI.md` is created. Output should show `FAIL: yok: GEMINI.md` and related failures, ending `init_gemini_test: 0 passed, N failed` with nonzero exit.

- [ ] **Step 3: Implement `init_gemini()` and wire it up**

In `skills/vibe-setup/scaffold.sh`, find the header comment block:

```bash
#   scaffold.sh init-cursor [DIR] → drop Cursor rules (.cursor/rules/*.mdc + .cursorrules → CLAUDE.md)
#   scaffold.sh upgrade [DIR]     → re-apply changed managed templates to an already-set-up repo
```

Replace with:

```bash
#   scaffold.sh init-cursor [DIR] → drop Cursor rules (.cursor/rules/*.mdc + .cursorrules → CLAUDE.md)
#   scaffold.sh init-gemini [DIR] → drop Gemini CLI context file (GEMINI.md → @CLAUDE.md import)
#   scaffold.sh upgrade [DIR]     → re-apply changed managed templates to an already-set-up repo
```

Then find (right after `init_cursor()`/`write_extra()` from Task 1):

```bash
write_extra() {  # $1 path (content on stdin) — never overwrite. Shared by init-cursor, init-gemini.
  if [ -e "$1" ]; then echo "  SKIP  $1 (var)"; return; fi
  mkdir -p "$(dirname "$1")"; cat > "$1"; echo "  NEW   $1"
}
```

Add directly after it:

```bash
init_gemini() {
  echo "vibe-setup init-gemini — $(pwd)"
  write_extra GEMINI.md <<'EOF'
# Gemini CLI context — tek doğruluk kaynağı CLAUDE.md
@CLAUDE.md
EOF
}
```

Then find the dispatch block:

```bash
case "$CMD" in
  audit)   audit ;;
  init)    init ;;
  init-cursor) init_cursor ;;
  upgrade) upgrade ;;
  profile) printf 'STACK=%s\nMODULE_DIR=%s\nFMT=%s\nLINT=%s\nTEST=%s\nBUILD=%s\nSRC_RE=%s\nTEST_FIND=%s\nFMT_FILE_OK=%s\nVIBE_VERSION=%s\n' "$STACK" "$MODULE_DIR" "$FMT" "$LINT" "$TEST" "$BUILD" "$SRC_RE" "$TEST_FIND" "$FMT_FILE_OK" "$VIBE_VERSION" ;;
  *) echo "kullanım: scaffold.sh {audit|init|init-cursor|upgrade|profile} [DIR]" >&2; exit 2 ;;
esac
```

Replace with:

```bash
case "$CMD" in
  audit)   audit ;;
  init)    init ;;
  init-cursor) init_cursor ;;
  init-gemini) init_gemini ;;
  upgrade) upgrade ;;
  profile) printf 'STACK=%s\nMODULE_DIR=%s\nFMT=%s\nLINT=%s\nTEST=%s\nBUILD=%s\nSRC_RE=%s\nTEST_FIND=%s\nFMT_FILE_OK=%s\nVIBE_VERSION=%s\n' "$STACK" "$MODULE_DIR" "$FMT" "$LINT" "$TEST" "$BUILD" "$SRC_RE" "$TEST_FIND" "$FMT_FILE_OK" "$VIBE_VERSION" ;;
  *) echo "kullanım: scaffold.sh {audit|init|init-cursor|init-gemini|upgrade|profile} [DIR]" >&2; exit 2 ;;
esac
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `bash tests/init_gemini_test.sh`
Expected: `init_gemini_test: 7 passed, 0 failed`

- [ ] **Step 5: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 6: Commit**

```bash
git add skills/vibe-setup/scaffold.sh tests/init_gemini_test.sh
git commit -m "$(cat <<'EOF'
VIB-5 scaffold.sh: init-gemini komutu ekle

Gemini CLI AGENTS.md okumaz, kendi GEMINI.md'sini okur (hiyerarşik,
@file.md import destekli). init-cursor ile aynı ezmez-pattern:
GEMINI.md managed_paths'e girmez, versiyon/upgrade takibi yok — bir kez
düşer, kullanıcı sahibi olur.
EOF
)"
```

---

### Task 3: Bump VIBE_VERSION, fix AGENTS.md template, update upgrade tests

**Files:**
- Modify: `skills/vibe-setup/scaffold.sh:15-17` (VIBE_VERSION), `:87-92` (artifact_changed_in), `:224-231` (AGENTS.md template)
- Modify: `tests/upgrade_test.sh:22,74,77,85`

**Interfaces:**
- Consumes: nothing new from Tasks 1-2.
- Produces: `VIBE_VERSION=4`; `artifact_changed_in AGENTS.md` returns `4`; `render_artifact AGENTS.md` returns the corrected template. No new function signatures — this task changes existing constants/templates. Downstream: `write_manifest` (unchanged) will now record `"AGENTS.md": { "v": 4, ... }` for any fresh `init`, and `upgrade`'s existing sha-drift comparison (unchanged logic) will treat any repo still on the old AGENTS.md text as due for `UPDATE` (untouched) or `CONFLICT` (edited).

This task changes the *content* of an already-synced managed artifact (AGENTS.md). The engine's existing UPDATE/CONFLICT machinery (already covered by `upgrade_test.sh` cases C and D) handles this automatically — no new drift logic is needed, only the version/template edit plus updating the tests that hard-code the old version number.

- [ ] **Step 1: Bump VIBE_VERSION with an explanatory comment**

In `skills/vibe-setup/scaffold.sh`, find:

```bash
# Şema versiyonu (tamsayı). Bir managed template VEYA migration değiştiğinde +1; artifact_changed_in'i de güncelle.
# plugin.json semver'i ayrı (marketplace); bu sayı upgrade/migration anahtarıdır.
VIBE_VERSION=3
```

Replace with:

```bash
# Şema versiyonu (tamsayı). Bir managed template VEYA migration değiştiğinde +1; artifact_changed_in'i de güncelle.
# plugin.json semver'i ayrı (marketplace); bu sayı upgrade/migration anahtarıdır.
VIBE_VERSION=4
```

- [ ] **Step 2: Add the AGENTS.md version entry to `artifact_changed_in`**

Find:

```bash
artifact_changed_in() { case "$1" in
  .githooks/pre-commit) echo 2 ;;   # v2: sed→bash literal-replace (node SRC_RE `|` delimiter çakışması fix)
  .githooks/commit-msg) echo 3 ;;   # v3: ticket-key hard-coded → opsiyonel (git config vibe.ticketre; ayarsız = bloklamaz)
  .gitmessage)          echo 3 ;;   # v3: ticket-key opsiyonel ibaresi
  *) echo 1 ;;
esac ; }
```

Replace with:

```bash
artifact_changed_in() { case "$1" in
  .githooks/pre-commit) echo 2 ;;   # v2: sed→bash literal-replace (node SRC_RE `|` delimiter çakışması fix)
  .githooks/commit-msg) echo 3 ;;   # v3: ticket-key hard-coded → opsiyonel (git config vibe.ticketre; ayarsız = bloklamaz)
  .gitmessage)          echo 3 ;;   # v3: ticket-key opsiyonel ibaresi
  AGENTS.md)            echo 4 ;;   # v4: Gemini AGENTS.md okumaz iddiası düzeltildi; Codex/Kimi Code isimlendirildi
  *) echo 1 ;;
esac ; }
```

- [ ] **Step 3: Rewrite the AGENTS.md template**

Find:

```bash
    AGENTS.md) emit "$1" <<'EOF'
<!-- vibe-setup:v@VER@ (managed) -->
# Agent Guide

Bu projenin tek doğruluk kaynağı **CLAUDE.md**'dir. Cursor / Codex / Gemini / Copilot dahil tüm
agent'lar oradan başlasın: [CLAUDE.md](CLAUDE.md). Ek doküman: [docs/](docs/).
EOF
    ;;
```

Replace with:

```bash
    AGENTS.md) emit "$1" <<'EOF'
<!-- vibe-setup:v@VER@ (managed) -->
# Agent Guide

Bu projenin tek doğruluk kaynağı **CLAUDE.md**'dir.

- **AGENTS.md standardını izleyen ajanlar** (Codex, Kimi Code, vb.) bu dosyayı doğrudan okur →
  [CLAUDE.md](CLAUDE.md)'ye bakın.
- **Kendi context dosyası olan araçlar** ayrı pointer kullanır: Cursor → `.cursor/rules/`,
  Gemini CLI → `GEMINI.md` (ikisi de CLAUDE.md'ye yönlendirir/import eder).

Ek doküman: [docs/](docs/).
EOF
    ;;
```

- [ ] **Step 4: Update `tests/upgrade_test.sh`'s hard-coded version references**

Find (test A):

```bash
grep -q '"vibeVersion": 3' "$d/.vibe-setup.json" && ok "vibeVersion=3" || bad "vibeVersion yok/yanlış"
grep -q '".githooks/pre-commit": { "v": 2' "$d/.vibe-setup.json" && ok "pre-commit v2 kayıtlı" || bad "pre-commit v kaydı yok"
```

Replace with:

```bash
grep -q '"vibeVersion": 4' "$d/.vibe-setup.json" && ok "vibeVersion=4" || bad "vibeVersion yok/yanlış"
grep -q '".githooks/pre-commit": { "v": 2' "$d/.vibe-setup.json" && ok "pre-commit v2 kayıtlı" || bad "pre-commit v kaydı yok"
grep -q '"AGENTS.md": { "v": 4' "$d/.vibe-setup.json" && ok "AGENTS.md v4 kayıtlı" || bad "AGENTS.md v kaydı yok"
```

Find (test H, simulating an old install):

```bash
# H. eski manifest sürümü → upgrade sürümü yükseltir; git-repo-değil → v3 migration atlanır (probe-guard)
d="$(fresh H)"
awk '{ sub(/"vibeVersion": 3/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
printf '%s' "$out" | grep -q 'applied=v1' && ok "eski uygulanan sürüm algılandı (v1)" || bad "applied=v1 basılmadı"
grep -q '"vibeVersion": 3' "$d/.vibe-setup.json" && ok "manifest v3'e yükseltildi" || bad "manifest sürümü yükselmedi"
```

Replace with:

```bash
# H. eski manifest sürümü → upgrade sürümü yükseltir; git-repo-değil → v3 migration atlanır (probe-guard)
d="$(fresh H)"
awk '{ sub(/"vibeVersion": 4/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
printf '%s' "$out" | grep -q 'applied=v1' && ok "eski uygulanan sürüm algılandı (v1)" || bad "applied=v1 basılmadı"
grep -q '"vibeVersion": 4' "$d/.vibe-setup.json" && ok "manifest v4'e yükseltildi" || bad "manifest sürümü yükselmedi"
```

Find (test I, same pattern under a real git repo):

```bash
  awk '{ sub(/"vibeVersion": 3/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
```

Replace with:

```bash
  awk '{ sub(/"vibeVersion": 4/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
```

- [ ] **Step 5: Run the upgrade test on its own first**

Run: `bash tests/upgrade_test.sh`
Expected: `upgrade_test: N passed, 0 failed` (N = previous count + 1, for the new AGENTS.md-v4 assertion added in Step 4)

- [ ] **Step 6: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 7: Dogfood — run audit and upgrade on this repo itself to sanity-check the version bump end-to-end**

Run: `bash skills/vibe-setup/scaffold.sh audit .`
Expected: since this repo's own `.vibe-setup.json` (if present) predates this change, output should include a line `UPDATE_AVAILABLE=v3->v4` (or no manifest-version line at all if this repo was never `init`'d — check which is true by reading `.vibe-setup.json` if it exists first). Either outcome is fine; just confirm the script runs without error and reports the new `VIBE_VERSION=4` correctly (visible via `bash skills/vibe-setup/scaffold.sh profile .` → last line `VIBE_VERSION=4`).

- [ ] **Step 8: Commit**

```bash
git add skills/vibe-setup/scaffold.sh tests/upgrade_test.sh
git commit -m "$(cat <<'EOF'
VIB-5 scaffold.sh: AGENTS.md şablonunu düzelt, VIBE_VERSION 4'e yükselt

AGENTS.md'nin "Gemini de bunu okur" iddiası yanlıştı (Gemini CLI kendi
GEMINI.md'sini okur). Codex ve Kimi Code'u isimlendirerek düzeltildi.
Mevcut sha-drift mekanizması bu içerik değişikliğini otomatik olarak
UPDATE/CONFLICT'e çevirir — yeni kod gerekmedi.
EOF
)"
```

---

### Task 4: Update SKILL.md orchestration flow (Faz 2 + Faz 3)

**Files:**
- Modify: `skills/vibe-setup/SKILL.md`

**Interfaces:**
- Consumes: `init-gemini` subcommand from Task 2 (referenced by name in the flow text).
- Produces: nothing consumed by other tasks — this is orchestration prose only, read by the LLM running the vibe-setup skill.

This task has no automated test (it's instructional markdown consumed by an LLM at skill-run time). Verification is a grep-based sanity check that the new command name appears and the old wording is gone.

- [ ] **Step 1: Update the Faz 2 "Hedef araç sorusu" bullet**

In `skills/vibe-setup/SKILL.md`, find:

```markdown
- **Hedef araç sorusu:** Claude varsayılan. Kullanıcıya sor: **"Cursor uyumluluğu da istiyor musun?"**
  (gerekirse Codex/Gemini/Copilot de). Evet ise Faz 3'te `init-cursor` çalıştır + içeriği doldur.
```

Replace with:

```markdown
- **Hedef araç sorusu:** Claude varsayılan. AGENTS.md zaten Codex ve Kimi Code'u kapsar — bu ikisi
  ekstra dosya istemez, hiçbir şey yapma. Kullanıcıya sor: **"Cursor ve/veya Gemini CLI için ayrı
  context dosyası ister misin?"** Evet ise Faz 3'te ilgili `init-cursor` / `init-gemini`'yi çalıştır.
```

- [ ] **Step 2: Update the Faz 3 skeleton-generation section**

Find:

```markdown
- Kullanıcı **Cursor** dediyse: `bash "$SKILL_DIR/scaffold.sh" init-cursor .` → `.cursor/rules/project.mdc`
  + `.cursorrules` (ikisi de CLAUDE.md'ye yönlendirir).
```

Replace with:

```markdown
- Kullanıcı **Cursor** dediyse: `bash "$SKILL_DIR/scaffold.sh" init-cursor .` → `.cursor/rules/project.mdc`
  + `.cursorrules` (ikisi de CLAUDE.md'ye yönlendirir).
- Kullanıcı **Gemini** dediyse: `bash "$SKILL_DIR/scaffold.sh" init-gemini .` → `GEMINI.md`
  (`@CLAUDE.md` importu — Gemini CLI içeriği doğrudan çeker, pointer değil).
```

- [ ] **Step 3: Verify the old wording is gone and the new commands are present**

Run: `grep -n "Codex/Gemini/Copilot\|init-gemini\|Kimi Code" skills/vibe-setup/SKILL.md`
Expected: no match for `Codex/Gemini/Copilot`; matches for `init-gemini` and `Kimi Code`.

- [ ] **Step 4: Commit**

```bash
git add skills/vibe-setup/SKILL.md
git commit -m "$(cat <<'EOF'
VIB-5 SKILL.md: Faz 2/3 akışına Codex/Kimi Code/Gemini netliği ekle

Codex ve Kimi Code AGENTS.md'yi otomatik okuduğu için ekstra dosya
gerekmediği açıklandı; Gemini seçilirse init-gemini çağrısı eklendi.
EOF
)"
```

---

### Task 5: Document the multi-tool decision in this repo's own CLAUDE.md

**Files:**
- Modify: `CLAUDE.md:24` (Dosyalar list), `CLAUDE.md` Gotchas section (add one bullet)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by other tasks — documentation only.

- [ ] **Step 1: Add `init-gemini` to the command list in the "Dosyalar" section**

In `CLAUDE.md`, find:

```markdown
- `skills/vibe-setup/scaffold.sh` — motor (`audit|init|init-cursor|upgrade|profile`)
```

Replace with:

```markdown
- `skills/vibe-setup/scaffold.sh` — motor (`audit|init|init-cursor|init-gemini|upgrade|profile`)
```

- [ ] **Step 2: Add a new Gotchas bullet explaining which tool reads what**

In `CLAUDE.md`, find:

```markdown
- **Hook tool yoksa atlar** (`command -v`). Bu repoda shellcheck/shfmt kurulu olmayabilir → fmt/lint
  sessizce atlanır, test yine çalışır.
```

Replace with:

```markdown
- **Hook tool yoksa atlar** (`command -v`). Bu repoda shellcheck/shfmt kurulu olmayabilir → fmt/lint
  sessizce atlanır, test yine çalışır.
- **Araç desteği:** Codex ve Kimi Code `AGENTS.md`'yi native okur (`init` zaten düşürür, ekstra dosya
  yok). Cursor (`init-cursor`) ve Gemini CLI (`init-gemini` → `GEMINI.md`, `@CLAUDE.md` importu) ayrı
  context dosyası ister — bunlar `managed_paths`'e GİRMEZ (Cursor ile aynı sınıf: bir kez düşer,
  drift/upgrade takibi yok, audit satırı yok). AGENTS.md'nin metni v4'te değişti (Gemini'nin AGENTS.md
  okuduğu yanlış iddiası düzeltildi) → bkz `VIBE_VERSION`.
```

- [ ] **Step 3: Verify the edits render correctly**

Run: `grep -n "init-gemini\|Araç desteği" CLAUDE.md`
Expected: both lines present.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
VIB-5 CLAUDE.md: araç desteği gotcha'sı + init-gemini komut listesi

Hangi ajan aracının AGENTS.md'yi native okuduğu, hangisinin ayrı context
dosyası (GEMINI.md, Cursor rules) istediği belgelendi.
EOF
)"
```

---

### Task 6: Full-suite verification + repo dogfood re-audit

**Files:** none modified — verification only.

**Interfaces:** none.

- [ ] **Step 1: Run the complete test suite one more time from a clean state**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`, exit code 0. This exercises every `tests/*_test.sh` including the new `init_gemini_test.sh` and the updated `upgrade_test.sh`.

- [ ] **Step 2: Dogfood — audit this repo with the new engine**

Run: `bash skills/vibe-setup/scaffold.sh audit .`
Expected: runs without error; `SCORE=N/M` footer present; if this repo has a `.vibe-setup.json` from before this work, either an `UPDATE_AVAILABLE=v3->v4` line appears (repo not yet upgraded) or no such line if already upgraded in a prior step — both are acceptable, just confirm no script error.

- [ ] **Step 3: If `UPDATE_AVAILABLE` appeared, run upgrade on this repo and confirm AGENTS.md regenerates cleanly**

Only if Step 2 printed `UPDATE_AVAILABLE`:

Run: `bash skills/vibe-setup/scaffold.sh upgrade .`
Expected: `UPDATE=AGENTS.md` (if this repo's AGENTS.md was never hand-edited) or `CONFLICT=AGENTS.md` (if it was — in which case do NOT blindly overwrite; this repo's own AGENTS.md content should be inspected and merged by hand, following the same CONFLICT-merge principle documented in SKILL.md's Upgrade akışı). Report which happened; do not proceed past a CONFLICT without showing the diff.

- [ ] **Step 4: Confirm no stray files from test runs are left in the repo**

Run: `git status --porcelain`
Expected: only the files intentionally modified across Tasks 1-5 (or, if Step 3 ran `upgrade`, also the regenerated `AGENTS.md` / `.vibe-setup.json`) — no leftover temp directories or test artifacts outside `tests/`.

- [ ] **Step 5: Final commit if Step 3 produced changes**

Only if Step 3 modified tracked files:

```bash
git add AGENTS.md .vibe-setup.json
git commit -m "$(cat <<'EOF'
VIB-5 dogfood: bu repoyu vibe-setup v4'e yükselt

scaffold.sh upgrade . ile AGENTS.md yeni şablona taşındı.
EOF
)"
```
