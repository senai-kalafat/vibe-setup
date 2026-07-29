# Strict doc-sync (git-config vibe.strictdocs) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the doc-sync check in the pre-commit hook `scaffold.sh` generates for target repos genuinely enforceable — replace the ephemeral `STRICT_DOCS=1` environment variable with a persisted `git config vibe.strictdocs true`, and teach `SKILL.md` to ask about it (default-suggested yes) during setup and during upgrade of already-installed repos.

**Architecture:** One mechanism swap inside `render_precommit()` (the canonical template source `init`/`upgrade` both render from), a `VIBE_VERSION` bump (this changes the template `upgrade` propagates to existing installs), and a documentation pass across `SKILL.md` (new Faz 2 question + Upgrade akışı note) and `README.md`. Mirrors the existing `vibe.ticketre` pattern exactly — same git-config namespace, same "ask once, persist, hook reads at runtime" shape.

**Tech Stack:** Pure bash (`scaffold.sh`'s existing style — heredoc template + `@VAR@` substitution, no new dependencies). Bash test harness (`tests/*_test.sh`, auto-discovered by `tests/run.sh`).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-30-strict-doc-sync-design.md` (VIB-13).
- New mechanism: `git config --get --bool vibe.strictdocs` read at commit time by the rendered `.githooks/pre-commit` — persisted, repo-local, exact same shape as the existing `vibe.ticketre` check in `.githooks/commit-msg`.
- No new env-var escape hatch — `git commit --no-verify` remains the only bypass, matching existing philosophy.
- `render_precommit()` in `skills/vibe-setup/scaffold.sh` is the single canonical source of the pre-commit template — both `init` and `upgrade` render from it, so editing it here is sufficient; no separate "target repo" code path exists.
- Per `CLAUDE.md`'s "Sürüm yükseltirken 3 yer" gotcha, a managed-template content change requires: (a) `VIBE_VERSION`++ (4→5), (b) `artifact_changed_in ".githooks/pre-commit"` bumped to match (2→5), (c) the template itself (`render_precommit`) — all three land in Task 1.
- Bumping `VIBE_VERSION` changes the *value* embedded in fresh manifests and in the `vibe-setup:vN` stamp written into `.githooks/pre-commit` — several existing assertions in `tests/upgrade_test.sh` hardcode the old values (`4`, `2`) and must be updated in the same task, or the full suite goes red for unrelated reasons.
- SKILL.md's existing pattern for "ask about an enforcement toggle" is the ticket-key question in Faz 2 (`## Akış (sırayla)` → `### 2. Rapor + onay`) — the new doc-sync question is added as a sibling bullet immediately after it, same phrasing shape ("zorunlu SOR, varsayma"), but with default-suggested answer **evet** (spec's explicit requirement, unlike ticket-key's default-off).
- Commit ticket key: `VIB-13` (this repo's `.githooks/commit-msg` enforces `^[A-Z]{3}-[0-9]{1,4} `).
- Test runner: `bash tests/run.sh` from repo root — auto-discovers every `tests/*_test.sh`.

---

### Task 1: Mechanism swap — `render_precommit()` + version bump + test fixes

**Files:**
- Modify: `skills/vibe-setup/scaffold.sh` (`VIBE_VERSION`, `artifact_changed_in`, `render_precommit()`)
- Modify: `tests/precommit_test.sh` (switch STRICT_DOCS env-var assertions to `git config vibe.strictdocs`)
- Modify: `tests/upgrade_test.sh` (fix hardcoded `vibeVersion`/pre-commit-`v` values broken by the bump)

**Interfaces:**
- Consumes: nothing new — reuses the existing `render_precommit()`/`artifact_changed_in()`/`emit()` machinery unchanged in shape, only the doc-sync check's *body* and the version constants change.
- Produces: the rendered `.githooks/pre-commit` now reads `git config --get --bool vibe.strictdocs` instead of `$STRICT_DOCS`. Task 2's documentation describes this command by name (`git config vibe.strictdocs true`) — must match exactly.

- [ ] **Step 1: Update the failing test — `tests/precommit_test.sh`**

Find:

```bash
# 2. STRICT_DOCS=1 + sadece kaynak staged → doc-sync bloklar
echo 'echo v2' >> "$d/tool.sh"; git -C "$d" add tool.sh
if STRICT_DOCS=1 git -C "$d" commit -q -m 'TST-2 kaynak' 2>/dev/null; then bad "STRICT_DOCS=1 bloklamadi"; else ok "STRICT_DOCS=1 doc'suz kaynak bloklandi"; fi
[ "$(git -C "$d" rev-list --count HEAD)" = "1" ] && ok "bloklanan commit olusmadi" || bad "bloklanmasina ragmen commit olustu"

# 3. aynı staged durum, STRICT_DOCS'suz → doc-sync advisory, geçer
if git -C "$d" commit -q -m 'TST-3 kaynak' 2>/dev/null; then ok "STRICT_DOCS'suz advisory gecti"; else bad "advisory modda bloklandi"; fi
```

Replace with:

```bash
# 2. vibe.strictdocs=true + sadece kaynak staged → doc-sync bloklar
echo 'echo v2' >> "$d/tool.sh"; git -C "$d" add tool.sh
git -C "$d" config vibe.strictdocs true
if git -C "$d" commit -q -m 'TST-2 kaynak' 2>/dev/null; then bad "vibe.strictdocs=true bloklamadi"; else ok "vibe.strictdocs=true doc'suz kaynak bloklandi"; fi
[ "$(git -C "$d" rev-list --count HEAD)" = "1" ] && ok "bloklanan commit olusmadi" || bad "bloklanmasina ragmen commit olustu"
git -C "$d" config --unset vibe.strictdocs

# 3. aynı staged durum, vibe.strictdocs ayarsız → doc-sync advisory, geçer
if git -C "$d" commit -q -m 'TST-3 kaynak' 2>/dev/null; then ok "vibe.strictdocs ayarsiz advisory gecti"; else bad "advisory modda bloklandi"; fi
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `bash tests/precommit_test.sh`
Expected: FAIL on the two updated assertions — the hook still reads `$STRICT_DOCS`, so `git config vibe.strictdocs true` has no effect yet (test 2's commit succeeds when it should be blocked; test 3's premise depends on test 2 having failed to block).

- [ ] **Step 3: Bump `VIBE_VERSION`**

Find:

```bash
VIBE_VERSION=4
```

Replace with:

```bash
VIBE_VERSION=5
```

- [ ] **Step 4: Bump `artifact_changed_in` for `.githooks/pre-commit`**

Find:

```bash
  .githooks/pre-commit) echo 2 ;;   # v2: sed→bash literal-replace (node SRC_RE `|` delimiter çakışması fix)
```

Replace with:

```bash
  .githooks/pre-commit) echo 5 ;;   # v5: doc-sync STRICT_DOCS env-var yerine git config vibe.strictdocs (kalıcı, vibe.ticketre ile aynı desen)
```

- [ ] **Step 5: Update the header comment inside the rendered template**

Find:

```bash
# Stack: @STACK@ | doc-sync'i blocking yap: STRICT_DOCS=1 | Bypass tümü: --no-verify
```

Replace with:

```bash
# Stack: @STACK@ | doc-sync'i blocking yap: git config vibe.strictdocs true | Bypass tümü: --no-verify
```

- [ ] **Step 6: Switch the doc-sync check itself to git-config**

Find:

```bash
# 3. doc-sync (advisory default; STRICT_DOCS=1 → blocking) — kaynak değişti, doküman değişmediyse
src=0; printf '%s\n' "$staged" | grep -qE '@SRCRE@' && src=1
doc=0; printf '%s\n' "$staged" | grep -qE '(^docs/.*\.md$|(^|/)(README|CLAUDE|AGENTS)\.md$)' && doc=1
if [ "$src" = 1 ] && [ "$doc" = 0 ]; then
  echo "ℹ doc-sync: kaynak değişti, doküman güncellenmedi. docs/ + README/CLAUDE/AGENTS gözden geçir." >&2
  [ "${STRICT_DOCS:-}" = "1" ] && { echo "  STRICT_DOCS=1 → blocking." >&2; fail=1; }
fi
```

Replace with:

```bash
# 3. doc-sync (advisory default; git config vibe.strictdocs true → blocking) — kaynak değişti,
#    doküman değişmediyse. vibe.ticketre ile AYNI desen: repo-local git config, kalıcı.
src=0; printf '%s\n' "$staged" | grep -qE '@SRCRE@' && src=1
doc=0; printf '%s\n' "$staged" | grep -qE '(^docs/.*\.md$|(^|/)(README|CLAUDE|AGENTS)\.md$)' && doc=1
if [ "$src" = 1 ] && [ "$doc" = 0 ]; then
  echo "ℹ doc-sync: kaynak değişti, doküman güncellenmedi. docs/ + README/CLAUDE/AGENTS gözden geçir." >&2
  strict="$(git config --get --bool vibe.strictdocs 2>/dev/null || echo false)"
  [ "$strict" = "true" ] && { echo "  vibe.strictdocs=true → blocking." >&2; fail=1; }
fi
```

- [ ] **Step 7: Run `tests/precommit_test.sh` to confirm it passes**

Run: `bash tests/precommit_test.sh`
Expected: `precommit_test: 9 passed, 0 failed`, no `FAIL` lines.

- [ ] **Step 8: Run the full suite to find the version-bump fallout**

Run: `bash tests/run.sh`
Expected: `tests/upgrade_test.sh` FAILs — several assertions hardcode the old `VIBE_VERSION`/pre-commit-`v` values. Everything else passes.

- [ ] **Step 9: Fix `tests/upgrade_test.sh`'s hardcoded version values**

Six spots need updating — each Find below is unique in the file (verify with the Step 8 failure output if a Find doesn't match exactly).

Find:

```bash
grep -q '"vibeVersion": 4' "$d/.vibe-setup.json" && ok "vibeVersion=4" || bad "vibeVersion yok/yanlış"
grep -q '".githooks/pre-commit": { "v": 2' "$d/.vibe-setup.json" && ok "pre-commit v2 kayıtlı" || bad "pre-commit v kaydı yok"
```

Replace with:

```bash
grep -q '"vibeVersion": 5' "$d/.vibe-setup.json" && ok "vibeVersion=5" || bad "vibeVersion yok/yanlış"
grep -q '".githooks/pre-commit": { "v": 5' "$d/.vibe-setup.json" && ok "pre-commit v5 kayıtlı" || bad "pre-commit v kaydı yok"
```

Find:

```bash
grep -q 'vibe-setup:v2' "$d/.githooks/pre-commit" && grep -qF 'js|ts|jsx|tsx' "$d/.githooks/pre-commit" && ok "pre-commit v2 template'e yenilendi" || bad "regen içeriği yanlış"
```

Replace with:

```bash
grep -q 'vibe-setup:v5' "$d/.githooks/pre-commit" && grep -qF 'js|ts|jsx|tsx' "$d/.githooks/pre-commit" && ok "pre-commit v5 template'e yenilendi" || bad "regen içeriği yanlış"
```

Find:

```bash
grep -q '".githooks/pre-commit": { "v": 2, "sha": "[0-9]*", "created": true' "$d/.vibe-setup.json" && ok "CONFLICT'te de created:true korunur" || bad "created flag CONFLICT'te bozuldu"
```

Replace with:

```bash
grep -q '".githooks/pre-commit": { "v": 5, "sha": "[0-9]*", "created": true' "$d/.vibe-setup.json" && ok "CONFLICT'te de created:true korunur" || bad "created flag CONFLICT'te bozuldu"
```

Find:

```bash
awk '{ sub(/"vibeVersion": 4/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
printf '%s' "$out" | grep -q 'applied=v1' && ok "eski uygulanan sürüm algılandı (v1)" || bad "applied=v1 basılmadı"
grep -q '"vibeVersion": 4' "$d/.vibe-setup.json" && ok "manifest v4'e yükseltildi" || bad "manifest sürümü yükselmedi"
```

Replace with:

```bash
awk '{ sub(/"vibeVersion": 5/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
printf '%s' "$out" | grep -q 'applied=v1' && ok "eski uygulanan sürüm algılandı (v1)" || bad "applied=v1 basılmadı"
grep -q '"vibeVersion": 5' "$d/.vibe-setup.json" && ok "manifest v5'e yükseltildi" || bad "manifest sürümü yükselmedi"
```

Find:

```bash
  awk '{ sub(/"vibeVersion": 4/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
```

Replace with:

```bash
  awk '{ sub(/"vibeVersion": 5/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
```

Find:

```bash
awk '{ sub(/"vibeVersion": 4/, "\"vibeVersion\": 2"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
bash "$SCAFFOLD" init-cursor "$d" >/dev/null 2>&1
grep -q '"vibeVersion": 2' "$d/.vibe-setup.json" && ok "K: init-cursor eski vibeVersion'i korudu" || bad "K: init-cursor vibeVersion'i yanlislikla guncelledi"
out3="$(bash "$SCAFFOLD" audit "$d" 2>/dev/null)"
printf '%s' "$out3" | grep -q 'UPDATE_AVAILABLE=v2->v4' && ok "K: audit hala UPDATE_AVAILABLE basiyor (sinyal kaybolmadi)" || bad "K: UPDATE_AVAILABLE sinyali kayboldu"
```

Replace with:

```bash
awk '{ sub(/"vibeVersion": 5/, "\"vibeVersion\": 2"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
bash "$SCAFFOLD" init-cursor "$d" >/dev/null 2>&1
grep -q '"vibeVersion": 2' "$d/.vibe-setup.json" && ok "K: init-cursor eski vibeVersion'i korudu" || bad "K: init-cursor vibeVersion'i yanlislikla guncelledi"
out3="$(bash "$SCAFFOLD" audit "$d" 2>/dev/null)"
printf '%s' "$out3" | grep -q 'UPDATE_AVAILABLE=v2->v5' && ok "K: audit hala UPDATE_AVAILABLE basiyor (sinyal kaybolmadi)" || bad "K: UPDATE_AVAILABLE sinyali kayboldu"
```

Note: `"AGENTS.md": { "v": 4` assertions (lines checking `AGENTS.md v4 kayıtlı`, case L's `created:false`) are **unaffected** — `AGENTS.md`'s own `artifact_changed_in` entry (separately `4`) was not touched by this plan, only `.githooks/pre-commit`'s. Do not change those lines.

- [ ] **Step 10: Run the full suite to confirm everything is green**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 11: Commit**

```bash
git add skills/vibe-setup/scaffold.sh tests/precommit_test.sh tests/upgrade_test.sh
git commit -m "$(cat <<'EOF'
VIB-13 scaffold.sh: doc-sync icin STRICT_DOCS yerine git config vibe.strictdocs

Env-var pratikte hic kullanilmiyordu (kimse shell profiline kalici
env var koymuyor). vibe.ticketre ile AYNI desen: repo-local git
config, .githooks/pre-commit git config --get --bool ile okur -
kalici, gercekten zorlayici. VIBE_VERSION 4->5, pre-commit
artifact_changed_in 2->5 (template icerigi degisti, upgrade mevcut
kurulumlari da tasisin diye). tests/upgrade_test.sh'in hardcoded v4/v2
degerleri guncellendi.
EOF
)"
```

---

### Task 2: Documentation — `SKILL.md` + `README.md`

**Files:**
- Modify: `skills/vibe-setup/SKILL.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: `git config vibe.strictdocs true` (Task 1) by name only — pure documentation, no code dependency.
- Produces: nothing consumed by other tasks — final task in this plan.

- [ ] **Step 1: `SKILL.md` — Faz 2 gets a new doc-sync question, right after the ticket-key question**

Find:

```markdown
- **Ticket-key sorusu (zorunlu SOR, varsayma):** commit mesajında ticket-key zorlansın mı?
  Varsayılan **zorlamasız** (hook hiçbir şeyi bloklamaz). Kullanıcı isterse formatı da sor —
  standart `ABC-1234` mi, özel regex mi? Cevaba göre Faz 3 sonrasında:
  `git config vibe.ticketre '^[A-Z]{3}-[0-9]{1,4} '` (ya da kullanıcının regex'i). İstemezse hiçbir şey yapma.
- **Hangi maddeleri kuralım?** diye sor. Kullanıcı seçmeden dosya üretme.
```

Replace with:

```markdown
- **Ticket-key sorusu (zorunlu SOR, varsayma):** commit mesajında ticket-key zorlansın mı?
  Varsayılan **zorlamasız** (hook hiçbir şeyi bloklamaz). Kullanıcı isterse formatı da sor —
  standart `ABC-1234` mi, özel regex mi? Cevaba göre Faz 3 sonrasında:
  `git config vibe.ticketre '^[A-Z]{3}-[0-9]{1,4} '` (ya da kullanıcının regex'i). İstemezse hiçbir şey yapma.
- **doc-sync sorusu (zorunlu SOR, varsayma):** "doc-sync'i zorlayıcı (blocking) yapayım mı?" — kaynak
  değişip doküman değişmezse commit'i engellesin mi? Varsayılan **öneri EVET** (ticket-key'in aksine —
  ama yine de sorulur, kullanıcı hayır diyebilir). Evet ise Faz 3 sonrasında: `git config vibe.strictdocs
  true` çalıştır. Hayır ise hiçbir şey yapma (hook advisory kalır).
- **Hangi maddeleri kuralım?** diye sor. Kullanıcı seçmeden dosya üretme.
```

- [ ] **Step 2: `SKILL.md` — Faz 4's pre-commit description mentions the new mechanism**

Find:

```markdown
  doc-sync default advisory (`STRICT_DOCS=1` ile blocking). `git config core.hooksPath .githooks` +
  `git config commit.template .gitmessage` öner.
```

Replace with:

```markdown
  doc-sync default advisory (`git config vibe.strictdocs true` ile blocking — Faz 2'de sordun).
  `git config core.hooksPath .githooks` + `git config commit.template .gitmessage` öner.
```

- [ ] **Step 3: `SKILL.md` — Upgrade akışı asks the same question for already-installed repos**

Find:

```markdown
### 2. UPDATE / ADD / MIGRATED — otomatik; sadece bildir
- UPDATE: engine zaten regen etti. Hangileri değişti söyle, `git diff` öner.
- ADD: `bash "$SKILL_DIR/scaffold.sh" init .` eksikleri düşürür (idempotent; var olanı ezmez).
- MIGRATED: ne yapıldığını aktar.
```

Replace with:

```markdown
### 2. UPDATE / ADD / MIGRATED — otomatik; sadece bildir
- UPDATE: engine zaten regen etti. Hangileri değişti söyle, `git diff` öner.
  - `.githooks/pre-commit` UPDATE edildiyse **ve** `git config --get --local vibe.strictdocs` boş
    dönerse: Faz 2'deki AYNI soruyu sor — **"doc-sync'i zorlayıcı (blocking) yapayım mı?"** Evet ise
    `git config vibe.strictdocs true` çalıştır.
- ADD: `bash "$SKILL_DIR/scaffold.sh" init .` eksikleri düşürür (idempotent; var olanı ezmez).
- MIGRATED: ne yapıldığını aktar.
```

- [ ] **Step 4: `README.md` — "Git hook davranışı" section**

Find:

```markdown
- **pre-commit:** fmt, file-capable stack'te (go/node/python/ruby/php/shell) **sadece staged** dosyalar →
  blocking (eski formatsız dosya temiz commit'i bloklamaz); java/rust/dotnet'te repo-geneli → advisory,
  asıl kapı CI. lint advisory. doc-sync advisory (`STRICT_DOCS=1` → blocking). Tool kurulu değilse atlar.
```

Replace with:

```markdown
- **pre-commit:** fmt, file-capable stack'te (go/node/python/ruby/php/shell) **sadece staged** dosyalar →
  blocking (eski formatsız dosya temiz commit'i bloklamaz); java/rust/dotnet'te repo-geneli → advisory,
  asıl kapı CI. lint advisory. doc-sync advisory (`git config vibe.strictdocs true` → blocking,
  `vibe.ticketre` ile aynı desen). Tool kurulu değilse atlar.
```

- [ ] **Step 5: Verify all edits landed**

Run: `grep -n "vibe.strictdocs" skills/vibe-setup/SKILL.md README.md skills/vibe-setup/scaffold.sh`
Expected: at least 6 matching lines spread across the three files (SKILL.md: Faz 2 question + Faz 4
mention + Upgrade akışı note = 3 mentions across those blocks; README.md: 1; scaffold.sh: header
comment + doc-sync check = 2).

- [ ] **Step 6: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED` (documentation-only task, but confirms nothing else broke).

- [ ] **Step 7: Commit**

```bash
git add skills/vibe-setup/SKILL.md README.md
git commit -m "$(cat <<'EOF'
VIB-13 SKILL.md/README: doc-sync zorlayicilik sorusu + git config vibe.strictdocs dokumante et

Faz 2'ye yeni soru (varsayilan oneri EVET), Faz 4'un pre-commit
aciklamasi guncellendi, Upgrade akisina zaten kurulu repolar icin ayni
soruyu sorma notu eklendi. README'nin Git hook davranisi bolumu yeni
mekanizmayi yansitiyor.
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:** Mekanizma değişikliği (`render_precommit`, env-var → git-config) → Task 1 Steps 5-6. SKILL.md Faz 2 yeni soru → Task 2 Step 1. `render_precommit()` sürüm etkisi (`VIBE_VERSION` 4→5, `artifact_changed_in` 2→5) → Task 1 Steps 3-4. Kapsam (yeni + var olan repolar, upgrade akışı notu) → Task 2 Step 3. README güncellemesi → Task 2 Step 4. Kapsam dışı maddeler (bu repo'nun kendi opt-in kararı, ayrı env-var bypass, STRICT_DOCS geriye-uyumluluğu) — hiçbiri implemente edilmedi, bilinçli olarak dışarıda.

**Placeholder scan:** no TBD/TODO; every step shows complete file content or exact find/replace text; `tests/upgrade_test.sh`'in 6 hardcoded-değer düzeltmesi tek tek gösterildi, "benzer şekilde güncelle" gibi bir yönlendirme yok.

**Type/name consistency:** `vibe.strictdocs` (git config key) Task 1'in `render_precommit()` değişikliğinde, testlerinde, ve Task 2'nin SKILL.md/README metinlerinde birebir aynı isimle geçiyor. `VIBE_VERSION=5` ve `artifact_changed_in ".githooks/pre-commit" → 5` Task 1 içinde tutarlı; `AGENTS.md`'nin kendi `v: 4` değeri (ayrı, dokunulmamış bir alan) Step 9'un notunda açıkça "değiştirilmeyecek" diye işaretlendi — bu, bir önceki oturumda (VIB-12) benzer bir karışıklığın kontrol edilmesi gereken tam nokta.
