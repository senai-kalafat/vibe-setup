# Multi-Tool Packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the vibe-setup repo installable/discoverable from Cursor (not just Claude Code), and add a bash version-sync script that keeps the package version field in lockstep across every manifest, so a future third manifest doesn't need yet another manual edit.

**Architecture:** Two independent additions. (1) A new `.cursor-plugin/plugin.json` + `.cursor-plugin/vibe-setup.mdc` — mirrors context-mode's own Cursor packaging pattern and vibe-setup's own existing `init_cursor()` output convention (a `.mdc` rule pointing an agent at the real instructions, here `skills/vibe-setup/SKILL.md` instead of a target repo's `CLAUDE.md`). (2) A new `scripts/version-sync.sh` — pure bash (no Node, no `sed -i`, reusing this codebase's established `awk gsub + tmp-file + mv` idiom), reads `.claude-plugin/plugin.json`'s `"version"` as the single source of truth and propagates it to `marketplace.json` (two occurrences) and the new `.cursor-plugin/plugin.json`. `CLAUDE.md` gets a new command line and a new Gotcha distinguishing this package version from the unrelated `VIBE_VERSION` (scaffold.sh's own output-schema version).

**Tech Stack:** Bash (`scripts/version-sync.sh`, reusing the exact `awk`/`grep`/tmp-file pattern already used throughout `scaffold.sh` and `tests/`), JSON (new manifest), Markdown (`.mdc` rule, `CLAUDE.md`), bash test harness (`tests/version_sync_test.sh`).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-28-multi-tool-packaging-design.md` (approved).
- No Node.js, no `package.json` — this project has never had a JS runtime dependency and stays that way. `scripts/version-sync.sh` is pure bash.
- No `sed -i` anywhere — BSD (macOS) vs GNU `sed -i` have incompatible flag syntax. Use the codebase's existing `awk '{ ... }' file > file.tmp && mv file.tmp file` idiom instead (see `tests/upgrade_test.sh`'s `set_msha` function for the established precedent).
- `.claude-plugin/plugin.json`'s `"version"` field is the single source of truth. The sync script only ever reads FROM it and writes TO the other manifests — never the reverse.
- No Codex/Gemini CLI manifest work in this plan — they already read this repo's root `AGENTS.md` → `CLAUDE.md` natively; explicitly out of scope per the spec.
- No git hook / CI wiring for the sync script — it's a manual, maintainer-run release step.
- Commit ticket key: `VIB-10` (per this repo's `.githooks/commit-msg` convention, `^[A-Z]{3}-[0-9]{1,4} `).
- Test runner: `bash tests/run.sh` from repo root — auto-discovers every `tests/*_test.sh`.
- Current manifest content (verify against it before editing — reproduced here for exact reference):
  - `.claude-plugin/plugin.json`:
    ```json
    {
      "name": "vibe-setup",
      "version": "0.2.0",
      "description": "Audit any repository for AI/agent (vibe coding) readiness, scaffold the missing pieces, upgrade an already-set-up repo to a newer version, and remove what it created — stack- and language-agnostic.",
      "author": {
        "name": "Senai Kalafat"
      },
      "homepage": "https://github.com/senai-kalafat/vibe-setup",
      "repository": "https://github.com/senai-kalafat/vibe-setup",
      "keywords": [
        "vibe-coding",
        "agent-readiness",
        "claude-md",
        "scaffold",
        "audit",
        "onboarding"
      ],
      "skills": "./skills/"
    }
    ```
  - `.claude-plugin/marketplace.json`:
    ```json
    {
      "name": "vibe-setup",
      "owner": {
        "name": "Senai Kalafat"
      },
      "metadata": {
        "description": "vibe-setup — Claude Code plugins",
        "version": "0.2.0"
      },
      "plugins": [
        {
          "name": "vibe-setup",
          "source": "./",
          "description": "Audit any repository for AI/agent (vibe coding) readiness, scaffold the missing pieces, upgrade an already-set-up repo to a newer version, and remove what it created — stack- and language-agnostic.",
          "version": "0.2.0",
          "author": {
            "name": "Senai Kalafat"
          },
          "category": "development",
          "keywords": [
            "vibe-coding",
            "agent-readiness",
            "claude-md",
            "scaffold",
            "audit",
            "onboarding"
          ]
        }
      ]
    }
    ```

---

### Task 1: Cursor plugin manifest + rule file

**Files:**
- Create: `.cursor-plugin/plugin.json`
- Create: `.cursor-plugin/vibe-setup.mdc`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `.cursor-plugin/plugin.json`'s `"version"` field is one of Task 2's sync targets (Task 2 reads this task's output file and overwrites its version field — the rest of the JSON is untouched by Task 2).

This is a self-contained, new-files-only task: nothing existing changes, so there's no "find current content" step — just create both files with the exact content below, matching the shape of vibe-setup's OWN existing `init_cursor()` output convention in `skills/vibe-setup/scaffold.sh` (a `.mdc` pointing at the real instructions) and context-mode's own `.cursor-plugin/plugin.json` shape (verified against `~/.claude/plugins/marketplaces/context-mode/.cursor-plugin/plugin.json` during design).

- [ ] **Step 1: Create `.cursor-plugin/plugin.json`**

Create `.cursor-plugin/plugin.json` with exactly this content:

```json
{
  "name": "vibe-setup",
  "version": "0.2.0",
  "description": "Audit any repository for AI/agent (vibe coding) readiness, scaffold the missing pieces, upgrade an already-set-up repo to a newer version, and remove what it created — stack- and language-agnostic.",
  "author": {
    "name": "Senai Kalafat"
  },
  "homepage": "https://github.com/senai-kalafat/vibe-setup",
  "repository": "https://github.com/senai-kalafat/vibe-setup",
  "keywords": [
    "vibe-coding",
    "agent-readiness",
    "claude-md",
    "scaffold",
    "audit",
    "onboarding"
  ],
  "rules": "./.cursor-plugin/vibe-setup.mdc",
  "skills": "./skills/"
}
```

- [ ] **Step 2: Create `.cursor-plugin/vibe-setup.mdc`**

Create `.cursor-plugin/vibe-setup.mdc` with exactly this content:

```markdown
---
description: vibe-setup — bir repoyu AI/agent ("vibe coding") hazırlığı için denetler ve eksikleri kurar. Kullanıcı "vibe-setup", "vibe checklist", "audit this project for agent readiness", "bu repoyu AI/agent'a hazırla" gibi bir şey istediğinde devreye gir.
alwaysApply: false
---
Kullanıcı bu repodaki (ya da açık olan başka bir hedef repodaki) AI/agent-hazırlığını denetlemek ya da
kurmak istiyorsa: `skills/vibe-setup/SKILL.md`'yi oku ve orada anlatılan akışı izle.

Deterministik motor: `skills/vibe-setup/scaffold.sh {audit|init|init-cursor|init-gemini|upgrade|remove|profile}`.
Sıfırdan kurulum değil, zaten kurulu bir repoyu güncelliyorsan SKILL.md'deki `## Upgrade akışı`'nı izle;
kaldırıyorsan `## Remove akışı`'nı izle.
```

- [ ] **Step 3: Verify both files are valid**

Run: `python3 -m json.tool .cursor-plugin/plugin.json >/dev/null && echo "plugin.json OK"`
Expected: `plugin.json OK`

Run: `head -5 .cursor-plugin/vibe-setup.mdc`
Expected: the YAML frontmatter block (`---` / `description: ...` / `alwaysApply: false` / `---`) prints cleanly, no errors.

- [ ] **Step 4: Run the full test suite as a sanity check**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED` (this task adds no code path any existing test touches, but confirms nothing else broke).

- [ ] **Step 5: Commit**

```bash
git add .cursor-plugin/plugin.json .cursor-plugin/vibe-setup.mdc
git commit -m "$(cat <<'EOF'
VIB-10 .cursor-plugin ekle: Cursor'dan vibe-setup'i kesfet/kur

context-mode'un kendi .cursor-plugin/plugin.json seklini izler (MCP/hook
yok — vibe-setup pasif bir skill). vibe-setup.mdc, vibe-setup'in kendi
init-cursor OUTPUT'unun ayni desenini kullanarak Cursor agent'ini
SKILL.md'ye yonlendirir.
EOF
)"
```

---

### Task 2: `scripts/version-sync.sh` + test

**Files:**
- Create: `scripts/version-sync.sh`
- Test: `tests/version_sync_test.sh` (new)

**Interfaces:**
- Consumes: `.cursor-plugin/plugin.json` (from Task 1) as one of its two sync targets — but the script itself takes a `DIR` argument and works against whatever manifests exist under that directory, so it doesn't literally depend on Task 1 having run in THIS repo; the test builds its own synthetic fixture directory.
- Produces: `bash scripts/version-sync.sh [DIR]` — a CLI script, `DIR` defaults to `.`. No other task consumes this programmatically; Task 3 documents it in `CLAUDE.md`.

This follows the codebase's existing test-fixture-in-tmpdir convention (see `tests/upgrade_test.sh`'s `fresh()` helper) rather than mutating this repo's real manifests during the test.

- [ ] **Step 1: Write the failing test**

Create `tests/version_sync_test.sh`:

```bash
#!/usr/bin/env bash
# scripts/version-sync.sh testi — plugin.json tek kaynak, marketplace.json (2 occurrence) +
# .cursor-plugin/plugin.json'a yayilir. Bagimsiz (dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SYNC="$ROOT/scripts/version-sync.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
work="$tmp/repo"; mkdir -p "$work/.claude-plugin" "$work/.cursor-plugin"

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

cat > "$work/.claude-plugin/plugin.json" <<'EOF'
{
  "name": "vibe-setup",
  "version": "9.9.9",
  "description": "test"
}
EOF
cat > "$work/.claude-plugin/marketplace.json" <<'EOF'
{
  "name": "vibe-setup",
  "metadata": {
    "description": "vibe-setup — Claude Code plugins",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "vibe-setup",
      "version": "0.1.0"
    }
  ]
}
EOF
cat > "$work/.cursor-plugin/plugin.json" <<'EOF'
{
  "name": "vibe-setup",
  "version": "0.1.0",
  "description": "test"
}
EOF

out="$(bash "$SYNC" "$work" 2>&1)"

[ "$(grep -c '"version": "9.9.9"' "$work/.claude-plugin/marketplace.json")" = "2" ] && ok "marketplace.json her iki version alani da guncellendi" || bad "marketplace.json version guncellemesi eksik/yanlis"
grep -q '"version": "9.9.9"' "$work/.cursor-plugin/plugin.json" && ok "cursor-plugin.json guncellendi" || bad "cursor-plugin.json guncellenmedi"
grep -q '"version": "9.9.9"' "$work/.claude-plugin/plugin.json" && ok "kaynak plugin.json degismedi (hala 9.9.9)" || bad "kaynak plugin.json bozuldu"

if command -v jq >/dev/null 2>&1; then
  jq -e . "$work/.claude-plugin/marketplace.json" >/dev/null 2>&1 && ok "marketplace.json gecerli JSON" || bad "marketplace.json bozuk JSON"
  jq -e . "$work/.cursor-plugin/plugin.json" >/dev/null 2>&1 && ok "cursor-plugin.json gecerli JSON" || bad "cursor-plugin.json bozuk JSON"
else
  echo "  skip: jq yok — JSON gecerlilik atlandi"
fi

# eksik .cursor-plugin/plugin.json durumunda cokmemeli (SKIP)
work2="$tmp/repo2"; mkdir -p "$work2/.claude-plugin"
cp "$work/.claude-plugin/plugin.json" "$work2/.claude-plugin/plugin.json"
cp "$work/.claude-plugin/marketplace.json" "$work2/.claude-plugin/marketplace.json"
out2="$(bash "$SYNC" "$work2" 2>&1)"; code2=$?
[ "$code2" -eq 0 ] && ok "cursor-plugin.json yokken bile exit 0" || bad "cursor-plugin.json yokken crash (exit $code2)"
printf '%s' "$out2" | grep -q 'SKIP' && ok "eksik dosya icin SKIP basildi" || bad "SKIP mesaji basilmadi"

# kaynak plugin.json hic yoksa net hata + nonzero exit
work3="$tmp/repo3"; mkdir -p "$work3"
out3="$(bash "$SYNC" "$work3" 2>&1)"; code3=$?
[ "$code3" -ne 0 ] && ok "kaynak plugin.json yokken nonzero exit" || bad "kaynak plugin.json yokken exit 0 (hata verilmeliydi)"

echo "version_sync_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

Make it executable-equivalent (matches sibling test files):

```bash
chmod +x tests/version_sync_test.sh
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `bash tests/version_sync_test.sh`
Expected: FAIL — `scripts/version-sync.sh` doesn't exist yet, so `bash "$SYNC" ...` errors with "No such file or directory" and every assertion that depends on its output fails. Confirms the test is exercising not-yet-built behavior.

- [ ] **Step 3: Implement `scripts/version-sync.sh`**

Create `scripts/version-sync.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# scripts/version-sync.sh [DIR] — .claude-plugin/plugin.json'daki "version" tek kaynak;
# marketplace.json + .cursor-plugin/plugin.json'a yayar. Manuel calistirilir (release aninda),
# git hook'a baglanmaz. sed -i YOK (BSD/GNU fark) — awk gsub + tmp-dosya + mv (mevcut kod tabani deseni).
set -euo pipefail
DIR="${1:-.}"
cd "$DIR"

PLUGIN_JSON=.claude-plugin/plugin.json
if [ ! -f "$PLUGIN_JSON" ]; then
  echo "kullanim: version-sync.sh [DIR] ($PLUGIN_JSON bulunamadi)" >&2
  exit 1
fi

VERSION="$(grep -m1 -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$PLUGIN_JSON" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
if [ -z "$VERSION" ]; then
  echo "$PLUGIN_JSON icinde \"version\" bulunamadi" >&2
  exit 1
fi

sync_file() {  # $1 = hedef dosya
  local f="$1"
  if [ ! -f "$f" ]; then echo "  SKIP  $f (yok)"; return; fi
  awk -v v="$VERSION" '{ gsub(/"version"[[:space:]]*:[[:space:]]*"[^"]+"/, "\"version\": \"" v "\""); print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  echo "  OK    $f → $VERSION"
}

echo "version-sync — kaynak: $PLUGIN_JSON ($VERSION)"
sync_file .claude-plugin/marketplace.json
sync_file .cursor-plugin/plugin.json
echo "Bitti."
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `bash tests/version_sync_test.sh`
Expected: `version_sync_test: N passed, 0 failed`

- [ ] **Step 5: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 6: Dogfood — run it against this real repo and confirm it's a no-op (already in sync)**

Run: `bash scripts/version-sync.sh .`
Expected: prints `version-sync — kaynak: .claude-plugin/plugin.json (0.2.0)`, then `OK    .claude-plugin/marketplace.json → 0.2.0` and `OK    .cursor-plugin/plugin.json → 0.2.0` (from Task 1), then `Bitti.`

Run: `git status --porcelain .claude-plugin/ .cursor-plugin/`
Expected: empty output — since every manifest was already at `0.2.0`, the rewrite produces byte-identical content (no working-tree diff).

- [ ] **Step 7: Commit**

```bash
git add scripts/version-sync.sh tests/version_sync_test.sh
git commit -m "$(cat <<'EOF'
VIB-10 scripts/version-sync.sh ekle: paket versiyonunu manifestlere yay

Saf bash, sed -i yok (awk gsub + tmp + mv — mevcut kod tabani deseni).
plugin.json'daki version tek kaynak; marketplace.json (2 occurrence) +
.cursor-plugin/plugin.json'a yayilir. Manuel calistirilir, git hook'a
baglanmaz.
EOF
)"
```

---

### Task 3: `CLAUDE.md` — document the command + the version-vs-VIBE_VERSION distinction

**Files:**
- Modify: `CLAUDE.md` (the `## Komutlar` section, and the `## Gotchas` section)

**Interfaces:**
- Consumes: `scripts/version-sync.sh` (Task 2) — this task only documents it, doesn't call it programmatically.
- Produces: nothing consumed elsewhere — final documentation task in this plan.

- [ ] **Step 1: Add the command line**

In `CLAUDE.md`, find:

```markdown
## Komutlar (repo kökünden)
- Test: `bash tests/run.sh` (bağımsız, dış dep yok)
- Audit (dogfood): `bash skills/vibe-setup/scaffold.sh audit .`
- Upgrade (dogfood): `bash skills/vibe-setup/scaffold.sh upgrade .` — sürümlü drift; UPDATE/ADD/CONFLICT raporu
- Profil: `bash skills/vibe-setup/scaffold.sh profile .`
- Lint (ops): `shellcheck skills/vibe-setup/scaffold.sh` — kurulu değilse atla
- Format (ops): `shfmt -d skills/vibe-setup/scaffold.sh` — kurulu değilse atla
```

Replace with:

```markdown
## Komutlar (repo kökünden)
- Test: `bash tests/run.sh` (bağımsız, dış dep yok)
- Audit (dogfood): `bash skills/vibe-setup/scaffold.sh audit .`
- Upgrade (dogfood): `bash skills/vibe-setup/scaffold.sh upgrade .` — sürümlü drift; UPDATE/ADD/CONFLICT raporu
- Profil: `bash skills/vibe-setup/scaffold.sh profile .`
- Versiyon senkron: `bash scripts/version-sync.sh` — `.claude-plugin/plugin.json`'daki `"version"`'ı
  `marketplace.json` + `.cursor-plugin/plugin.json`'a yayar (release'te elle çalıştır).
- Lint (ops): `shellcheck skills/vibe-setup/scaffold.sh` — kurulu değilse atla
- Format (ops): `shfmt -d skills/vibe-setup/scaffold.sh` — kurulu değilse atla
```

- [ ] **Step 2: Add the new Gotcha**

In `CLAUDE.md`, find (the tail of the `## Gotchas` section, immediately before `## Git workflow`):

```markdown
- **context-mode zorunlu bağımlılık** (v9+): SKILL.md Faz 3 her çalıştırmada sorulmadan kurar
  (`npm install -g context-mode` + Claude/Cursor repo-tracked JSON-merge + Antigravity global config).
  Subagent dispatch eden bir akış varsa (bu repoda: subagent-driven-development), her dispatch
  prompt'una context-mode kullanım talimatı **açıkça** eklenmeli — subagent taze context alır, parent
  session'ın context-mode kurallarını miras almaz.

## Git workflow
```

Replace with:

```markdown
- **context-mode zorunlu bağımlılık** (v9+): SKILL.md Faz 3 her çalıştırmada sorulmadan kurar
  (`npm install -g context-mode` + Claude/Cursor repo-tracked JSON-merge + Antigravity global config).
  Subagent dispatch eden bir akış varsa (bu repoda: subagent-driven-development), her dispatch
  prompt'una context-mode kullanım talimatı **açıkça** eklenmeli — subagent taze context alır, parent
  session'ın context-mode kurallarını miras almaz.
- **Paket versiyonu ≠ `VIBE_VERSION`.** `.claude-plugin/plugin.json` / `marketplace.json` /
  `.cursor-plugin/plugin.json`'daki `"version"` bu PLUGIN'in kendi sürümü — `scripts/version-sync.sh`
  ile senkron tutulur, `plugin.json` tek kaynak. `scaffold.sh`'taki `VIBE_VERSION` TAMAMEN AYRI bir
  kavram: scaffold.sh'ın hedef repolara ÜRETTİĞİ dosya şemasının sürümü (upgrade'in drift tespiti
  için). Biri artınca diğeri otomatik artmaz — ikisini karıştırma.

## Git workflow
```

- [ ] **Step 3: Verify both edits**

Run: `grep -n "version-sync.sh\|Paket versiyonu" CLAUDE.md`
Expected: at least 3 matching lines (the Komutlar line, and the two lines of the new Gotcha that mention `version-sync.sh`/"Paket versiyonu").

- [ ] **Step 4: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
VIB-10 CLAUDE.md: version-sync.sh komutu + paket-versiyonu-vs-VIBE_VERSION gotcha'si

Yeni scripts/version-sync.sh Komutlar'a eklendi. Yeni Gotcha: plugin
paket versiyonu (plugin.json/marketplace.json/cursor-plugin.json) ile
scaffold.sh'in kendi VIBE_VERSION'i (OUTPUT-drift takibi) karistirilmamali.
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:** every kapsam kararı in the spec (Cursor manifest + `.mdc` rule shape and content, explicit no-manifest decision for Codex/Gemini, bash-only version-sync script with `plugin.json` as single source and the two propagation targets, `CLAUDE.md` command + gotcha) has a corresponding task/step. The spec's "kapsam dışı" exclusions (no marketplace submission, no git-hook/CI wiring for the sync script, no README Cursor-install section, no Codex/Gemini manifest) are honored by construction — no task does any of those things.

**Placeholder scan:** no TBD/TODO; every step shows the complete file content or exact find/replace text, not a description of what to write.

**Type/name consistency:** `scripts/version-sync.sh [DIR]` (Task 2) is referenced identically in Task 3's `CLAUDE.md` command line (`bash scripts/version-sync.sh`) and in Task 2's own dogfood step. `.cursor-plugin/plugin.json`'s `"version"` field (created in Task 1 at `0.2.0`, matching the current real `plugin.json`/`marketplace.json` value) is exactly the file Task 2's sync script targets by the literal path `.cursor-plugin/plugin.json` — no drift between what Task 1 creates and what Task 2 looks for.
