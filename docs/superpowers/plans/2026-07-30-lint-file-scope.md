# Lint File Scope (`LINT_FILE_OK`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the generated pre-commit hook a file-scope concept for lint (mirroring the existing `FMT_FILE_OK`), so file-oriented linters like `shellcheck` receive the staged source files instead of being invoked bare and dumping a usage error on every commit.

**Architecture:** Add `LINT_FILE_OK` as the 10th `detect_profile` field, hoist the `staged_src` computation to a single place in the hook so fmt and lint share it, and branch the lint block on the new flag. Only the `shell` profile gets `1`; every other stack keeps `0` and therefore behaves exactly as today. The template change drives a `VIBE_VERSION` 6→7 bump plus its test-fixture and dogfood fallout.

**Tech Stack:** Pure bash (`scaffold.sh`), bash test harness (`tests/*_test.sh`), shellcheck 0.11.0 (installed locally, and the CI gate is now blocking at `--severity=warning`).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-30-lint-file-scope-design.md` (VIB-16).
- `LINT_FILE_OK` contract mirrors `FMT_FILE_OK` exactly: `1` = lint accepts a file list, hook passes staged source files; `0` = whole-project only, hook runs it bare.
- **Only `shell` gets `1`.** Every other stack (go, node-biome, node-eslint, python ×3, java-maven, kotlin, java-gradle, rust, ruby, php, swift, elixir, dotnet, unknown) gets `0` — deliberate minimum blast radius, no other stack's hook behavior changes. `php`/`phpstan` stays `0` on purpose (it normally works via `phpstan.neon`; flipping it would break working setups).
- **Lint stays ADVISORY in both modes** — never sets `fail=1`. Existing philosophy (`CLAUDE.md`: fmt blocking, lint/doc-sync advisory). Making lint blocking is explicitly out of scope.
- When `LINT_FILE_OK=1` and there are no staged source files (e.g. a docs-only commit), the lint step is **skipped entirely** rather than invoked bare.
- Per `CLAUDE.md`'s "Sürüm yükseltirken 3 yer" gotcha, this managed-template change requires `VIBE_VERSION` 6→7 **and** `artifact_changed_in ".githooks/pre-commit"` → 7.
- `tests/upgrade_test.sh` hardcodes `6`/`v6` in several places; they must move to `7`/`v7` in the same task or the suite goes red for unrelated reasons. `AGENTS.md`'s own `artifact_changed_in` stays `4` — do not touch `"AGENTS.md": { "v": 4` assertions.
- The CI shellcheck gate is now **blocking** at `--severity=warning` over `skills/vibe-setup/scaffold.sh tests/*.sh scripts/*.sh .githooks/pre-commit .githooks/commit-msg` — both `scaffold.sh` and every generated hook must stay warning-clean. The generated hook's constant expressions (post-substitution `@LINTFILEOK@`) need the same `# shellcheck disable=SC2050` treatment the fmt block already has.
- This repo is itself a shell-stack install that dogfoods its own hook (`.githooks/pre-commit` + `.vibe-setup.json`, refreshed to v6 in VIB-15). It is the live reproduction case for this bug and must be regenerated to v7.
- Commit ticket key: `VIB-16`.
- Test runner: `bash tests/run.sh` from repo root.

---

### Task 1: `LINT_FILE_OK` field + hook lint branching + version bump

**Files:**
- Modify: `skills/vibe-setup/scaffold.sh` (`detect_profile` header comment + 17 printf lines, `IFS read`, `profile` output, `render_precommit`, `VIBE_VERSION`, `artifact_changed_in`)
- Modify: `tests/profile_test.sh` (new `LINT_FILE_OK` assertions)
- Modify: `tests/init_test.sh` (marker-substitution guard)
- Modify: `tests/upgrade_test.sh` (v6 → v7 fixtures)

**Interfaces:**
- Consumes: existing `FMT_FILE_OK` machinery as the pattern to mirror; existing `staged`/`@SRCRE@` in the hook template.
- Produces: `LINT_FILE_OK` as the 10th tab-separated field of `detect_profile`'s output, the 10th `KEY=value` line of `scaffold.sh profile`, and `@LINTFILEOK@` as a template marker. Task 2's documentation describes all three by these exact names.

- [ ] **Step 1: Write the failing profile assertions**

Open `tests/profile_test.sh`. Find:

```bash
[ "$(field_of "$tmp/ex" FMT_FILE_OK)" = "1" ]   && { echo "  ok: elixir FMT_FILE_OK=1"; pass=$((pass+1)); } || { echo "  FAIL: elixir FMT_FILE_OK"; fail=$((fail+1)); }
```

Replace with:

```bash
[ "$(field_of "$tmp/ex" FMT_FILE_OK)" = "1" ]   && { echo "  ok: elixir FMT_FILE_OK=1"; pass=$((pass+1)); } || { echo "  FAIL: elixir FMT_FILE_OK"; fail=$((fail+1)); }

# LINT_FILE_OK: sadece shell dosya-odakli (shellcheck dosya ister); digerleri argumansiz calisir
mkdir -p "$tmp/sh" && : > "$tmp/sh/tool.sh"
[ "$(field_of "$tmp/sh" LINT_FILE_OK)" = "1" ]   && { echo "  ok: shell LINT_FILE_OK=1"; pass=$((pass+1)); }   || { echo "  FAIL: shell LINT_FILE_OK"; fail=$((fail+1)); }
[ "$(field_of "$tmp/go" LINT_FILE_OK)" = "0" ]   && { echo "  ok: go LINT_FILE_OK=0"; pass=$((pass+1)); }      || { echo "  FAIL: go LINT_FILE_OK"; fail=$((fail+1)); }
[ "$(field_of "$tmp/rust" LINT_FILE_OK)" = "0" ] && { echo "  ok: rust LINT_FILE_OK=0"; pass=$((pass+1)); }    || { echo "  FAIL: rust LINT_FILE_OK"; fail=$((fail+1)); }
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `bash tests/profile_test.sh`
Expected: FAIL on all three new assertions — `profile` emits no `LINT_FILE_OK=` line yet, so `field_of` returns empty.

- [ ] **Step 3: Update the `detect_profile` header comment**

Find:

```bash
# Echoes: STACK MODULE_DIR FMT LINT TEST BUILD SRC_RE TEST_FIND FMT_FILE_OK  (tab-separated; "-" = none)
# FMT_FILE_OK=1 → fmt accepts a file list, so the hook checks ONLY staged files (blocking).
# FMT_FILE_OK=0 → fmt is whole-project only, so the hook runs it advisory (CI must enforce).
```

Replace with:

```bash
# Echoes: STACK MODULE_DIR FMT LINT TEST BUILD SRC_RE TEST_FIND FMT_FILE_OK LINT_FILE_OK  (tab-separated; "-" = none)
# FMT_FILE_OK=1 → fmt accepts a file list, so the hook checks ONLY staged files (blocking).
# FMT_FILE_OK=0 → fmt is whole-project only, so the hook runs it advisory (CI must enforce).
# LINT_FILE_OK=1 → lint accepts a file list (e.g. shellcheck), so the hook passes staged source files;
#                  with no staged source files the lint step is skipped entirely. Still ADVISORY.
# LINT_FILE_OK=0 → lint runs whole-project bare (go vet ./..., ruff check ., cargo clippy, ...). ADVISORY.
```

- [ ] **Step 4: Add the 10th field to all 17 `detect_profile` printf lines**

Each line gains one more tab-separated value before the closing `\n`. Only `shell` gets `1`.

Find:

```bash
  if   d="$(manifest_dir go.mod)";        [ -n "$d" ]; then printf 'go\t%s\tgofmt -l\tgo vet ./...\tgo test ./...\tgo build ./...\t\\.go$\t*_test.go\t1\n' "$d"
  elif d="$(manifest_dir package.json)";  [ -n "$d" ]; then
    if [ -f "$d/biome.json" ] || [ -f "$d/biome.jsonc" ]; then
      printf 'node\t%s\tnpx --no-install @biomejs/biome check\t-\tnpm test\tnpm run build\t\\.(js|ts|jsx|tsx)$\t*.test.*\t1\n' "$d"
    else
      printf 'node\t%s\tnpx --no-install prettier --check\tnpx --no-install eslint .\tnpm test\tnpm run build\t\\.(js|ts|jsx|tsx)$\t*.test.*\t1\n' "$d"
    fi
  elif d="$(manifest_dir pyproject.toml)";[ -n "$d" ]; then printf 'python\t%s\truff format --check\truff check .\tpytest\t-\t\\.py$\ttest_*.py\t1\n' "$d"
  elif d="$(manifest_dir setup.py)";      [ -n "$d" ]; then printf 'python\t%s\truff format --check\truff check .\tpytest\t-\t\\.py$\ttest_*.py\t1\n' "$d"
  elif d="$(manifest_dir requirements.txt)";[ -n "$d" ]; then printf 'python\t%s\truff format --check\truff check .\tpytest\t-\t\\.py$\ttest_*.py\t1\n' "$d"
  elif d="$(manifest_dir pom.xml)";       [ -n "$d" ]; then printf 'java\t%s\tmvn spotless:check\t-\tmvn test\tmvn package\t\\.java$\t*Test.java\t0\n' "$d"
  elif d="$(manifest_dir build.gradle.kts)"; [ -n "$d" ]; then printf 'kotlin\t%s\t./gradlew ktlintCheck\t-\t./gradlew test\t./gradlew build\t\\.(kt|kts)$\t*Test.kt\t0\n' "$d"
  elif d="$(manifest_dir build.gradle)";  [ -n "$d" ]; then printf 'java\t%s\t./gradlew spotlessCheck\t-\t./gradlew test\t./gradlew build\t\\.java$\t*Test.java\t0\n' "$d"
  elif d="$(manifest_dir Cargo.toml)";    [ -n "$d" ]; then printf 'rust\t%s\tcargo fmt --check\tcargo clippy\tcargo test\tcargo build\t\\.rs$\t*_test.rs\t0\n' "$d"
  elif d="$(manifest_dir Gemfile)";       [ -n "$d" ]; then printf 'ruby\t%s\trubocop\trubocop\trspec\t-\t\\.rb$\t*_spec.rb\t1\n' "$d"
  elif d="$(manifest_dir composer.json)"; [ -n "$d" ]; then printf 'php\t%s\tphp-cs-fixer fix --dry-run\tphpstan analyse\tphpunit\t-\t\\.php$\t*Test.php\t1\n' "$d"
  elif d="$(manifest_dir Package.swift)"; [ -n "$d" ]; then printf 'swift\t%s\tswiftformat --lint\tswiftlint\tswift test\tswift build\t\\.swift$\t*Tests.swift\t1\n' "$d"
  elif d="$(manifest_dir mix.exs)";       [ -n "$d" ]; then printf 'elixir\t%s\tmix format --check-formatted\tmix credo\tmix test\tmix compile\t\\.(ex|exs)$\t*_test.exs\t1\n' "$d"
  elif find . -maxdepth 3 \( -name '*.csproj' -o -name '*.sln' \) -not -path '*/.*' 2>/dev/null | grep -q .; then printf 'dotnet\t.\tdotnet format --verify-no-changes\t-\tdotnet test\tdotnet build\t\\.cs$\t*Tests.cs\t0\n'
  elif find . -maxdepth 3 -name '*.sh' -not -path '*/.*' 2>/dev/null | grep -q .; then printf 'shell\t.\tshfmt -d\tshellcheck\tbash tests/run.sh\t-\t\\.sh$\t*_test.sh\t1\n'
  else printf 'unknown\t.\t-\t-\t-\t-\t-\t-\t0\n'
  fi
```

Replace with:

```bash
  if   d="$(manifest_dir go.mod)";        [ -n "$d" ]; then printf 'go\t%s\tgofmt -l\tgo vet ./...\tgo test ./...\tgo build ./...\t\\.go$\t*_test.go\t1\t0\n' "$d"
  elif d="$(manifest_dir package.json)";  [ -n "$d" ]; then
    if [ -f "$d/biome.json" ] || [ -f "$d/biome.jsonc" ]; then
      printf 'node\t%s\tnpx --no-install @biomejs/biome check\t-\tnpm test\tnpm run build\t\\.(js|ts|jsx|tsx)$\t*.test.*\t1\t0\n' "$d"
    else
      printf 'node\t%s\tnpx --no-install prettier --check\tnpx --no-install eslint .\tnpm test\tnpm run build\t\\.(js|ts|jsx|tsx)$\t*.test.*\t1\t0\n' "$d"
    fi
  elif d="$(manifest_dir pyproject.toml)";[ -n "$d" ]; then printf 'python\t%s\truff format --check\truff check .\tpytest\t-\t\\.py$\ttest_*.py\t1\t0\n' "$d"
  elif d="$(manifest_dir setup.py)";      [ -n "$d" ]; then printf 'python\t%s\truff format --check\truff check .\tpytest\t-\t\\.py$\ttest_*.py\t1\t0\n' "$d"
  elif d="$(manifest_dir requirements.txt)";[ -n "$d" ]; then printf 'python\t%s\truff format --check\truff check .\tpytest\t-\t\\.py$\ttest_*.py\t1\t0\n' "$d"
  elif d="$(manifest_dir pom.xml)";       [ -n "$d" ]; then printf 'java\t%s\tmvn spotless:check\t-\tmvn test\tmvn package\t\\.java$\t*Test.java\t0\t0\n' "$d"
  elif d="$(manifest_dir build.gradle.kts)"; [ -n "$d" ]; then printf 'kotlin\t%s\t./gradlew ktlintCheck\t-\t./gradlew test\t./gradlew build\t\\.(kt|kts)$\t*Test.kt\t0\t0\n' "$d"
  elif d="$(manifest_dir build.gradle)";  [ -n "$d" ]; then printf 'java\t%s\t./gradlew spotlessCheck\t-\t./gradlew test\t./gradlew build\t\\.java$\t*Test.java\t0\t0\n' "$d"
  elif d="$(manifest_dir Cargo.toml)";    [ -n "$d" ]; then printf 'rust\t%s\tcargo fmt --check\tcargo clippy\tcargo test\tcargo build\t\\.rs$\t*_test.rs\t0\t0\n' "$d"
  elif d="$(manifest_dir Gemfile)";       [ -n "$d" ]; then printf 'ruby\t%s\trubocop\trubocop\trspec\t-\t\\.rb$\t*_spec.rb\t1\t0\n' "$d"
  elif d="$(manifest_dir composer.json)"; [ -n "$d" ]; then printf 'php\t%s\tphp-cs-fixer fix --dry-run\tphpstan analyse\tphpunit\t-\t\\.php$\t*Test.php\t1\t0\n' "$d"
  elif d="$(manifest_dir Package.swift)"; [ -n "$d" ]; then printf 'swift\t%s\tswiftformat --lint\tswiftlint\tswift test\tswift build\t\\.swift$\t*Tests.swift\t1\t0\n' "$d"
  elif d="$(manifest_dir mix.exs)";       [ -n "$d" ]; then printf 'elixir\t%s\tmix format --check-formatted\tmix credo\tmix test\tmix compile\t\\.(ex|exs)$\t*_test.exs\t1\t0\n' "$d"
  elif find . -maxdepth 3 \( -name '*.csproj' -o -name '*.sln' \) -not -path '*/.*' 2>/dev/null | grep -q .; then printf 'dotnet\t.\tdotnet format --verify-no-changes\t-\tdotnet test\tdotnet build\t\\.cs$\t*Tests.cs\t0\t0\n'
  elif find . -maxdepth 3 -name '*.sh' -not -path '*/.*' 2>/dev/null | grep -q .; then printf 'shell\t.\tshfmt -d\tshellcheck\tbash tests/run.sh\t-\t\\.sh$\t*_test.sh\t1\t1\n'
  else printf 'unknown\t.\t-\t-\t-\t-\t-\t-\t0\t0\n'
  fi
```

- [ ] **Step 5: Add `LINT_FILE_OK` to the `IFS read`**

Find:

```bash
IFS=$'\t' read -r STACK MODULE_DIR FMT LINT TEST BUILD SRC_RE TEST_FIND FMT_FILE_OK <<<"$PROFILE"
```

Replace with:

```bash
IFS=$'\t' read -r STACK MODULE_DIR FMT LINT TEST BUILD SRC_RE TEST_FIND FMT_FILE_OK LINT_FILE_OK <<<"$PROFILE"
```

- [ ] **Step 6: Add `LINT_FILE_OK` to the `profile` command output**

Find:

```bash
  profile) printf 'STACK=%s\nMODULE_DIR=%s\nFMT=%s\nLINT=%s\nTEST=%s\nBUILD=%s\nSRC_RE=%s\nTEST_FIND=%s\nFMT_FILE_OK=%s\nVIBE_VERSION=%s\n' "$STACK" "$MODULE_DIR" "$FMT" "$LINT" "$TEST" "$BUILD" "$SRC_RE" "$TEST_FIND" "$FMT_FILE_OK" "$VIBE_VERSION" ;;
```

Replace with:

```bash
  profile) printf 'STACK=%s\nMODULE_DIR=%s\nFMT=%s\nLINT=%s\nTEST=%s\nBUILD=%s\nSRC_RE=%s\nTEST_FIND=%s\nFMT_FILE_OK=%s\nLINT_FILE_OK=%s\nVIBE_VERSION=%s\n' "$STACK" "$MODULE_DIR" "$FMT" "$LINT" "$TEST" "$BUILD" "$SRC_RE" "$TEST_FIND" "$FMT_FILE_OK" "$LINT_FILE_OK" "$VIBE_VERSION" ;;
```

- [ ] **Step 7: Run the profile test — it should now pass**

Run: `bash tests/profile_test.sh`
Expected: `profile_test: 19 passed, 0 failed` (16 existing + 3 new), no `FAIL` lines.

- [ ] **Step 8: Hoist `staged_src` and branch the lint block in `render_precommit`**

This is the behavioral core. Find:

```bash
staged="$(git diff --cached --name-only --diff-filter=ACM || true)"
[ -z "$staged" ] && exit 0
fail=0

# 1. fmt — tool kuruluysa çalışır; file-capable ise staged-scope & blocking, değilse repo-geneli & advisory.
fmt_bin="$(printf '%s' "@FMT@" | awk '{print $1}')"
# shellcheck disable=SC2050  # @FMT@/@FMTFILEOK@ üretim anında sabitlenir — render sonrası sabit ifade normal
if [ "@FMT@" != "-" ] && command -v "$fmt_bin" >/dev/null 2>&1; then
  # shellcheck disable=SC2050
  if [ "@FMTFILEOK@" = "1" ]; then
    staged_src="$(printf '%s\n' "$staged" | grep -E '@SRCRE@' || true)"
    if [ -n "$staged_src" ]; then
```

Replace with:

```bash
staged="$(git diff --cached --name-only --diff-filter=ACM || true)"
[ -z "$staged" ] && exit 0
fail=0
# staged kaynak dosyaları — fmt ve lint aynı listeyi paylaşır (tek kaynak).
staged_src="$(printf '%s\n' "$staged" | grep -E '@SRCRE@' || true)"

# 1. fmt — tool kuruluysa çalışır; file-capable ise staged-scope & blocking, değilse repo-geneli & advisory.
fmt_bin="$(printf '%s' "@FMT@" | awk '{print $1}')"
# shellcheck disable=SC2050  # @FMT@/@FMTFILEOK@ üretim anında sabitlenir — render sonrası sabit ifade normal
if [ "@FMT@" != "-" ] && command -v "$fmt_bin" >/dev/null 2>&1; then
  # shellcheck disable=SC2050
  if [ "@FMTFILEOK@" = "1" ]; then
    if [ -n "$staged_src" ]; then
```

- [ ] **Step 9: Rewrite the lint block to honour `LINT_FILE_OK`**

Find:

```bash
# 2. lint (advisory) — tool kuruluysa
lint_bin="$(printf '%s' "@LINT@" | awk '{print $1}')"
# shellcheck disable=SC2050  # @LINT@ üretim anında sabitlenir — render sonrası sabit ifade normal
if [ "@LINT@" != "-" ] && command -v "$lint_bin" >/dev/null 2>&1; then
  lint_out="$(mktemp)"                       # sabit /tmp yolu YOK: çok-kullanıcılı makinede symlink riski + paralel commit çakışması
  @LINT@ >"$lint_out" 2>&1 || true
  [ -s "$lint_out" ] && { echo "ℹ lint (bloklamaz):" >&2; sed 's/^/  /' "$lint_out" >&2; }
  rm -f "$lint_out"
fi
```

Replace with:

```bash
# 2. lint (advisory — her iki modda da BLOKLAMAZ) — tool kuruluysa.
# LINT_FILE_OK=1 → araç dosya listesi ister (ör. shellcheck): staged kaynak dosyaları geçilir,
# staged kaynak yoksa adım tamamen atlanır (argümansız çağırıp usage hatası basmak yerine).
lint_bin="$(printf '%s' "@LINT@" | awk '{print $1}')"
# shellcheck disable=SC2050  # @LINT@/@LINTFILEOK@ üretim anında sabitlenir — render sonrası sabit ifade normal
if [ "@LINT@" != "-" ] && command -v "$lint_bin" >/dev/null 2>&1; then
  lint_out="$(mktemp)"                       # sabit /tmp yolu YOK: çok-kullanıcılı makinede symlink riski + paralel commit çakışması
  lint_ran=0
  # shellcheck disable=SC2050
  if [ "@LINTFILEOK@" = "1" ]; then
    if [ -n "$staged_src" ]; then
      # shellcheck disable=SC2086
      @LINT@ $staged_src >"$lint_out" 2>&1 || true
      lint_ran=1
    fi
  else
    @LINT@ >"$lint_out" 2>&1 || true
    lint_ran=1
  fi
  [ "$lint_ran" = 1 ] && [ -s "$lint_out" ] && { echo "ℹ lint (bloklamaz):" >&2; sed 's/^/  /' "$lint_out" >&2; }
  rm -f "$lint_out"
fi
```

- [ ] **Step 10: Add the `@LINTFILEOK@` substitution**

Find:

```bash
  t="${t//@FMTFILEOK@/$FMT_FILE_OK}"
```

Replace with:

```bash
  t="${t//@FMTFILEOK@/$FMT_FILE_OK}"
  t="${t//@LINTFILEOK@/$LINT_FILE_OK}"
```

- [ ] **Step 11: Guard against an unsubstituted marker in `tests/init_test.sh`**

Find:

```bash
grep -q '@FMT@\|@SRCRE@\|@STACK@\|@LINT@\|@FMTFILEOK@\|@VER@' "$node/.githooks/pre-commit" 2>/dev/null && bad "ikame edilmemis @marker@ kaldi" || ok "tum @marker@ ikame edildi"
```

Replace with:

```bash
grep -q '@FMT@\|@SRCRE@\|@STACK@\|@LINT@\|@FMTFILEOK@\|@LINTFILEOK@\|@VER@' "$node/.githooks/pre-commit" 2>/dev/null && bad "ikame edilmemis @marker@ kaldi" || ok "tum @marker@ ikame edildi"
```

- [ ] **Step 12: Bump `VIBE_VERSION` and `artifact_changed_in`**

Find:

```bash
VIBE_VERSION=6
```

Replace with:

```bash
VIBE_VERSION=7
```

Find:

```bash
  .githooks/pre-commit) echo 6 ;;   # v6: lint çıktısı sabit /tmp/vibe_lint yerine mktemp (symlink riski + paralel commit çakışması)
```

Replace with:

```bash
  .githooks/pre-commit) echo 7 ;;   # v7: lint dosya-scope (LINT_FILE_OK) — dosya-odaklı linter'a staged kaynaklar geçilir
```

- [ ] **Step 13: Update `tests/upgrade_test.sh`'s hardcoded version values**

Find:

```bash
grep -q '"vibeVersion": 6' "$d/.vibe-setup.json" && ok "vibeVersion=6" || bad "vibeVersion yok/yanlış"
grep -q '".githooks/pre-commit": { "v": 6' "$d/.vibe-setup.json" && ok "pre-commit v6 kayıtlı" || bad "pre-commit v kaydı yok"
```

Replace with:

```bash
grep -q '"vibeVersion": 7' "$d/.vibe-setup.json" && ok "vibeVersion=7" || bad "vibeVersion yok/yanlış"
grep -q '".githooks/pre-commit": { "v": 7' "$d/.vibe-setup.json" && ok "pre-commit v7 kayıtlı" || bad "pre-commit v kaydı yok"
```

Find:

```bash
grep -q 'vibe-setup:v6' "$d/.githooks/pre-commit" && grep -qF 'js|ts|jsx|tsx' "$d/.githooks/pre-commit" && ok "pre-commit v6 template'e yenilendi" || bad "regen içeriği yanlış"
```

Replace with:

```bash
grep -q 'vibe-setup:v7' "$d/.githooks/pre-commit" && grep -qF 'js|ts|jsx|tsx' "$d/.githooks/pre-commit" && ok "pre-commit v7 template'e yenilendi" || bad "regen içeriği yanlış"
```

Find:

```bash
grep -q '".githooks/pre-commit": { "v": 6, "sha": "[0-9]*", "created": true' "$d/.vibe-setup.json" && ok "CONFLICT'te de created:true korunur" || bad "created flag CONFLICT'te bozuldu"
```

Replace with:

```bash
grep -q '".githooks/pre-commit": { "v": 7, "sha": "[0-9]*", "created": true' "$d/.vibe-setup.json" && ok "CONFLICT'te de created:true korunur" || bad "created flag CONFLICT'te bozuldu"
```

Find:

```bash
awk '{ sub(/"vibeVersion": 6/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
printf '%s' "$out" | grep -q 'applied=v1' && ok "eski uygulanan sürüm algılandı (v1)" || bad "applied=v1 basılmadı"
grep -q '"vibeVersion": 6' "$d/.vibe-setup.json" && ok "manifest v6'ya yükseltildi" || bad "manifest sürümü yükselmedi"
```

Replace with:

```bash
awk '{ sub(/"vibeVersion": 7/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
printf '%s' "$out" | grep -q 'applied=v1' && ok "eski uygulanan sürüm algılandı (v1)" || bad "applied=v1 basılmadı"
grep -q '"vibeVersion": 7' "$d/.vibe-setup.json" && ok "manifest v7'ye yükseltildi" || bad "manifest sürümü yükselmedi"
```

Find:

```bash
  awk '{ sub(/"vibeVersion": 6/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
```

Replace with:

```bash
  awk '{ sub(/"vibeVersion": 7/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
```

Find:

```bash
awk '{ sub(/"vibeVersion": 6/, "\"vibeVersion\": 2"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
bash "$SCAFFOLD" init-cursor "$d" >/dev/null 2>&1
grep -q '"vibeVersion": 2' "$d/.vibe-setup.json" && ok "K: init-cursor eski vibeVersion'i korudu" || bad "K: init-cursor vibeVersion'i yanlislikla guncelledi"
out3="$(bash "$SCAFFOLD" audit "$d" 2>/dev/null)"
printf '%s' "$out3" | grep -q 'UPDATE_AVAILABLE=v2->v6' && ok "K: audit hala UPDATE_AVAILABLE basiyor (sinyal kaybolmadi)" || bad "K: UPDATE_AVAILABLE sinyali kayboldu"
```

Replace with:

```bash
awk '{ sub(/"vibeVersion": 7/, "\"vibeVersion\": 2"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
bash "$SCAFFOLD" init-cursor "$d" >/dev/null 2>&1
grep -q '"vibeVersion": 2' "$d/.vibe-setup.json" && ok "K: init-cursor eski vibeVersion'i korudu" || bad "K: init-cursor vibeVersion'i yanlislikla guncelledi"
out3="$(bash "$SCAFFOLD" audit "$d" 2>/dev/null)"
printf '%s' "$out3" | grep -q 'UPDATE_AVAILABLE=v2->v7' && ok "K: audit hala UPDATE_AVAILABLE basiyor (sinyal kaybolmadi)" || bad "K: UPDATE_AVAILABLE sinyali kayboldu"
```

- [ ] **Step 14: Prove the fix behaviorally — shell repo, staged `.sh` gives real findings**

Run:
```bash
t=$(mktemp -d); cd "$t"; git init -q; git config user.email t@t; git config user.name t; git config commit.gpgsign false
printf 'echo hi\n' > tool.sh
bash /Users/senaikalafat/projects/vibe-setup/skills/vibe-setup/scaffold.sh init "$t" >/dev/null 2>&1
git config core.hooksPath .githooks
echo "--- hook lint blogu ---"; sed -n '/^# 2. lint/,/^fi/p' .githooks/pre-commit
printf 'x=1\necho $undefined_var\n' >> tool.sh
git add -A
echo "--- .sh staged commit ciktisi ---"
git commit -q -m 'TST-1 kaynak' 2>&1 | grep -A5 'lint' || echo "(lint ciktisi yok)"
cd /; rm -rf "$t"
```
Expected: the hook's lint block contains `shellcheck $staged_src`; the commit output shows **real
shellcheck findings** (e.g. an `SC2154`-style note about `undefined_var`) and **no `Usage: shellcheck`
text**.

- [ ] **Step 15: Prove the skip path — docs-only commit runs no lint at all**

Run:
```bash
t=$(mktemp -d); cd "$t"; git init -q; git config user.email t@t; git config user.name t; git config commit.gpgsign false
printf 'echo hi\n' > tool.sh
bash /Users/senaikalafat/projects/vibe-setup/skills/vibe-setup/scaffold.sh init "$t" >/dev/null 2>&1
git config core.hooksPath .githooks
git add -A; git commit -q -m 'TST-1 baseline' >/dev/null 2>&1
printf '# notlar\n' > NOTES.md; git add NOTES.md
echo "--- sadece .md staged commit ciktisi ---"
git commit -q -m 'TST-2 sadece dokuman' 2>&1 | grep -i 'lint\|Usage' && echo "!!! LINT CALISTI (atlanmaliydi)" || echo "OK: lint tamamen atlandi"
cd /; rm -rf "$t"
```
Expected: `OK: lint tamamen atlandi` — no lint output and no usage text.

- [ ] **Step 16: Confirm the generated hook stays shellcheck-clean (CI gate is blocking)**

Run:
```bash
t=$(mktemp -d); printf 'echo hi\n' > "$t/tool.sh"
bash skills/vibe-setup/scaffold.sh init "$t" >/dev/null 2>&1
shellcheck --severity=warning "$t/.githooks/pre-commit"; echo "uretilen hook exit=$?"
bash -n "$t/.githooks/pre-commit" && echo "SYNTAX OK"; rm -rf "$t"
```
Expected: `uretilen hook exit=0` and `SYNTAX OK`.

- [ ] **Step 17: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 18: Run the exact CI shellcheck command**

Run: `shellcheck --severity=warning skills/vibe-setup/scaffold.sh tests/*.sh scripts/*.sh .githooks/pre-commit .githooks/commit-msg; echo "exit=$?"`
Expected: `exit=0`

- [ ] **Step 19: Commit**

```bash
git add skills/vibe-setup/scaffold.sh tests/profile_test.sh tests/init_test.sh tests/upgrade_test.sh
git commit -m "$(cat <<'EOF'
VIB-16 lint dosya-scope: LINT_FILE_OK 10. profil alani (VIBE_VERSION 6->7)

shell profilinin shellcheck'i dosya ister ama hook lint'i argumansiz
cagiriyordu -> shellcheck kurulu her shell-stack repoda her commit'te
usage hatasi basiliyordu (advisory, bloklamiyordu ama lint fiilen HIC
calismiyordu). FMT_FILE_OK ile simetrik 10. alan eklendi:
- LINT_FILE_OK=1 (sadece shell): staged kaynak dosyalari gecilir,
  staged kaynak yoksa adim tamamen atlanir
- LINT_FILE_OK=0 (diger tum stack'ler): bugunku argumansiz davranis
Lint her iki modda da ADVISORY kalir. staged_src hook'un basina
tasindi (fmt+lint tek kaynak paylasir).
EOF
)"
```

---

### Task 2: Documentation — `CLAUDE.md` + `stack-profiles.md`

**Files:**
- Modify: `CLAUDE.md` (the "9 alan" gotcha)
- Modify: `skills/vibe-setup/stack-profiles.md` (table column + "9 alan" note)

**Interfaces:**
- Consumes: `LINT_FILE_OK` from Task 1 — referenced by that exact name.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: `CLAUDE.md` — the field-count gotcha**

Find:

```markdown
- **`detect_profile` printf = 9 alan**, sonuncu `FMT_FILE_OK` (`1`=staged-scope fmt, `0`=repo-advisory).
  Alan eklersen `IFS read` satırını + `profile` çıktısını da güncelle. (`profile` komutu ayrıca `VIBE_VERSION`
  basar → 10 satır; ama `detect_profile` hâlâ 9 tab-alan.)
```

Replace with:

```markdown
- **`detect_profile` printf = 10 alan**, son ikisi `FMT_FILE_OK` (`1`=staged-scope fmt blocking,
  `0`=repo-geneli advisory) ve `LINT_FILE_OK` (`1`=lint dosya listesi alır → staged kaynaklar geçilir,
  staged kaynak yoksa adım atlanır; `0`=argümansız repo-geneli). **Lint her iki modda da advisory.**
  Bugün sadece `shell` `LINT_FILE_OK=1` (shellcheck dosya ister); diğer tüm stack'ler `0`.
  Alan eklersen `IFS read` satırını + `profile` çıktısını da güncelle. (`profile` komutu ayrıca
  `VIBE_VERSION` basar → 11 satır; ama `detect_profile` hâlâ 10 tab-alan.)
```

- [ ] **Step 2: `stack-profiles.md` — add the `lint-scope` column**

The table gains one column. Find:

```markdown
| Stack | Tespit (manifest) | fmt (check) | lint | test | build | SRC_RE | test deseni | fmt-scope |
|---|---|---|---|---|---|---|---|---|
| go | `go.mod` | `gofmt -l` | `go vet ./...` | `go test ./...` | `go build ./...` | `\.go$` | `*_test.go` | staged |
| node | `package.json` | `npx --no-install prettier --check` | `npx --no-install eslint .` | `npm test` | `npm run build` | `\.(js\|ts\|jsx\|tsx)$` | `*.test.*` | staged |
| node (biome) | `package.json` + `biome.json(c)` | `npx --no-install @biomejs/biome check` | (check kapsar) | `npm test` | `npm run build` | `\.(js\|ts\|jsx\|tsx)$` | `*.test.*` | staged |
| python | `pyproject.toml`/`setup.py`/`requirements.txt` | `ruff format --check` | `ruff check .` | `pytest` | — | `\.py$` | `test_*.py` | staged |
| java (maven) | `pom.xml` | `mvn spotless:check` | — | `mvn test` | `mvn package` | `\.java$` | `*Test.java` | repo |
| java (gradle) | `build.gradle` | `./gradlew spotlessCheck` | — | `./gradlew test` | `./gradlew build` | `\.java$` | `*Test.java` | repo |
| kotlin | `build.gradle.kts` | `./gradlew ktlintCheck` | — | `./gradlew test` | `./gradlew build` | `\.(kt\|kts)$` | `*Test.kt` | repo |
| rust | `Cargo.toml` | `cargo fmt --check` | `cargo clippy` | `cargo test` | `cargo build` | `\.rs$` | `*_test.rs` | repo |
| ruby | `Gemfile` | `rubocop` | `rubocop` | `rspec` | — | `\.rb$` | `*_spec.rb` | staged |
| dotnet | `*.csproj`/`*.sln` | `dotnet format --verify-no-changes` | — | `dotnet test` | `dotnet build` | `\.cs$` | `*Tests.cs` | repo |
| php | `composer.json` | `php-cs-fixer fix --dry-run` | `phpstan analyse` | `phpunit` | — | `\.php$` | `*Test.php` | staged |
| swift | `Package.swift` | `swiftformat --lint` | `swiftlint` | `swift test` | `swift build` | `\.swift$` | `*Tests.swift` | staged |
| elixir | `mix.exs` | `mix format --check-formatted` | `mix credo` | `mix test` | `mix compile` | `\.(ex\|exs)$` | `*_test.exs` | staged |
| shell | `*.sh` (manifest yok) | `shfmt -d` | `shellcheck` | `bash tests/run.sh` | — | `\.sh$` | `*_test.sh` | staged |
| unknown | — | — | — | — | — | — | — | — |
```

Replace with:

```markdown
| Stack | Tespit (manifest) | fmt (check) | lint | test | build | SRC_RE | test deseni | fmt-scope | lint-scope |
|---|---|---|---|---|---|---|---|---|---|
| go | `go.mod` | `gofmt -l` | `go vet ./...` | `go test ./...` | `go build ./...` | `\.go$` | `*_test.go` | staged | repo |
| node | `package.json` | `npx --no-install prettier --check` | `npx --no-install eslint .` | `npm test` | `npm run build` | `\.(js\|ts\|jsx\|tsx)$` | `*.test.*` | staged | repo |
| node (biome) | `package.json` + `biome.json(c)` | `npx --no-install @biomejs/biome check` | (check kapsar) | `npm test` | `npm run build` | `\.(js\|ts\|jsx\|tsx)$` | `*.test.*` | staged | repo |
| python | `pyproject.toml`/`setup.py`/`requirements.txt` | `ruff format --check` | `ruff check .` | `pytest` | — | `\.py$` | `test_*.py` | staged | repo |
| java (maven) | `pom.xml` | `mvn spotless:check` | — | `mvn test` | `mvn package` | `\.java$` | `*Test.java` | repo | repo |
| java (gradle) | `build.gradle` | `./gradlew spotlessCheck` | — | `./gradlew test` | `./gradlew build` | `\.java$` | `*Test.java` | repo | repo |
| kotlin | `build.gradle.kts` | `./gradlew ktlintCheck` | — | `./gradlew test` | `./gradlew build` | `\.(kt\|kts)$` | `*Test.kt` | repo | repo |
| rust | `Cargo.toml` | `cargo fmt --check` | `cargo clippy` | `cargo test` | `cargo build` | `\.rs$` | `*_test.rs` | repo | repo |
| ruby | `Gemfile` | `rubocop` | `rubocop` | `rspec` | — | `\.rb$` | `*_spec.rb` | staged | repo |
| dotnet | `*.csproj`/`*.sln` | `dotnet format --verify-no-changes` | — | `dotnet test` | `dotnet build` | `\.cs$` | `*Tests.cs` | repo | repo |
| php | `composer.json` | `php-cs-fixer fix --dry-run` | `phpstan analyse` | `phpunit` | — | `\.php$` | `*Test.php` | staged | repo |
| swift | `Package.swift` | `swiftformat --lint` | `swiftlint` | `swift test` | `swift build` | `\.swift$` | `*Tests.swift` | staged | repo |
| elixir | `mix.exs` | `mix format --check-formatted` | `mix credo` | `mix test` | `mix compile` | `\.(ex\|exs)$` | `*_test.exs` | staged | repo |
| shell | `*.sh` (manifest yok) | `shfmt -d` | `shellcheck` | `bash tests/run.sh` | — | `\.sh$` | `*_test.sh` | staged | **staged** |
| unknown | — | — | — | — | — | — | — | — | — |
```

- [ ] **Step 3: `stack-profiles.md` — explain lint-scope and update the field count**

Find:

```markdown
- **lint `—`** olanlar advisory bile çalışmaz (ekosistemde standart araç yok / opsiyonel).
```

Replace with:

```markdown
- **lint `—`** olanlar advisory bile çalışmaz (ekosistemde standart araç yok / opsiyonel).
- **lint-scope.** `repo` → araç argümansız bütün-proje çalışır (`go vet ./...`, `ruff check .`,
  `cargo clippy`…). `staged` → araç dosya listesi ister (shellcheck): hook staged kaynak dosyalarını
  geçer, staged kaynak yoksa adımı tamamen atlar. **Lint her iki modda da advisory** (bloklamaz);
  lint-scope sadece "araca ne geçilir" sorusunu yanıtlar, fmt-scope'un aksine blocking'i etkilemez.
```

Find:

```markdown
- **Yeni stack eklemek:** `scaffold.sh::detect_profile`'a bir `printf` satırı (9 alan: son alan `FMT_FILE_OK`)
  + bu tabloya bir satır. Kanonik kaynak script; bu tablo onun insan-okur dökümü (senkron tut).
```

Replace with:

```markdown
- **Yeni stack eklemek:** `scaffold.sh::detect_profile`'a bir `printf` satırı (10 alan: son ikisi
  `FMT_FILE_OK` ve `LINT_FILE_OK`) + bu tabloya bir satır. Kanonik kaynak script; bu tablo onun
  insan-okur dökümü (senkron tut).
```

- [ ] **Step 4: Verify both docs are consistent with the code**

Run: `grep -n 'LINT_FILE_OK\|lint-scope\|10 alan' CLAUDE.md skills/vibe-setup/stack-profiles.md`
Expected: at least 5 matching lines across the two files (CLAUDE.md: the gotcha; stack-profiles.md: table header, shell row context, the lint-scope note, the "10 alan" note).

- [ ] **Step 5: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md skills/vibe-setup/stack-profiles.md
git commit -m "$(cat <<'EOF'
VIB-16 CLAUDE.md/stack-profiles: LINT_FILE_OK'i dokumante et

"detect_profile printf = 9 alan" gotcha'si 10 alana guncellendi
(profile ciktisi artik 11 satir). stack-profiles tablosuna lint-scope
sutunu + lint'in her iki modda da advisory kaldigini aciklayan not.
EOF
)"
```

---

### Task 3: Dogfood — regenerate this repo's own hook at v7

**Files:**
- Modify: `.githooks/pre-commit` (regenerated from the v7 template)
- Modify: `.vibe-setup.json` (refreshed manifest)

**Interfaces:**
- Consumes: the v7 template from Task 1 — must run after it.
- Produces: nothing consumed by later tasks — final task.

This repo is shell-stack, so it is the live reproduction case: before this change its own commits emit
shellcheck usage noise. VIB-15 established the dogfood invariant (own hook stamped and manifest-tracked);
leaving it at v6 would immediately re-open that gap.

- [ ] **Step 1: Regenerate the hook from the current template**

Run:
```bash
t=$(mktemp -d); printf 'echo hi\n' > "$t/tool.sh"
bash skills/vibe-setup/scaffold.sh init "$t" >/dev/null 2>&1
cp "$t/.githooks/pre-commit" .githooks/pre-commit
chmod +x .githooks/pre-commit
rm -rf "$t"
grep -n 'vibe-setup:v\|staged_src\|shellcheck \$staged_src' .githooks/pre-commit
bash -n .githooks/pre-commit && echo "SYNTAX OK"
```
Expected: shows `vibe-setup:v7`, the hoisted `staged_src` assignment, a `shellcheck $staged_src`
invocation in the lint block, and `SYNTAX OK`.

- [ ] **Step 2: Refresh the manifest**

Run:
```bash
rm -f .vibe-setup.json
bash skills/vibe-setup/scaffold.sh init . 2>&1 | tail -3
```
Expected: all managed files report `SKIP`, ending with a `MANIFEST .vibe-setup.json (v7 …)` line.

- [ ] **Step 3: Verify the version state is clean**

Run: `bash skills/vibe-setup/scaffold.sh upgrade . 2>&1 | grep -E 'applied|UPDATE=|ADD=|CONFLICT=|legacy'`
Expected: `applied=v7 → engine=v7`, `UPDATE=` empty, no `legacy` line. `CONFLICT=` may still list
`docs/architecture/decisions/0000-template.md` (genuinely hand-edited) — correct never-clobber behavior.

- [ ] **Step 4: Prove the bug is gone in this repo's own commits**

Run:
```bash
printf '\n' >> README.md && git add README.md
git commit -m "VIB-16 dogfood dogrulama" 2>&1 | grep -i 'Usage: shellcheck' && echo "!!! GURULTU HALA VAR" || echo "OK: shellcheck usage gurultusu yok"
git reset --soft HEAD~1 && git restore --staged README.md && git checkout -- README.md
```
Expected: `OK: shellcheck usage gurultusu yok`. The trailing commands undo the throwaway commit and
restore `README.md`, leaving the tree exactly as it was.

- [ ] **Step 5: Run the full suite and the CI lint command**

Run:
```bash
bash tests/run.sh 2>&1 | tail -2
shellcheck --severity=warning skills/vibe-setup/scaffold.sh tests/*.sh scripts/*.sh .githooks/pre-commit .githooks/commit-msg; echo "shellcheck exit=$?"
```
Expected: `ALL TESTS PASSED` and `shellcheck exit=0`.

- [ ] **Step 6: Commit**

```bash
git add .githooks/pre-commit .vibe-setup.json
git commit -m "$(cat <<'EOF'
VIB-16 dogfood: kendi hook'unu v7'ye yenile (lint artik gercekten calisiyor)

Bu repo shell-stack, yani bug'in canli ureme vakasiydi: her commit'te
shellcheck usage hatasi basiyordu. v7 sablonundan yeniden uretildi;
lint artik staged .sh dosyalari uzerinde GERCEK bulgu uretiyor,
dokuman-only commit'lerde ise tamamen atlaniyor. Manifest v7'ye
tazelendi (VIB-15'te kurulan dogfood degismezi korunuyor).
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:** Kapsam kararı 1 (10. alan) → Task 1 Steps 3-6. Karar 2 (sadece shell=1) → Task 1 Step 4 (tablo değerleri) + Task 1 Step 1 (test). Karar 3 (advisory kalır + staged yoksa atla) → Task 1 Step 9 (`lint_ran` mantığı) + Step 15 (davranış kanıtı). Karar 4 (`staged_src` tek kaynak) → Task 1 Step 8. Karar 5 (sürüm etkisi) → Task 1 Steps 12-13. Karar 6 (dogfood) → Task 3. Karar 7 (dokümantasyon) → Task 2. Kapsam dışı maddeler (lint blocking, php davranışı, MODULE_DIR scope) — hiçbir task bunlara dokunmuyor.

**Placeholder scan:** TBD/TODO yok; her adım ya tam dosya içeriği ya birebir find/replace metni gösteriyor. `detect_profile`'ın 17 printf satırı tek tek yazıldı ("benzer şekilde güncelle" yok) çünkü her satırın alan sırası farklı ve yanlış yere eklenen bir tab sessiz bir profil bozulması demek.

**Type/name consistency:** `LINT_FILE_OK` (profil alanı / `profile` çıktısı anahtarı) ve `@LINTFILEOK@` (template marker) ayrımı tutarlı — Task 1 Step 4/5/6 alanı, Step 9/10 marker'ı, Step 11 marker guard'ını kullanıyor; Task 2 dokümanları alan adını kullanıyor. `VIBE_VERSION=7` / `artifact_changed_in → 7` / `vibe-setup:v7` / `"vibeVersion": 7` Task 1 kodu, Task 1 testleri ve Task 3 doğrulamaları arasında tutarlı. `AGENTS.md`'nin ayrı `v: 4` değeri Global Constraints'te açıkça dışarıda bırakıldı.

**Risk notu:** Task 1 Step 8'de `staged_src` yukarı taşınırken fmt bloğundaki eski hesaplama satırı SİLİNİYOR (yeni yerinde tekrar hesaplanmıyor) — Find/Replace bloğu bunu birebir gösteriyor. doc-sync bloğundaki bağımsız `grep -qE '@SRCRE@'` kontrolüne kasıtlı olarak dokunulmuyor (aynı bilgiyi üretiyor ama davranışı değiştirme riski almadan diff'i dar tutmak için).
