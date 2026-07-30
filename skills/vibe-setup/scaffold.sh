#!/usr/bin/env bash
# vibe-setup scaffold engine — stack-agnostic.
#
#   scaffold.sh audit [DIR]       → readiness table (✅/❌/—) + machine-readable SCORE=N/M footer
#   scaffold.sh init  [DIR]       → drop missing agnostic skeletons (never overwrites) + write .vibe-setup.json
#   scaffold.sh init-cursor [DIR] → drop Cursor rules (.cursor/rules/*.mdc + .cursorrules → CLAUDE.md)
#   scaffold.sh init-gemini [DIR] → drop Gemini CLI context file (GEMINI.md → @CLAUDE.md import)
#   scaffold.sh init-aider [DIR]  → drop Aider config (.aider.conf.yml → read: AGENTS.md)
#   scaffold.sh upgrade [DIR]     → re-apply changed managed templates to an already-set-up repo
#                                   (sha drift → UPDATE untouched / ADD missing / CONFLICT human-edited; never clobbers)
#   scaffold.sh remove [DIR] [--apply] → dry-run (default) or actually delete: only paths vibe-setup
#                                   created AND that are still unchanged since creation; never LLM content
#   scaffold.sh profile [DIR]     → print only the detected stack profile (machine-readable)
#
# The LLM-driven part (filling CLAUDE.md prose, real tests, deny paths, CONFLICT merges) is the SKILL's job;
# this script only does deterministic detection + agnostic boilerplate + stack-command substitution + drift detection.
set -euo pipefail

# Şema versiyonu (tamsayı). Bir managed template VEYA migration değiştiğinde +1; artifact_changed_in'i de güncelle.
# plugin.json semver'i ayrı (marketplace); bu sayı upgrade/migration anahtarıdır.
VIBE_VERSION=5

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

# ---------------------------------------------------------------- stack detection + profile
# Project artifacts (CLAUDE.md, docs/, hooks...) live at repo ROOT.
# The stack manifest + tests may live in a MODULE_DIR (root or a subdir like src/, app/, backend/).
# manifest_dir <filename> → dir containing it (root preferred, else nearest within depth 3), or "".
manifest_dir() {
  [ -f "$1" ] && { echo "."; return; }
  find . -maxdepth 3 -name "$1" -not -path '*/.*' -not -path '*/node_modules/*' -not -path '*/vendor/*' 2>/dev/null \
    | head -1 | sed 's#/[^/]*$##; s#^$#.#'
}

# Echoes: STACK MODULE_DIR FMT LINT TEST BUILD SRC_RE TEST_FIND FMT_FILE_OK  (tab-separated; "-" = none)
# FMT_FILE_OK=1 → fmt accepts a file list, so the hook checks ONLY staged files (blocking).
# FMT_FILE_OK=0 → fmt is whole-project only, so the hook runs it advisory (CI must enforce).
detect_profile() {
  local d
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
}

PROFILE="$(detect_profile)"
IFS=$'\t' read -r STACK MODULE_DIR FMT LINT TEST BUILD SRC_RE TEST_FIND FMT_FILE_OK <<<"$PROFILE"

# ---------------------------------------------------------------- helpers
has_file() { [ -e "$1" ]; }
has_glob() { compgen -G "$1" >/dev/null 2>&1; }
git_cfg()  { git config --local "$1" 2>/dev/null || true; }
have()     { command -v "$1" >/dev/null 2>&1; }
jq_key()   { have jq && [ -f "$1" ] && jq -e "$2" "$1" >/dev/null 2>&1; }
has_test() { [ "$TEST_FIND" = "-" ] && return 1; find "$MODULE_DIR" -name "$TEST_FIND" -not -path '*/.*' 2>/dev/null | grep -q .; }
sha_of_path() { cksum < "$1" | awk '{print $1}'; }   # CRC32 — değişiklik tespiti için yeterli (jq/sha gerekmez)

# PR/MR template yolu — VCS'e göre (GitLab `.gitlab/...`, GitHub `.github/`).
pr_template_path() {
  local u; u="$(git config --get remote.origin.url 2>/dev/null || true)"
  if printf '%s' "$u" | grep -qi gitlab || [ -d .gitlab ]; then echo ".gitlab/merge_request_templates/Default.md"
  else echo ".github/pull_request_template.md"; fi
}
# Engine'in ürettiği agnostik managed dosyalar (repo kökünde; PR yolu VCS'e göre).
managed_paths() {
  printf '%s\n' AGENTS.md docs/README.md docs/architecture/decisions/0000-template.md \
    .gitmessage .githooks/pre-commit .githooks/commit-msg .claude/settings.json "$(pr_template_path)"
}
managed_present() { local p; for p in $(managed_paths); do [ -e "$p" ] && return 0; done; return 1; }
# init-cursor/init-gemini'nin düşürdüğü "extra" dosyalar — managed_paths'e GİRMEZ (versiyon/drift takibi yok,
# audit satırı yok), ama remove'un provenance'ı için manifestin ayrı extras bölümünde kaydedilir.
extra_paths() {
  printf '%s\n' .cursor/rules/project.mdc .cursorrules GEMINI.md .aider.conf.yml
}
# Her artifact en son hangi VIBE_VERSION'da değişti (stamp + manifest v + upgrade raporu için).
artifact_changed_in() { case "$1" in
  .githooks/pre-commit) echo 5 ;;   # v5: doc-sync STRICT_DOCS env-var yerine git config vibe.strictdocs (kalıcı, vibe.ticketre ile aynı desen)
  .githooks/commit-msg) echo 3 ;;   # v3: ticket-key hard-coded → opsiyonel (git config vibe.ticketre; ayarsız = bloklamaz)
  .gitmessage)          echo 3 ;;   # v3: ticket-key opsiyonel ibaresi
  AGENTS.md)            echo 4 ;;   # v4: Gemini AGENTS.md okumaz iddiası düzeltildi; Codex/Kimi Code isimlendirildi
  *) echo 1 ;;
esac ; }
# synced = engine sürdürür (template drift → update/conflict). seed = bir kez düşer, sonra kullanıcı sahibi (drift normal).
artifact_class() { case "$1" in
  AGENTS.md|docs/architecture/decisions/0000-template.md|.githooks/pre-commit|.githooks/commit-msg) echo synced ;;
  *) echo seed ;;   # docs/README.md (LLM doldurur), .gitmessage (ticket uyarlanır), settings.json (LLM doldurur), PR/MR
esac ; }

OK="✅"; NO="❌"; NA="—"
PASS=0; TOTAL=0
row() {
  case "$1" in
    "$OK") PASS=$((PASS+1)); TOTAL=$((TOTAL+1)) ;;
    "$NO") TOTAL=$((TOTAL+1)) ;;
  esac
  printf '  %s  %-34s %s\n' "$1" "$2" "${3:-}"
}

# ---------------------------------------------------------------- audit
audit() {
  echo "vibe-setup audit — $(pwd)"
  echo "stack: $STACK  (module: $MODULE_DIR)  | fmt: $FMT | test: $TEST"
  local av=""; [ -f .vibe-setup.json ] && av="$(manifest_version)"
  if [ -n "$av" ]; then
    if   [ "$av" -lt "$VIBE_VERSION" ]; then echo "applied: v$av → engine: v$VIBE_VERSION — YENİ SÜRÜM VAR (scaffold.sh upgrade .)"
    elif [ "$av" -gt "$VIBE_VERSION" ]; then echo "applied: v$av > engine: v$VIBE_VERSION — repo daha yeni sürümle kurulmuş; SKILL'İ güncelle"
    else echo "applied: v$av (engine v$VIBE_VERSION) — güncel"; fi
  fi
  echo
  echo "BAĞLAM"
  has_file CLAUDE.md   && row "$OK" "CLAUDE.md" || row "$NO" "CLAUDE.md" "LLM: oluştur (komut+mimari+gotchas)"
  if has_file AGENTS.md; then row "$OK" "AGENTS.md"
  elif has_file AGENT.md; then row "$NO" "AGENTS.md" "legacy AGENT.md bulundu — init migrate eder (mv+symlink)"
  else row "$NO" "AGENTS.md" "init düşürür"; fi
  has_file llms.txt    && row "$OK" "llms.txt (ops)" || row "$NA" "llms.txt (ops)" "opsiyonel: dış LLM tüketicisi varsa"
  has_file README.md   && row "$OK" "README.md" || row "$NO" "README.md" "yok"
  if ! has_file README.md; then row "$NA" "README mimari diagramı" "README.md yok"
  elif grep -q '```mermaid' README.md; then row "$OK" "README mimari diagramı"
  else row "$NO" "README mimari diagramı" "LLM: üst-seviye özet diagram ekle (dış bağlantılar + ne iş yaptığı) — docs/architecture/overview.md'ye detay linki ver"
  fi
  echo "BİLGİ TABANI"
  has_file docs/README.md && row "$OK" "docs/ index" || row "$NO" "docs/README.md" "init düşürür"
  has_file docs/architecture/decisions/0000-template.md && row "$OK" "ADR template" || row "$NO" "ADR 0000-template" "init düşürür"
  echo "YAPI / DOĞRULAMA"
  if [ "$TEST_FIND" = "-" ]; then row "$NA" "test suite" "stack bilinmiyor"
  elif has_test; then row "$OK" "test suite ($TEST_FIND)"
  else row "$NO" "test suite" "LLM: gerçek test yaz ($STACK)"; fi
  echo "EKLENTİ / HOOK"
  have context-mode && row "$OK" "context-mode" || row "$NO" "context-mode" "npm install -g context-mode"
  has_file .githooks/pre-commit && row "$OK" ".githooks/pre-commit" || row "$NO" ".githooks/pre-commit" "init düşürür"
  has_file .githooks/commit-msg && row "$OK" ".githooks/commit-msg" || row "$NO" ".githooks/commit-msg" "init düşürür (ticket-key ops: vibe.ticketre)"
  [ -n "$(git_cfg core.hooksPath)" ] && row "$OK" "core.hooksPath" "$(git_cfg core.hooksPath)" || row "$NO" "core.hooksPath" "git config core.hooksPath .githooks"
  has_file .claude/settings.json && row "$OK" ".claude/settings.json" || row "$NO" ".claude/settings.json" "init düşürür"
  if have jq; then
    jq_key .claude/settings.json '.permissions.allow|length>0' && row "$OK" "permissions.allow" || row "$NO" "permissions.allow" "LLM: stack komutları"
    jq_key .claude/settings.json '.permissions.deny|length>0'  && row "$OK" "permissions.deny"  || row "$NO" "permissions.deny"  "LLM: token-bombası yolları"
  else
    row "$NA" "permissions.allow" "jq yok — atlandı"
    row "$NA" "permissions.deny"  "jq yok — atlandı"
  fi
  echo "İŞ AKIŞI"
  has_file .gitmessage && row "$OK" ".gitmessage" || row "$NO" ".gitmessage" "init düşürür"
  { has_file .github/pull_request_template.md || has_glob '.gitlab/merge_request_templates/*'; } && row "$OK" "PR/MR template" || row "$NO" "PR/MR template" "init düşürür"
  echo
  echo "SCORE=$PASS/$TOTAL"
  # Makine-okur sürüm sinyali — skill bunu görünce kullanıcıya "upgrade edeyim mi?" diye SORAR.
  [ -n "$av" ] && [ "$av" -lt "$VIBE_VERSION" ] && echo "UPDATE_AVAILABLE=v$av->v$VIBE_VERSION"
  # MODULE_DIR != . veya birden çok manifest → muhtemelen monorepo/polyglot; script tek stack tespit eder.
  if [ "$MODULE_DIR" != "." ]; then
    echo "Not: nested module ($MODULE_DIR). Monorepo/polyglot ise ek stack'leri elle teyit et — script ilk eşleşeni alır."
  fi
  echo "Sonraki: 'scaffold.sh init' agnostik iskeletleri düşürür; 'LLM:' maddelerini skill doldurur. Zaten kuruluysa: 'scaffold.sh upgrade'."
}

# ---------------------------------------------------------------- managed artifact rendering (TEK kaynak)
# Üretilen agnostik dosyaların kanonik içeriği burada; init yazar, upgrade kıyaslar. Stamp marker'ı
# "vibe-setup:vN (managed)" gömülür (N=artifact_changed_in). settings.json JSON → stamp'siz (provenance = manifest sha).
emit() { local t; t="$(cat)"; printf '%s\n' "${t//@VER@/$(artifact_changed_in "$1")}"; }   # stdin=template, @VER@→sürüm

render_precommit() {
  local t
  t="$(cat <<'EOF'
#!/usr/bin/env bash
# vibe-setup:v@VER@ (managed; elle düzenlersen upgrade EZMEZ → CONFLICT → LLM merge)
# Repo-tracked pre-commit — herkes için (insan + AI). Enable: git config core.hooksPath .githooks
# Stack: @STACK@ | doc-sync'i blocking yap: git config vibe.strictdocs true | Bypass tümü: --no-verify
# fmt: file-capable stack'te SADECE staged dosyalar (blocking); değilse repo-geneli (advisory, CI zorlasın).
set -euo pipefail
staged="$(git diff --cached --name-only --diff-filter=ACM || true)"
[ -z "$staged" ] && exit 0
fail=0

# 1. fmt — tool kuruluysa çalışır; file-capable ise staged-scope & blocking, değilse repo-geneli & advisory.
fmt_bin="$(printf '%s' "@FMT@" | awk '{print $1}')"
if [ "@FMT@" != "-" ] && command -v "$fmt_bin" >/dev/null 2>&1; then
  if [ "@FMTFILEOK@" = "1" ]; then
    staged_src="$(printf '%s\n' "$staged" | grep -E '@SRCRE@' || true)"
    if [ -n "$staged_src" ]; then
      # shellcheck disable=SC2086
      if ! out="$(@FMT@ $staged_src 2>&1)"; then
        echo "✗ fmt (staged): hata/formatlı değil:" >&2; printf '%s\n' "$out" | sed 's/^/  /' >&2; fail=1
      elif [ -n "$out" ]; then
        echo "✗ fmt (staged): formatlı değil:" >&2; printf '%s\n' "$out" | sed 's/^/  /' >&2; fail=1
      fi
    fi
  else
    if ! out="$(@FMT@ 2>&1)" || [ -n "$out" ]; then
      echo "ℹ fmt (bloklamaz, repo-geneli — CI zorlasın):" >&2; printf '%s\n' "$out" | sed 's/^/  /' >&2
    fi
  fi
fi

# 2. lint (advisory) — tool kuruluysa
lint_bin="$(printf '%s' "@LINT@" | awk '{print $1}')"
if [ "@LINT@" != "-" ] && command -v "$lint_bin" >/dev/null 2>&1; then
  @LINT@ >/tmp/vibe_lint 2>&1 || true
  [ -s /tmp/vibe_lint ] && { echo "ℹ lint (bloklamaz):" >&2; sed 's/^/  /' /tmp/vibe_lint >&2; }
fi

# 3. doc-sync (advisory default; git config vibe.strictdocs true → blocking) — kaynak değişti,
#    doküman değişmediyse. vibe.ticketre ile AYNI desen: repo-local git config, kalıcı.
src=0; printf '%s\n' "$staged" | grep -qE '@SRCRE@' && src=1
doc=0; printf '%s\n' "$staged" | grep -qE '(^docs/.*\.md$|(^|/)(README|CLAUDE|AGENTS)\.md$)' && doc=1
if [ "$src" = 1 ] && [ "$doc" = 0 ]; then
  echo "ℹ doc-sync: kaynak değişti, doküman güncellenmedi. docs/ + README/CLAUDE/AGENTS gözden geçir." >&2
  strict="$(git config --get --bool vibe.strictdocs 2>/dev/null || echo false)"
  [ "$strict" = "true" ] && { echo "  vibe.strictdocs=true → blocking." >&2; fail=1; }
fi
exit "$fail"
EOF
)"
  t="${t//@VER@/$(artifact_changed_in .githooks/pre-commit)}"
  t="${t//@FMT@/$FMT}"
  t="${t//@LINT@/$LINT}"
  t="${t//@SRCRE@/$SRC_RE}"
  t="${t//@STACK@/$STACK}"
  t="${t//@FMTFILEOK@/$FMT_FILE_OK}"
  printf '%s\n' "$t"
}

render_artifact() {  # $1 = managed path → kanonik güncel içerik (stdout); bilinmeyen path → return 1
  case "$1" in
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
    docs/README.md) emit "$1" <<'EOF'
# Dokümantasyon

Tüm dokümantasyonun giriş noktası.

## Mimari
- [Genel Bakış](architecture/overview.md) <TODO>
- [Mimari Kararlar (ADR)](architecture/decisions/) — neden böyle yapıldı

## Domain
- [Sözlük](domain/glossary.md) <TODO>
EOF
    ;;
    docs/architecture/decisions/0000-template.md) emit "$1" <<'EOF'
<!-- vibe-setup:v@VER@ (managed) -->
# N. <Karar başlığı>

- Status: proposed | accepted | superseded
- Date: YYYY-MM-DD

## Context
<Hangi problem / kısıt?>

## Decision
<Ne karar verdik?>

## Consequences
<Artılar, eksiler, takaslar.>
EOF
    ;;
    .gitmessage) emit "$1" <<'EOF'
# <ABC-1234> kısa özet (emir kipi, küçük harf)
# Ticket key OPSİYONEL — zorlamak istersen: git config vibe.ticketre '^[A-Z]{3}-[0-9]{1,4} '
#
# Neden / ne değişti:
#
EOF
    ;;
    .githooks/pre-commit) render_precommit ;;
    .githooks/commit-msg) emit "$1" <<'EOF'
#!/usr/bin/env bash
# vibe-setup:v@VER@ (managed; elle düzenlersen upgrade EZMEZ → CONFLICT → LLM merge)
# Ticket-key OPSİYONEL — zorlamak için repo'da bir kez desen tanımla:
#   git config vibe.ticketre '^[A-Z]{3}-[0-9]{1,4} '   # ör. VAN-3195; kendi regex'in de olur
# Ayarsızsa hook hiçbir şeyi bloklamaz. Merge/Revert/fixup/squash muaf. Bypass: git commit --no-verify
set -euo pipefail
re="$(git config --get vibe.ticketre 2>/dev/null || true)"
[ -z "$re" ] && exit 0
subject="$(grep -vE '^[[:space:]]*#' "$1" | grep -vE '^[[:space:]]*$' | head -1 || true)"
case "$subject" in Merge*|Revert*|fixup!*|squash!*) exit 0 ;; esac
if ! printf '%s' "$subject" | grep -qE "$re"; then
  echo "✗ commit-msg: konu 'vibe.ticketre' desenine uymalı: $re" >&2
  echo "  Gelen: ${subject:-<boş>}" >&2
  echo "  Bypass (merge/acil): git commit --no-verify | Zorlamayı kaldır: git config --unset vibe.ticketre" >&2
  exit 1
fi
EOF
    ;;
    .claude/settings.json) cat <<'EOF'
{
  "permissions": {
    "allow": [],
    "deny": []
  }
}
EOF
    ;;
    .github/pull_request_template.md|.gitlab/merge_request_templates/Default.md) emit "$1" <<'EOF'
<!-- vibe-setup:v@VER@ (managed) -->
## Ne / Neden
<Değişiklik ve gerekçe.>

## Nasıl test edildi
<Komut + sonuç.>

## Checklist
- [ ] fmt/lint/test geçiyor
- [ ] doküman güncel (docs/ + README/CLAUDE/AGENTS gerekiyorsa)
EOF
    ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------- version manifest (.vibe-setup.json)
manifest_version() { [ -f .vibe-setup.json ] && grep -oE '"vibeVersion"[[:space:]]*:[[:space:]]*[0-9]+' .vibe-setup.json | grep -oE '[0-9]+' | head -1; }
manifest_sha()     { [ -f .vibe-setup.json ] && grep -F "\"$1\":" .vibe-setup.json | grep -oE '"sha"[[:space:]]*:[[:space:]]*"[0-9]+"' | grep -oE '[0-9]+' | head -1; }
manifest_v()       { [ -f .vibe-setup.json ] && grep -F "\"$1\":" .vibe-setup.json | grep -oE '"v"[[:space:]]*:[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | head -1; }
manifest_created() { [ -f .vibe-setup.json ] && grep -F "\"$1\":" .vibe-setup.json | grep -oE '"created"[[:space:]]*:[[:space:]]*(true|false)' | grep -oE 'true|false' | head -1; }
manifest_gitignore_line() { [ -f .vibe-setup.json ] && grep -oE '"gitignoreLine"[[:space:]]*:[[:space:]]*"[^"]*"' .vibe-setup.json | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/' | head -1; }

WRITTEN_PATHS=""    # write_managed/write_extra + upgrade'in UPDATE dalı BU ÇALIŞTIRMADA gerçekten yazdığı yolları
                    # doldurur. sha/v için TEK doğru "bu çalıştırma neyi değiştirdi" sinyali — write_manifest her
                    # komuttan (init/upgrade/init-cursor/init-gemini) çağrıldığı için, bunun DIŞINDAKİ her yol
                    # manifestteki ÖNCEKİ değerini korur; yoksa örn. init-cursor, arada elle düzenlenmiş bir
                    # managed dosyayı "blessed" ederdi (remove onu güvenle silinebilir sanırdı — VERİ KAYBI).
NEW_PATHS=""        # write_managed/write_extra bu ÇALIŞTIRMADA "NEW" basılan yolları doldurur (created:true tespiti için)
GITIGNORE_LINE=""   # init bu ÇALIŞTIRMADA .gitignore'a satır eklediyse doldurur; boşsa write_manifest eski kaydı korur
STAMP_VERSION=0     # sadece init/upgrade 1 yapar — repo'nun "kurulu sürüm" imzasının sahibi bunlar; init-cursor/
                    # init-gemini eski vibeVersion'ı korur (yoksa audit'in UPDATE_AVAILABLE sinyali kaybolur)
sha_for_manifest() {
  case " $WRITTEN_PATHS " in
    *" $1 "*) sha_of_path "$1" ;;
    *) manifest_sha "$1" 2>/dev/null || sha_of_path "$1" ;;
  esac
}
v_for_manifest() {
  case " $WRITTEN_PATHS " in
    *" $1 "*) artifact_changed_in "$1" ;;
    *)
      local prior; prior="$(manifest_v "$1" 2>/dev/null || true)"
      if [ -n "$prior" ]; then echo "$prior"; else artifact_changed_in "$1"; fi
      ;;
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
write_manifest() {
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
  local paths=() p; for p in $(managed_paths); do [ -e "$p" ] && paths+=("$p"); done
  local extras=(); for p in $(extra_paths); do [ -e "$p" ] && extras+=("$p"); done
  local gi; gi="$GITIGNORE_LINE"
  [ -z "$gi" ] && gi="$(manifest_gitignore_line 2>/dev/null || true)"
  local vv="$VIBE_VERSION"
  if [ "$STAMP_VERSION" != 1 ]; then
    local priorvv; priorvv="$(manifest_version 2>/dev/null || true)"
    [ -n "$priorvv" ] && vv="$priorvv"
  fi
  # ÖNCE body'yi kur (eski .vibe-setup.json hâlâ dururken sha_for_manifest/v_for_manifest eski değerleri okur),
  # SONRA tek seferde yaz — yoksa `> file` redirect'i dosyayı baştan trunc eder, eski değerler kaybolur.
  local body; body="$(
    echo "{"
    echo "  \"vibeVersion\": $vv,"
    echo "  \"stack\": \"$STACK\","
    echo "  \"generatedAt\": \"$ts\","
    echo "  \"managed\": {"
    local n=${#paths[@]} i=0 sep
    for p in ${paths[@]+"${paths[@]}"}; do
      i=$((i+1)); sep=","; [ "$i" -eq "$n" ] && sep=""
      printf '    "%s": { "v": %s, "sha": "%s", "created": %s }%s\n' "$p" "$(v_for_manifest "$p")" "$(sha_for_manifest "$p")" "$(created_for_manifest "$p")" "$sep"
    done
    echo "  },"
    echo "  \"extras\": {"
    local en=${#extras[@]} ei=0 esep
    for p in ${extras[@]+"${extras[@]}"}; do
      ei=$((ei+1)); esep=","; [ "$ei" -eq "$en" ] && esep=""
      printf '    "%s": { "sha": "%s", "created": %s }%s\n' "$p" "$(sha_for_manifest "$p")" "$(created_for_manifest "$p")" "$esep"
    done
    echo "  },"
    if [ -n "$gi" ]; then
      printf '  "gitignoreLine": "%s",\n' "$gi"
    fi
    echo "  \"llm\": [\"CLAUDE.md\", \"docs/\", \"tests/\"]"
    echo "}"
  )"
  printf '%s\n' "$body" > .vibe-setup.json
}

# ---------------------------------------------------------------- init (agnostic skeletons; never overwrite)
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

  if [ -f .gitignore ] && ! grep -q 'settings.local.json' .gitignore; then
    printf '\n.claude/settings.local.json\n' >> .gitignore; echo "  EDIT  .gitignore (+settings.local.json)"
    GITIGNORE_LINE=".claude/settings.local.json"
  fi

  write_manifest
  echo "  MANIFEST .vibe-setup.json (v$VIBE_VERSION — upgrade için sürüm/sha kaydı)"

  echo
  echo "Agnostik iskeletler hazır. STACK-BAĞIMLI (skill/LLM doldurur):"
  echo "  - CLAUDE.md (komutlar: fmt='$FMT' test='$TEST' build='$BUILD'; mimari; gotchas)"
  echo "  - gerçek test ($STACK, desen: $TEST_FIND)"
  echo "  - settings.json allow ('$TEST','$BUILD','$FMT' + salt-okunur git) & deny (büyük üretilmiş asset yolları)"
  echo "  - (ops) llms.txt — dış LLM tüketicisi varsa ekle (llmstxt.org)"
  echo "Öner: git config core.hooksPath .githooks && git config commit.template .gitmessage"
  echo "Ticket-key zorlamak istersen (ops — kullanıcıya SOR): git config vibe.ticketre '^[A-Z]{3}-[0-9]{1,4} '"
  echo "Sürüm güncellemesi (sonra): yeni vibe-setup sürümünde 'scaffold.sh upgrade .'"
}

# ---------------------------------------------------------------- migrations (ordered, idempotent, probe-guarded)
# Dosya-template değişimleri UPDATE yoluyla gider; migration SADECE dosya-dışı dönüşümler için
# (alan rename, mevcut dosyaya satır ekleme vb.). Her biri tekrar-güvenli olmalı (probe ile).
MIGRATED=()
run_migrations() {  # $1 = applied version
  # v3: commit-msg ticket-key zorunlu→opsiyonel (vibe.ticketre). Eski kurulumda davranışı KORU:
  # config'i eski hard-coded desene sabitle (yoksa upgrade sessizce zorlamayı kaldırırdı).
  if [ "$1" -lt 3 ] && [ -f .githooks/commit-msg ] && git rev-parse --git-dir >/dev/null 2>&1; then
    if ! git config --local --get vibe.ticketre >/dev/null 2>&1; then
      git config vibe.ticketre '^[A-Z]{3}-[0-9]{1,4} ' \
        && MIGRATED+=("v3: vibe.ticketre eski zorunlu desene sabitlendi — davranış korundu (kaldır: git config --unset vibe.ticketre)")
    fi
  fi
  return 0
}

# ---------------------------------------------------------------- upgrade (deterministik drift; asla ezmez)
upgrade() {
  echo "vibe-setup upgrade — $(pwd)  (engine v$VIBE_VERSION, stack $STACK)"
  local applied legacy=0
  applied="$(manifest_version || true)"
  if [ -z "$applied" ]; then
    if managed_present; then echo "Manifest yok ama managed dosyalar var → legacy repo (sürümleme öncesi); provenance yok."; applied=0; legacy=1
    else echo "Repo init edilmemiş. Önce: scaffold.sh init ."; return 0; fi
  fi
  echo "applied=v$applied → engine=v$VIBE_VERSION"

  local add=() upd=() conf=() tmp; tmp="$(mktemp)"
  local p cls wantsha cursha mansha mancreated
  for p in $(managed_paths); do
    if [ ! -e "$p" ]; then add+=("$p"); continue; fi
    cls="$(artifact_class "$p")"
    [ "$cls" = "seed" ] && continue                                   # seed: bir kez düşer, drift normal → dokunma
    render_artifact "$p" > "$tmp" 2>/dev/null || continue
    wantsha="$(sha_of_path "$tmp")"; cursha="$(sha_of_path "$p")"
    [ "$wantsha" = "$cursha" ] && continue                            # zaten güncel template
    mansha="$(manifest_sha "$p" 2>/dev/null || true)"
    mancreated="$(manifest_created "$p" 2>/dev/null || true)"
    # provenance yok, VEYA vibe-setup'ın ürettiği içerik değil (created:false — pre-existing ya da
    # migrate_legacy_agent_md gibi taşınmış içerik) → güvenli CONFLICT (sha eşleşse bile EZME):
    if [ "$legacy" -eq 1 ] || [ -z "$mansha" ] || [ "$mancreated" = "false" ]; then conf+=("$p")
    elif [ "$cursha" = "$mansha" ]; then                              # dokunulmamış → güvenli UPDATE
      cp "$tmp" "$p"; case "$p" in .githooks/*) chmod +x "$p" ;; esac; upd+=("$p")
    else conf+=("$p"); fi                                             # elle düzenlenmiş → CONFLICT (ezme)
  done
  rm -f "$tmp"

  STAMP_VERSION=1
  WRITTEN_PATHS="${upd[*]:-}"
  run_migrations "$applied"
  write_manifest   # vibeVersion→$VIBE_VERSION; UPDATE'lerin (WRITTEN_PATHS) yeni sha'sı, geri kalanının ESKİ sha'sı korunur

  echo
  printf 'UPDATE=%s\n'   "$(IFS=,; echo "${upd[*]:-}")"
  printf 'ADD=%s\n'      "$(IFS=,; echo "${add[*]:-}")"
  printf 'CONFLICT=%s\n' "$(IFS=,; echo "${conf[*]:-}")"
  printf 'MIGRATED=%s\n' "$(IFS=,; echo "${MIGRATED[*]:-}")"
  echo
  [ ${#upd[@]}  -gt 0 ] && echo "UPDATE: dokunulmamış managed dosya(lar) yeni template'e güncellendi (restamp + manifest)."
  [ ${#add[@]}  -gt 0 ] && echo "ADD: eksik dosya(lar) — 'scaffold.sh init .' düşürür (idempotent)."
  [ ${#conf[@]} -gt 0 ] && echo "CONFLICT: elle düzenlenmiş managed dosya(lar) — engine EZMEDİ. Skill/LLM yeni template ile merge etsin (insan edit'ini koru)."
  echo "Sonraki (skill): UPDATE/ADD/MIGRATED'ı bildir; CONFLICT'leri LLM-merge ile çöz; llm artifact'leri (CLAUDE.md/test/docs) yeni checklist'e göre re-audit et; sonda audit."
}

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
write_extra() {  # $1 path (content on stdin) — never overwrite. Shared by init-cursor, init-gemini.
  if [ -e "$1" ]; then echo "  SKIP  $1 (var)"; return; fi
  mkdir -p "$(dirname "$1")"; cat > "$1"
  NEW_PATHS="$NEW_PATHS $1"
  WRITTEN_PATHS="$WRITTEN_PATHS $1"
  echo "  NEW   $1"
}

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
  echo "KAPSAM DIŞI — elle gözden geçir: CLAUDE.md, docs/, tests/, .claude/settings.json içeriği, vibe-checklist.md"
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
    # grep -v exits 1 (no output) when $gi was the ONLY line — that's a valid empty
    # result here, not a failure, so don't gate the mv on grep's exit status.
    grep -vxF "$gi" .gitignore > .gitignore.tmp || true
    mv .gitignore.tmp .gitignore
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
    echo "CLAUDE.md, docs/, tests/, .claude/settings.json içeriği, vibe-checklist.md (LLM/kullanıcı tarafından dolduruldu, otomatik silinmez)."
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
