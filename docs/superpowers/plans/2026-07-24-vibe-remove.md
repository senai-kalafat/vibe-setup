# vibe-remove Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `.vibe-setup.json` real provenance (did vibe-setup create this path, or was it already there) and add a `scaffold.sh remove` command that uses that provenance to safely undo everything the deterministic engine created — without ever touching a file the user already had, or one they've since hand-edited.

**Architecture:** Every path vibe-setup writes (`managed_paths()` + the new `extra_paths()` for Cursor/Gemini files) gets a `created: true|false` flag recorded in `.vibe-setup.json`, computed once and never re-derived (mirrors how `sha` is already preserved-not-reblessed for CONFLICTs). `write_manifest()` becomes the single place this is computed and becomes callable from `init`, `upgrade`, `init-cursor`, and `init-gemini` alike, so the manifest is always a complete, current record no matter which subcommand last ran. `remove` reads that record to classify every tracked path into REMOVE (created + unchanged) / KEEP (created + hand-edited) / untouched (pre-existing), dry-running by default and only acting on `--apply`.

**Tech Stack:** Bash (scaffold.sh — must stay bash-3.2-compatible for macOS's default `/bin/bash`), the existing grep/awk-based `.vibe-setup.json` parsing (no `jq` dependency for the engine itself), the repo's bash test harness (`tests/*_test.sh`, no external deps).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-24-vibe-remove-design.md` (approved).
- **Scope is scaffold.sh only.** No SKILL.md, CLAUDE.md, or README.md changes — the approved spec's "Değişiklikler" is entirely engine-level; do not add orchestration-layer wiring beyond what's specified here.
- **No VIBE_VERSION bump.** `.vibe-setup.json`'s own schema is not a `managed_paths()` artifact and is never drift-tracked against itself — adding fields to it is an engine change, not a rendered-template content change. Do not touch `VIBE_VERSION` or `artifact_changed_in`.
- **`created` semantics:** `true` = vibe-setup wrote this path (was `NEW`). `false` = the path already existed when vibe-setup first touched it (was `SKIP`). Once a path has a `created` value recorded in `.vibe-setup.json`, every later `write_manifest()` call preserves it verbatim — never recompute it from a fresh NEW/SKIP result on a later run.
- **`extras` section (`.cursor/rules/project.mdc`, `.cursorrules`, `GEMINI.md`) has no `v` field and no CONFLICT/drift concept** — those files are (and remain) outside version tracking. Only `created` + `sha` are recorded for them, for `remove`'s benefit.
- **`gitignoreLine` is optional** and only appears in the manifest when `init()` actually appended a `.gitignore` line this run, or when a prior run already recorded one (preserve-forward). If the line pre-existed in `.gitignore` before vibe-setup touched it, nothing is recorded.
- **`remove` is dry-run unless `--apply` is passed.** Dry-run only prints; nothing is deleted, nothing is written to disk.
- **`remove --apply` never deletes:** a path with no `created` entry or `created: false` (pre-existing before vibe-setup), a path with `created: true` whose current sha no longer matches the manifest's recorded sha (hand-edited since creation), or any LLM-authored content (`CLAUDE.md`, `docs/`, `tests/`, `.claude/settings.json`'s filled-in permissions). `.vibe-setup.json` itself is always deleted last, unconditionally, once `--apply` runs.
- **`remove --apply` writes `vibe-remove-report.md`** to the repo root (dry-run writes nothing to disk, stdout only).
- **All generated/written prose (report included) stays Turkish** — existing repo convention.
- **Manifest stays single-line-per-JSON-entry**, parseable by the existing grep/awk helpers without `jq`. Follow the exact style of `manifest_sha()`/`manifest_version()`.
- **Bash 3.2 compatibility** (macOS ships this as `/bin/bash`): when looping over a `local arr=()` that might be empty, use the codebase's existing guard idiom `${arr[@]+"${arr[@]}"}`, not a bare `"${arr[@]}"`.
- Commit subjects in this repo must match `^[A-Z]{3}-[0-9]{1,4} ` (`.githooks/commit-msg`, local `vibe.ticketre` config). Use ticket key `VIB-7` for every commit in this plan (next after `VIB-6`, the spec commit).
- Test runner: `bash tests/run.sh` from repo root — auto-discovers every `tests/*_test.sh`, no registration step.

---

### Task 1: `created` provenance flag on `managed` entries

**Files:**
- Modify: `skills/vibe-setup/scaffold.sh:325-334` (manifest read helpers + `CONFLICT_PATHS`/`sha_for_manifest` block), `skills/vibe-setup/scaffold.sh:345-350` (write_manifest's managed loop), `skills/vibe-setup/scaffold.sh:359-365` (`write_managed`)
- Test: `tests/init_test.sh` (extend)
- Test: `tests/upgrade_test.sh` (extend, one assertion)

**Interfaces:**
- Produces: `manifest_created(path)` — echoes `true`, `false`, or nothing (path not in an existing manifest). `created_for_manifest(path)` — echoes `true` or `false`, always: preserves `manifest_created`'s value if non-empty, else `true` iff `path` is in the run-scoped `NEW_PATHS` string, else `false`. `NEW_PATHS` — global string, space-separated paths that were `NEW` (not `SKIP`) *this invocation*; `write_managed` (this task) and `write_extra` (already exists, wired in Task 2) append to it.
- Consumes: nothing new from outside this task; uses existing `sha_of_path`, the existing `CONFLICT_PATHS` string-membership idiom (`case " $X " in *" $1 "*)`).

This is the foundational piece: every later task (extras, gitignoreLine, remove) reads `created` via `manifest_created`/`created_for_manifest`, so get the read/write pair exactly right here, with its own test coverage, before building on it.

- [ ] **Step 1: Add `manifest_created()` and `NEW_PATHS`, wire `created_for_manifest()`**

In `skills/vibe-setup/scaffold.sh`, find:

```bash
manifest_version() { [ -f .vibe-setup.json ] && grep -oE '"vibeVersion"[[:space:]]*:[[:space:]]*[0-9]+' .vibe-setup.json | grep -oE '[0-9]+' | head -1; }
manifest_sha()     { [ -f .vibe-setup.json ] && grep -F "\"$1\":" .vibe-setup.json | grep -oE '"sha"[[:space:]]*:[[:space:]]*"[0-9]+"' | grep -oE '[0-9]+' | head -1; }

CONFLICT_PATHS=""   # upgrade doldurur; manifest bu dosyaların ESKİ sha'sını korur (kullanıcı edit'i "blessed" olmasın)
sha_for_manifest() {
  case " $CONFLICT_PATHS " in
    *" $1 "*) manifest_sha "$1" 2>/dev/null || sha_of_path "$1" ;;
    *) sha_of_path "$1" ;;
  esac
}
```

Replace with:

```bash
manifest_version() { [ -f .vibe-setup.json ] && grep -oE '"vibeVersion"[[:space:]]*:[[:space:]]*[0-9]+' .vibe-setup.json | grep -oE '[0-9]+' | head -1; }
manifest_sha()     { [ -f .vibe-setup.json ] && grep -F "\"$1\":" .vibe-setup.json | grep -oE '"sha"[[:space:]]*:[[:space:]]*"[0-9]+"' | grep -oE '[0-9]+' | head -1; }
manifest_created() { [ -f .vibe-setup.json ] && grep -F "\"$1\":" .vibe-setup.json | grep -oE '"created"[[:space:]]*:[[:space:]]*(true|false)' | grep -oE 'true|false' | head -1; }

CONFLICT_PATHS=""   # upgrade doldurur; manifest bu dosyaların ESKİ sha'sını korur (kullanıcı edit'i "blessed" olmasın)
NEW_PATHS=""        # write_managed/write_extra bu ÇALIŞTIRMADA "NEW" basılan yolları doldurur (created:true tespiti için)
sha_for_manifest() {
  case " $CONFLICT_PATHS " in
    *" $1 "*) manifest_sha "$1" 2>/dev/null || sha_of_path "$1" ;;
    *) sha_of_path "$1" ;;
  esac
}
# created bir kez set edilince asla flip olmaz: manifestte zaten kayıtlıysa onu koru (CONFLICT'te bile),
# yoksa bu çalıştırmada NEW basıldıysa true, SKIP basıldıysa (zaten vardı) false.
created_for_manifest() {
  local prior; prior="$(manifest_created "$1" 2>/dev/null || true)"
  if [ -n "$prior" ]; then echo "$prior"; return; fi
  case " $NEW_PATHS " in
    *" $1 "*) echo true ;;
    *) echo false ;;
  esac
}
```

- [ ] **Step 2: Make `write_managed` record NEW paths**

Find:

```bash
write_managed() {  # $1 = managed path
  if [ -e "$1" ]; then echo "  SKIP  $1 (var)"; return; fi
  mkdir -p "$(dirname "$1")"
  render_artifact "$1" > "$1"
  case "$1" in .githooks/*) chmod +x "$1" ;; esac
  echo "  NEW   $1"
}
```

Replace with:

```bash
write_managed() {  # $1 = managed path
  if [ -e "$1" ]; then echo "  SKIP  $1 (var)"; return; fi
  mkdir -p "$(dirname "$1")"
  render_artifact "$1" > "$1"
  case "$1" in .githooks/*) chmod +x "$1" ;; esac
  NEW_PATHS="$NEW_PATHS $1"
  echo "  NEW   $1"
}
```

- [ ] **Step 3: Add `created` to the rendered manifest's `managed` entries**

Find:

```bash
    echo "  \"managed\": {"
    local n=${#paths[@]} i=0 sep
    for p in ${paths[@]+"${paths[@]}"}; do
      i=$((i+1)); sep=","; [ "$i" -eq "$n" ] && sep=""
      printf '    "%s": { "v": %s, "sha": "%s" }%s\n' "$p" "$(artifact_changed_in "$p")" "$(sha_for_manifest "$p")" "$sep"
    done
    echo "  },"
    echo "  \"llm\": [\"CLAUDE.md\", \"docs/\", \"tests/\"]"
```

Replace with:

```bash
    echo "  \"managed\": {"
    local n=${#paths[@]} i=0 sep
    for p in ${paths[@]+"${paths[@]}"}; do
      i=$((i+1)); sep=","; [ "$i" -eq "$n" ] && sep=""
      printf '    "%s": { "v": %s, "sha": "%s", "created": %s }%s\n' "$p" "$(artifact_changed_in "$p")" "$(sha_for_manifest "$p")" "$(created_for_manifest "$p")" "$sep"
    done
    echo "  },"
    echo "  \"llm\": [\"CLAUDE.md\", \"docs/\", \"tests/\"]"
```

- [ ] **Step 4: Add test coverage in `tests/init_test.sh`**

In `tests/init_test.sh`, find:

```bash
# 2. settings.json geçerli JSON
if command -v jq >/dev/null 2>&1; then
  jq -e . "$work/.claude/settings.json" >/dev/null 2>&1 && ok "settings.json gecerli JSON" || bad "settings.json bozuk JSON"
else
  echo "  skip: jq yok — JSON gecerlilik atlandi"
fi
```

Replace with:

```bash
# 2. settings.json + manifest geçerli JSON
if command -v jq >/dev/null 2>&1; then
  jq -e . "$work/.claude/settings.json" >/dev/null 2>&1 && ok "settings.json gecerli JSON" || bad "settings.json bozuk JSON"
  jq -e . "$work/.vibe-setup.json" >/dev/null 2>&1 && ok ".vibe-setup.json gecerli JSON" || bad ".vibe-setup.json bozuk JSON"
else
  echo "  skip: jq yok — JSON gecerlilik atlandi"
fi
```

Then, at the end of the file, find:

```bash
grep -q '@FMT@\|@SRCRE@\|@STACK@\|@LINT@\|@FMTFILEOK@\|@VER@' "$node/.githooks/pre-commit" 2>/dev/null && bad "ikame edilmemis @marker@ kaldi" || ok "tum @marker@ ikame edildi"

echo "init_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

Replace with:

```bash
grep -q '@FMT@\|@SRCRE@\|@STACK@\|@LINT@\|@FMTFILEOK@\|@VER@' "$node/.githooks/pre-commit" 2>/dev/null && bad "ikame edilmemis @marker@ kaldi" || ok "tum @marker@ ikame edildi"

# 6. created flag — yeni yazılan dosya true, önceden var olan (SKIP'lenen) dosya false
pre="$tmp/pre-existing"; mkdir -p "$pre"
echo '# zaten vardı' > "$pre/.gitmessage"
bash "$SCAFFOLD" init "$pre" >/dev/null 2>&1
grep -q '"AGENTS.md": { "v": 4, "sha": "[0-9]*", "created": true' "$pre/.vibe-setup.json" && ok "yeni yazilan AGENTS.md created:true" || bad "AGENTS.md created:true degil"
grep -q '".gitmessage": { "v": 3, "sha": "[0-9]*", "created": false' "$pre/.vibe-setup.json" && ok "onceden var olan .gitmessage created:false" || bad ".gitmessage created:false degil"

echo "init_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 5: Add a CONFLICT-preservation regression check to `tests/upgrade_test.sh`**

In `tests/upgrade_test.sh`, find (test D's final two lines):

```bash
out2="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
[ "$(field "$out2" CONFLICT)" = ".githooks/pre-commit" ] && ok "2. upgrade hâlâ CONFLICT" || bad "2. upgrade conflict düştü: U='$(field "$out2" UPDATE)'"
grep -q 'KULLANICI OZEL SATIR' "$d/.githooks/pre-commit" && ok "2. upgrade'de de ezilmedi" || bad "2. upgrade kullanıcı edit'ini ezdi!"
```

Replace with:

```bash
out2="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
[ "$(field "$out2" CONFLICT)" = ".githooks/pre-commit" ] && ok "2. upgrade hâlâ CONFLICT" || bad "2. upgrade conflict düştü: U='$(field "$out2" UPDATE)'"
grep -q 'KULLANICI OZEL SATIR' "$d/.githooks/pre-commit" && ok "2. upgrade'de de ezilmedi" || bad "2. upgrade kullanıcı edit'ini ezdi!"
grep -q '".githooks/pre-commit": { "v": 2, "sha": "[0-9]*", "created": true' "$d/.vibe-setup.json" && ok "CONFLICT'te de created:true korunur" || bad "created flag CONFLICT'te bozuldu"
```

- [ ] **Step 6: Run the affected tests**

Run: `bash tests/init_test.sh && bash tests/upgrade_test.sh`
Expected: both print `... passed, 0 failed` with no `FAIL` lines.

- [ ] **Step 7: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 8: Commit**

```bash
git add skills/vibe-setup/scaffold.sh tests/init_test.sh tests/upgrade_test.sh
git commit -m "$(cat <<'EOF'
VIB-7 scaffold.sh: manifest'e created provenance flag ekle

managed girdileri artık vibe-setup'ın bu dosyayı yarattığını mı (true)
yoksa önceden var olup SKIP'lendiğini mi (false) kaydediyor. Bir kez
set edilince flip olmaz — sonraki remove komutunun güvenli silme kararı
buna dayanacak.
EOF
)"
```

---

### Task 2: `extras` manifest section for Cursor/Gemini files

**Files:**
- Modify: `skills/vibe-setup/scaffold.sh:82-86` (add `extra_paths()`), `skills/vibe-setup/scaffold.sh:335-356` (write_manifest — as left by Task 1), `skills/vibe-setup/scaffold.sh:449-475` (`init_cursor`/`init_gemini`)
- Test: `tests/init_cursor_test.sh` (extend), `tests/init_gemini_test.sh` (extend)

**Interfaces:**
- Consumes: `created_for_manifest`, `sha_for_manifest`, `NEW_PATHS`, `write_extra` (all from Task 1 / pre-existing).
- Produces: `extra_paths()` — echoes `.cursor/rules/project.mdc`, `.cursorrules`, `GEMINI.md` (one per line, same shape as `managed_paths()`). `write_manifest()` now also emits a top-level `"extras"` object with the same `{sha, created}` shape as `managed` entries but no `v` field. `write_manifest` is now called at the end of both `init_cursor()` and `init_gemini()`.

`init-cursor`/`init-gemini` currently don't touch `.vibe-setup.json` at all — after this task, running either (even on a repo that was never `init`-ed) produces or refreshes a valid manifest recording what they wrote, which `remove` (Task 4) depends on.

- [ ] **Step 1: Add `extra_paths()`**

In `skills/vibe-setup/scaffold.sh`, find:

```bash
managed_present() { local p; for p in $(managed_paths); do [ -e "$p" ] && return 0; done; return 1; }
```

Replace with:

```bash
managed_present() { local p; for p in $(managed_paths); do [ -e "$p" ] && return 0; done; return 1; }
# init-cursor/init-gemini'nin düşürdüğü "extra" dosyalar — managed_paths'e GİRMEZ (versiyon/drift takibi yok,
# audit satırı yok), ama remove'un provenance'ı için manifestin ayrı extras bölümünde kaydedilir.
extra_paths() {
  printf '%s\n' .cursor/rules/project.mdc .cursorrules GEMINI.md
}
```

- [ ] **Step 2: Add the `extras` block to `write_manifest`**

Find (this is `write_manifest` as Task 1 left it):

```bash
write_manifest() {
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
  local paths=() p; for p in $(managed_paths); do [ -e "$p" ] && paths+=("$p"); done
  # ÖNCE body'yi kur (eski .vibe-setup.json hâlâ dururken sha_for_manifest CONFLICT'lerin eski sha'sını okur),
  # SONRA tek seferde yaz — yoksa `> file` redirect'i dosyayı baştan trunc eder, eski sha kaybolur.
  local body; body="$(
    echo "{"
    echo "  \"vibeVersion\": $VIBE_VERSION,"
    echo "  \"stack\": \"$STACK\","
    echo "  \"generatedAt\": \"$ts\","
    echo "  \"managed\": {"
    local n=${#paths[@]} i=0 sep
    for p in ${paths[@]+"${paths[@]}"}; do
      i=$((i+1)); sep=","; [ "$i" -eq "$n" ] && sep=""
      printf '    "%s": { "v": %s, "sha": "%s", "created": %s }%s\n' "$p" "$(artifact_changed_in "$p")" "$(sha_for_manifest "$p")" "$(created_for_manifest "$p")" "$sep"
    done
    echo "  },"
    echo "  \"llm\": [\"CLAUDE.md\", \"docs/\", \"tests/\"]"
    echo "}"
  )"
  printf '%s\n' "$body" > .vibe-setup.json
}
```

Replace with:

```bash
write_manifest() {
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
  local paths=() p; for p in $(managed_paths); do [ -e "$p" ] && paths+=("$p"); done
  local extras=(); for p in $(extra_paths); do [ -e "$p" ] && extras+=("$p"); done
  # ÖNCE body'yi kur (eski .vibe-setup.json hâlâ dururken sha_for_manifest CONFLICT'lerin eski sha'sını okur),
  # SONRA tek seferde yaz — yoksa `> file` redirect'i dosyayı baştan trunc eder, eski sha kaybolur.
  local body; body="$(
    echo "{"
    echo "  \"vibeVersion\": $VIBE_VERSION,"
    echo "  \"stack\": \"$STACK\","
    echo "  \"generatedAt\": \"$ts\","
    echo "  \"managed\": {"
    local n=${#paths[@]} i=0 sep
    for p in ${paths[@]+"${paths[@]}"}; do
      i=$((i+1)); sep=","; [ "$i" -eq "$n" ] && sep=""
      printf '    "%s": { "v": %s, "sha": "%s", "created": %s }%s\n' "$p" "$(artifact_changed_in "$p")" "$(sha_for_manifest "$p")" "$(created_for_manifest "$p")" "$sep"
    done
    echo "  },"
    echo "  \"extras\": {"
    local en=${#extras[@]} ei=0 esep
    for p in ${extras[@]+"${extras[@]}"}; do
      ei=$((ei+1)); esep=","; [ "$ei" -eq "$en" ] && esep=""
      printf '    "%s": { "sha": "%s", "created": %s }%s\n' "$p" "$(sha_for_manifest "$p")" "$(created_for_manifest "$p")" "$esep"
    done
    echo "  },"
    echo "  \"llm\": [\"CLAUDE.md\", \"docs/\", \"tests/\"]"
    echo "}"
  )"
  printf '%s\n' "$body" > .vibe-setup.json
}
```

- [ ] **Step 3: Call `write_manifest` from `init_cursor` and `init_gemini`**

Find:

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
  write_manifest
}
```

Find:

```bash
init_gemini() {
  echo "vibe-setup init-gemini — $(pwd)"
  write_extra GEMINI.md <<'EOF'
# Gemini CLI context — tek doğruluk kaynağı CLAUDE.md
@CLAUDE.md
EOF
}
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
```

- [ ] **Step 4: Add test coverage in `tests/init_cursor_test.sh`**

In `tests/init_cursor_test.sh`, find:

```bash
grep -q 'alwaysApply: true' "$work/.cursor/rules/project.mdc" 2>/dev/null && ok "project.mdc frontmatter alwaysApply" || bad "project.mdc frontmatter eksik"
printf '%s' "$out1" | grep -q 'NEW' && ok "ilk init-cursor NEW basar" || bad "ilk init-cursor NEW basmadi"
```

Replace with:

```bash
grep -q 'alwaysApply: true' "$work/.cursor/rules/project.mdc" 2>/dev/null && ok "project.mdc frontmatter alwaysApply" || bad "project.mdc frontmatter eksik"
printf '%s' "$out1" | grep -q 'NEW' && ok "ilk init-cursor NEW basar" || bad "ilk init-cursor NEW basmadi"
[ -f "$work/.vibe-setup.json" ] && ok "init-cursor tek basina manifest yazar" || bad "init-cursor manifest yazmadi"
grep -q '".cursor/rules/project.mdc": { "sha": "[0-9]*", "created": true' "$work/.vibe-setup.json" 2>/dev/null && ok "extras: project.mdc created:true kayitli" || bad "extras: project.mdc manifest kaydi yok/yanlis"
grep -q '".cursorrules": { "sha": "[0-9]*", "created": true' "$work/.vibe-setup.json" 2>/dev/null && ok "extras: .cursorrules created:true kayitli" || bad "extras: .cursorrules manifest kaydi yok/yanlis"
```

- [ ] **Step 5: Add test coverage in `tests/init_gemini_test.sh`**

In `tests/init_gemini_test.sh`, find:

```bash
grep -q '@CLAUDE.md' "$work/GEMINI.md" 2>/dev/null && ok "GEMINI.md CLAUDE.md'yi import eder" || bad "GEMINI.md @CLAUDE.md import satırı yok"
printf '%s' "$out1" | grep -q 'NEW' && ok "ilk init-gemini NEW basar" || bad "ilk init-gemini NEW basmadi"
```

Replace with:

```bash
grep -q '@CLAUDE.md' "$work/GEMINI.md" 2>/dev/null && ok "GEMINI.md CLAUDE.md'yi import eder" || bad "GEMINI.md @CLAUDE.md import satırı yok"
printf '%s' "$out1" | grep -q 'NEW' && ok "ilk init-gemini NEW basar" || bad "ilk init-gemini NEW basmadi"
[ -f "$work/.vibe-setup.json" ] && ok "init-gemini tek basina manifest yazar" || bad "init-gemini manifest yazmadi"
grep -q '"GEMINI.md": { "sha": "[0-9]*", "created": true' "$work/.vibe-setup.json" 2>/dev/null && ok "extras: GEMINI.md created:true kayitli" || bad "extras: GEMINI.md manifest kaydi yok/yanlis"
```

- [ ] **Step 6: Run the affected tests**

Run: `bash tests/init_cursor_test.sh && bash tests/init_gemini_test.sh`
Expected: both print `... passed, 0 failed`, no `FAIL`.

- [ ] **Step 7: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 8: Commit**

```bash
git add skills/vibe-setup/scaffold.sh tests/init_cursor_test.sh tests/init_gemini_test.sh
git commit -m "$(cat <<'EOF'
VIB-7 scaffold.sh: extras (Cursor/Gemini) icin manifest provenance ekle

init-cursor/init-gemini artik yazdiklarini .vibe-setup.json'un yeni
extras bolumune kaydediyor (v yok, sadece sha+created) — remove
komutunun bu dosyalari da guvenle siniflandirabilmesi icin.
EOF
)"
```

---

### Task 3: `gitignoreLine` provenance

**Files:**
- Modify: `skills/vibe-setup/scaffold.sh:328-329` (`CONFLICT_PATHS`/`NEW_PATHS` block — as left by Task 1), `skills/vibe-setup/scaffold.sh:325-327` (manifest read helpers — as left by Task 1), `skills/vibe-setup/scaffold.sh:335-360ish` (write_manifest — as left by Task 2), `skills/vibe-setup/scaffold.sh:371-374` (`init()`'s `.gitignore` append)
- Test: `tests/init_test.sh` (extend)

**Interfaces:**
- Consumes: `write_manifest` (as left by Task 2).
- Produces: `GITIGNORE_LINE` — global string, set by `init()` to `.claude/settings.local.json` only in the branch where it actually appended that line this run; empty otherwise. `manifest_gitignore_line()` — echoes the previously-recorded `gitignoreLine` value from `.vibe-setup.json`, or nothing. `write_manifest` now emits an optional top-level `"gitignoreLine"` field: `$GITIGNORE_LINE` if set this run, else the preserved prior value, else omitted entirely.

- [ ] **Step 1: Add the `GITIGNORE_LINE` global**

Find:

```bash
CONFLICT_PATHS=""   # upgrade doldurur; manifest bu dosyaların ESKİ sha'sını korur (kullanıcı edit'i "blessed" olmasın)
NEW_PATHS=""        # write_managed/write_extra bu ÇALIŞTIRMADA "NEW" basılan yolları doldurur (created:true tespiti için)
sha_for_manifest() {
```

Replace with:

```bash
CONFLICT_PATHS=""   # upgrade doldurur; manifest bu dosyaların ESKİ sha'sını korur (kullanıcı edit'i "blessed" olmasın)
NEW_PATHS=""        # write_managed/write_extra bu ÇALIŞTIRMADA "NEW" basılan yolları doldurur (created:true tespiti için)
GITIGNORE_LINE=""   # init bu ÇALIŞTIRMADA .gitignore'a satır eklediyse doldurur; boşsa write_manifest eski kaydı korur
sha_for_manifest() {
```

- [ ] **Step 2: Add `manifest_gitignore_line()`**

Find:

```bash
manifest_created() { [ -f .vibe-setup.json ] && grep -F "\"$1\":" .vibe-setup.json | grep -oE '"created"[[:space:]]*:[[:space:]]*(true|false)' | grep -oE 'true|false' | head -1; }
```

Replace with:

```bash
manifest_created() { [ -f .vibe-setup.json ] && grep -F "\"$1\":" .vibe-setup.json | grep -oE '"created"[[:space:]]*:[[:space:]]*(true|false)' | grep -oE 'true|false' | head -1; }
manifest_gitignore_line() { [ -f .vibe-setup.json ] && grep -oE '"gitignoreLine"[[:space:]]*:[[:space:]]*"[^"]*"' .vibe-setup.json | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/' | head -1; }
```

- [ ] **Step 3: Emit the optional field from `write_manifest`**

Find (this is `write_manifest` as Task 2 left it — only the top portion and the tail change):

```bash
write_manifest() {
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
  local paths=() p; for p in $(managed_paths); do [ -e "$p" ] && paths+=("$p"); done
  local extras=(); for p in $(extra_paths); do [ -e "$p" ] && extras+=("$p"); done
  # ÖNCE body'yi kur (eski .vibe-setup.json hâlâ dururken sha_for_manifest CONFLICT'lerin eski sha'sını okur),
  # SONRA tek seferde yaz — yoksa `> file` redirect'i dosyayı baştan trunc eder, eski sha kaybolur.
  local body; body="$(
```

Replace with:

```bash
write_manifest() {
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
  local paths=() p; for p in $(managed_paths); do [ -e "$p" ] && paths+=("$p"); done
  local extras=(); for p in $(extra_paths); do [ -e "$p" ] && extras+=("$p"); done
  local gi; gi="$GITIGNORE_LINE"
  [ -z "$gi" ] && gi="$(manifest_gitignore_line 2>/dev/null || true)"
  # ÖNCE body'yi kur (eski .vibe-setup.json hâlâ dururken sha_for_manifest CONFLICT'lerin eski sha'sını okur),
  # SONRA tek seferde yaz — yoksa `> file` redirect'i dosyayı baştan trunc eder, eski sha kaybolur.
  local body; body="$(
```

Then find:

```bash
    echo "  },"
    echo "  \"llm\": [\"CLAUDE.md\", \"docs/\", \"tests/\"]"
    echo "}"
  )"
  printf '%s\n' "$body" > .vibe-setup.json
}
```

Replace with:

```bash
    echo "  },"
    if [ -n "$gi" ]; then
      printf '  "gitignoreLine": "%s",\n' "$gi"
    fi
    echo "  \"llm\": [\"CLAUDE.md\", \"docs/\", \"tests/\"]"
    echo "}"
  )"
  printf '%s\n' "$body" > .vibe-setup.json
}
```

(This second `echo "  },"` is the one that closes the `extras` block — it's the last `echo "  },"` before the `llm` line in the function.)

- [ ] **Step 4: Set `GITIGNORE_LINE` in `init()`**

Find:

```bash
  if [ -f .gitignore ] && ! grep -q 'settings.local.json' .gitignore; then
    printf '\n.claude/settings.local.json\n' >> .gitignore; echo "  EDIT  .gitignore (+settings.local.json)"
  fi
```

Replace with:

```bash
  if [ -f .gitignore ] && ! grep -q 'settings.local.json' .gitignore; then
    printf '\n.claude/settings.local.json\n' >> .gitignore; echo "  EDIT  .gitignore (+settings.local.json)"
    GITIGNORE_LINE=".claude/settings.local.json"
  fi
```

- [ ] **Step 5: Add test coverage in `tests/init_test.sh`**

At the end of `tests/init_test.sh`, find:

```bash
grep -q '".gitmessage": { "v": 3, "sha": "[0-9]*", "created": false' "$pre/.vibe-setup.json" && ok "onceden var olan .gitmessage created:false" || bad ".gitmessage created:false degil"

echo "init_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

Replace with:

```bash
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
```

- [ ] **Step 6: Run the affected test**

Run: `bash tests/init_test.sh`
Expected: `init_test: N passed, 0 failed`, no `FAIL`.

- [ ] **Step 7: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 8: Commit**

```bash
git add skills/vibe-setup/scaffold.sh tests/init_test.sh
git commit -m "$(cat <<'EOF'
VIB-7 scaffold.sh: .gitignore satiri icin manifest provenance ekle

init'in .gitignore'a eklediği satır artık .vibe-setup.json'da
gitignoreLine olarak kayıtlı (sadece bu çalıştırmada gerçekten
eklendiyse) ve sonraki upgrade/init-cursor/init-gemini çağrılarında
korunuyor — remove komutu bu satırı geri almak için buna bakacak.
EOF
)"
```

---

### Task 4: `remove` command (dry-run default + `--apply`)

**Files:**
- Modify: `skills/vibe-setup/scaffold.sh:4-10` (header comment), `skills/vibe-setup/scaffold.sh:20-22` (arg parsing), `skills/vibe-setup/scaffold.sh:477-485` (case dispatch + usage)
- Create (new function in the same file): `remove()`
- Test: `tests/remove_test.sh` (new)

**Interfaces:**
- Consumes: `managed_paths`, `extra_paths`, `manifest_created`, `manifest_sha`, `manifest_gitignore_line`, `sha_of_path` — all from Tasks 1-3 / pre-existing.
- Produces: `remove()` — no args (reads the new global `$APPLY`). `$APPLY` — new global int (`0`/`1`), set by the top-level arg parser when `--apply` appears anywhere in argv. `scaffold.sh remove [DIR] [--apply]` as a new CLI entry point.

This is the feature's payoff task. Dry-run and `--apply` share one classification pass (which paths are created+unchanged vs. created+edited vs. pre-existing) — they aren't separable into independently-shippable halves (a `remove` that can only print and never act isn't a complete command), so both land in one task with its own TDD cycle.

- [ ] **Step 1: Write the failing test**

Create `tests/remove_test.sh`:

```bash
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
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `bash tests/remove_test.sh`
Expected: FAIL — `scaffold.sh` doesn't recognize `remove` yet (hits the `*)` usage branch, exits 2), and `--apply` isn't parsed out of argv yet either. Most assertions should fail; scenario A's exit-code check may even fail differently (nonzero exit) since the unknown-command branch exits 2. This confirms the test is actually exercising not-yet-built behavior.

- [ ] **Step 3: Update argument parsing to recognize `--apply`**

Find:

```bash
CMD="${1:-audit}"
DIR="${2:-.}"
cd "$DIR"
```

Replace with:

```bash
APPLY=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
CMD="${ARGS[0]:-audit}"
DIR="${ARGS[1]:-.}"
cd "$DIR"
```

- [ ] **Step 4: Update the header comment**

Find:

```bash
#   scaffold.sh upgrade [DIR]     → re-apply changed managed templates to an already-set-up repo
#                                   (sha drift → UPDATE untouched / ADD missing / CONFLICT human-edited; never clobbers)
#   scaffold.sh profile [DIR]     → print only the detected stack profile (machine-readable)
```

Replace with:

```bash
#   scaffold.sh upgrade [DIR]     → re-apply changed managed templates to an already-set-up repo
#                                   (sha drift → UPDATE untouched / ADD missing / CONFLICT human-edited; never clobbers)
#   scaffold.sh remove [DIR] [--apply] → dry-run (default) or actually delete: only paths vibe-setup
#                                   created AND that are still unchanged since creation; never LLM content
#   scaffold.sh profile [DIR]     → print only the detected stack profile (machine-readable)
```

- [ ] **Step 5: Implement `remove()`**

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

case "$CMD" in
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

# ---------------------------------------------------------------- remove (dry-run varsayılan; --apply gerçek siler)
remove() {
  echo "vibe-setup remove — $(pwd)  $([ "$APPLY" = 1 ] && echo '(--apply)' || echo '(dry-run)')"
  if [ ! -f .vibe-setup.json ]; then
    echo "Manifest yok — vibe-setup bu repoda kurulu değil (ya da zaten kaldırılmış)."
    return 0
  fi

  local p created cursha mansha
  local to_remove=() kept_edited=() pre_existing_count=0

  for p in $(managed_paths) $(extra_paths); do
    [ -e "$p" ] || continue
    created="$(manifest_created "$p" 2>/dev/null || true)"
    if [ "$created" != "true" ]; then
      pre_existing_count=$((pre_existing_count+1))
      continue
    fi
    mansha="$(manifest_sha "$p" 2>/dev/null || true)"
    cursha="$(sha_of_path "$p")"
    if [ "$cursha" = "$mansha" ]; then to_remove+=("$p"); else kept_edited+=("$p"); fi
  done

  local gi gi_remove=0
  gi="$(manifest_gitignore_line 2>/dev/null || true)"
  if [ -n "$gi" ] && [ -f .gitignore ] && grep -qxF "$gi" .gitignore; then gi_remove=1; fi

  echo
  echo "SİLİNECEK (vibe-setup yarattı, değişmemiş):"
  if [ ${#to_remove[@]} -eq 0 ]; then echo "  (yok)"; else printf '  - %s\n' ${to_remove[@]+"${to_remove[@]}"}; fi
  [ "$gi_remove" = 1 ] && echo "  - .gitignore: \"$gi\" satırı"

  echo
  echo "ELLE DÜZENLENMİŞ — DOKUNULMAYACAK:"
  if [ ${#kept_edited[@]} -eq 0 ]; then echo "  (yok)"; else printf '  - %s\n' ${kept_edited[@]+"${kept_edited[@]}"}; fi

  echo
  echo "ÖNCEDEN VARDI — hiç dokunulmadı: $pre_existing_count dosya"
  echo
  echo "KAPSAM DIŞI — elle gözden geçir: CLAUDE.md, docs/, tests/, .claude/settings.json içeriği"
  echo
  echo "(varsa) git config temizliği — önerilir, otomatik yapılmadı:"
  echo "  git config --unset core.hooksPath"
  echo "  git config --unset commit.template"
  echo "  git config --unset vibe.ticketre"

  if [ "$APPLY" != 1 ]; then
    echo
    echo "Dry-run — hiçbir şey silinmedi. Uygulamak için: scaffold.sh remove . --apply"
    return 0
  fi

  for p in ${to_remove[@]+"${to_remove[@]}"}; do rm -f "$p"; done
  if [ "$gi_remove" = 1 ]; then
    grep -vxF "$gi" .gitignore > .gitignore.tmp && mv .gitignore.tmp .gitignore
  fi
  local d
  for p in ${to_remove[@]+"${to_remove[@]}"}; do
    d="$(dirname "$p")"
    while [ "$d" != "." ] && [ -d "$d" ]; do
      rmdir "$d" 2>/dev/null || break
      d="$(dirname "$d")"
    done
  done

  {
    echo "# vibe-remove report — $(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
    echo
    echo "## Silinen dosyalar"
    if [ ${#to_remove[@]} -eq 0 ] && [ "$gi_remove" != 1 ]; then
      echo "(yok)"
    else
      for p in ${to_remove[@]+"${to_remove[@]}"}; do echo "- $p"; done
      [ "$gi_remove" = 1 ] && echo "- .gitignore: \"$gi\" satırı"
    fi
    echo
    echo "## Elle düzenlenmiş — dokunulmadı"
    if [ ${#kept_edited[@]} -eq 0 ]; then
      echo "(yok)"
    else
      for p in ${kept_edited[@]+"${kept_edited[@]}"}; do echo "- $p — oluşturulduğundan beri değişmiş, silinmedi"; done
    fi
    echo
    echo "## Pre-existing — hiç dokunulmadı"
    echo "$pre_existing_count dosya vibe-setup'tan önce zaten vardı, elle silinmedi."
    echo
    echo "## Kapsam dışı — elle gözden geçir"
    echo "CLAUDE.md, docs/, tests/, .claude/settings.json içeriği (LLM tarafından dolduruldu, otomatik silinmez)."
    echo
    echo "## (varsa) git config temizliği — önerilir, otomatik yapılmadı"
    echo '```'
    echo "git config --unset core.hooksPath"
    echo "git config --unset commit.template"
    echo "git config --unset vibe.ticketre"
    echo '```'
  } > vibe-remove-report.md

  rm -f .vibe-setup.json

  echo
  echo "Silindi. Rapor: vibe-remove-report.md"
}

case "$CMD" in
```

- [ ] **Step 6: Wire the dispatch case**

Find:

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

Replace with:

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

- [ ] **Step 7: Run the test to confirm it passes**

Run: `bash tests/remove_test.sh`
Expected: `remove_test: 24 passed, 0 failed`

- [ ] **Step 8: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 9: Dogfood — dry-run on this repo itself (never actually apply against the live repo)**

Run: `bash skills/vibe-setup/scaffold.sh remove .`
Expected: runs without error. Since this repo's own `.vibe-setup.json` may or may not exist depending on prior work, either the "Manifest yok" message appears, or a classification report appears. **Do not run `--apply` against this repo** — it's a dry-run-only sanity check that the command doesn't crash on a real, non-synthetic repo; do not delete this project's own tracked files.

- [ ] **Step 10: Commit**

```bash
git add skills/vibe-setup/scaffold.sh tests/remove_test.sh
git commit -m "$(cat <<'EOF'
VIB-7 scaffold.sh: remove komutu ekle (dry-run varsayilan, --apply)

created provenance'a dayanarak sadece vibe-setup'in yarattigi VE hala
degismemis dosyalari siler; onceden var olanlara ve elle duzenlenmislere
hic dokunmaz. --apply vibe-remove-report.md yazar, .vibe-setup.json'u
en son siler. LLM icerik (CLAUDE.md/docs/tests/settings.json) ve git
config asla otomatik dokunulmaz — raporda elle-yap onerisi olarak kalir.
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:** every "Manifest schema changes" bullet (created flag, extras section, gitignoreLine) has its own task (1/2/3); every "`remove` command" requirement (dry-run default, `--apply`, classification rules, report format, empty-dir cleanup, gitignore-line removal, out-of-scope reminder, git-config-unset suggestion) is in Task 4. "Out of scope" items (no LLM auto-delete, no git-config auto-unset, no undo-history journal, no interactive per-file confirmation) are all honored by construction — nothing in any task does those things.

**Type/name consistency check:** `manifest_created`/`created_for_manifest`/`NEW_PATHS` (Task 1) are used unchanged by Task 2's extras loop and Task 4's `remove()` classification loop. `extra_paths` (Task 2) is used unchanged by Task 4. `manifest_gitignore_line`/`GITIGNORE_LINE` (Task 3) are used unchanged by Task 4. `write_manifest` signature (no args, reads globals) stays constant across Tasks 1-3, each task only growing its body. `$APPLY` (Task 4) is the only new CLI-facing global, set once at the top of the script before any command function runs.
