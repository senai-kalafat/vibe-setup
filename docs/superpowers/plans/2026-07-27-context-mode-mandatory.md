# context-mode Mandatory Dependency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the context-mode MCP plugin a mandatory (no longer optional/excluded) dependency that every vibe-setup run installs and wires — a deterministic presence check in `scaffold.sh audit`, plus an unconditional install+wire flow in `SKILL.md` for Claude Code, Cursor, and Antigravity, with paste-ready (non-mandatory) snippets for Codex CLI/Gemini CLI (non-Antigravity)/Kimi Code.

**Architecture:** Three independent edits. (1) `scaffold.sh` gains one new `have context-mode` audit row — reuses the existing `have()` helper, zero new bash machinery. (2) `SKILL.md`'s Faz 3 gains an unconditional context-mode install+wire sub-flow: `npm install -g context-mode` (universal), then JSON-merge instructions for `.claude/settings.json` (always) and `.cursor/mcp.json` (if Cursor was selected) — both repo-tracked files the LLM edits directly with Read/Edit (no bash JSON-merge code needed) — plus a transparent edit of Antigravity's user-global MCP config file. (3) `SKILL.md`'s Faz 6 gains paste-ready (opt-in) snippets for the three remaining tools, and the old "don't embed universal personal tools" principle bullet is deleted outright.

**Tech Stack:** Bash (`scaffold.sh`, reusing the existing `have()`/`row()` helpers), Markdown (`SKILL.md`), bash test harness (`tests/audit_test.sh`).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-27-context-mode-mandatory-design.md` (approved).
- No new bash helper functions needed in `scaffold.sh` for the audit check — reuse the existing `have()` (`command -v "$1"`) exactly as it's already used for `jq`/`shellcheck`/`shfmt` elsewhere in this codebase.
- `scaffold.sh` must NOT gain any JSON-merge code. All three JSON-file edits (`.claude/settings.json`, `.cursor/mcp.json`, Antigravity's global config) are instructions for the LLM running the SKILL.md flow to perform directly with its own Read/Edit tools — this is deliberate, matches the existing "Deterministik" vs "Akıllı (LLM)" architecture split documented in this repo's `CLAUDE.md`.
- The context-mode install/wire flow in Faz 3 is **unconditional** — it runs on every vibe-setup pass, never gated behind a user question (this is the entire point of "mandatory").
- Cursor's `.cursor/mcp.json` wiring only happens when the user selected Cursor in Faz 2 (i.e., when `init-cursor` is also being run this pass) — no point creating Cursor MCP config in a repo that isn't being set up for Cursor.
- Antigravity's global MCP config edit is the one deliberate exception to vibe-setup's "repo-only" scope — the flow text must make this explicit and transparent to whoever is running the skill (state which file is being edited, not silently).
- Codex CLI / Gemini CLI (non-Antigravity) / Kimi Code get paste-ready snippets in Faz 6's existing user-action table pattern — NOT auto-installed, NOT mandatory.
- Exact JSON shapes (verified against this repo's own working context-mode installation, not guessed):
  - Claude Code `.claude/settings.json` additions:
    ```json
    "extraKnownMarketplaces": {
      "context-mode": { "source": { "source": "github", "repo": "mksglu/context-mode" } }
    },
    "enabledPlugins": {
      "context-mode@context-mode": true
    }
    ```
  - Cursor `.cursor/mcp.json` additions (standalone project MCP config — NOT the `${CLAUDE_PLUGIN_ROOT}`-relative form, which only resolves inside Claude's own plugin runtime):
    ```json
    "mcpServers": {
      "context-mode": { "command": "npx", "args": ["-y", "context-mode"] }
    }
    ```
  - Antigravity CLI (`agy`) global config `~/.gemini/config/mcp_config.json`, Antigravity IDE `~/.gemini/antigravity/mcp_config.json` — same `mcpServers` shape:
    ```json
    "mcpServers": {
      "context-mode": { "command": "context-mode" }
    }
    ```
- Commit ticket key: `VIB-9` (per this repo's `.githooks/commit-msg` convention, `^[A-Z]{3}-[0-9]{1,4} `).
- Test runner: `bash tests/run.sh` from repo root.

---

### Task 1: `scaffold.sh audit` — context-mode presence check

**Files:**
- Modify: `skills/vibe-setup/scaffold.sh:149-150` (the `EKLENTİ / HOOK` audit block)
- Test: `tests/audit_test.sh` (extend)

**Interfaces:**
- Consumes: the existing `have()` helper (`skills/vibe-setup/scaffold.sh`, already defined: `have() { command -v "$1" >/dev/null 2>&1; }`) and `row()` (existing OK/NO/NA printer).
- Produces: nothing consumed by other tasks — this is a self-contained audit row addition.

This mirrors the exact existing pattern used for `jq` (checked via `have jq` in the same function) — no new mechanism, just one more row.

- [ ] **Step 1: Add the audit row**

In `skills/vibe-setup/scaffold.sh`, find:

```bash
  echo "EKLENTİ / HOOK"
  has_file .githooks/pre-commit && row "$OK" ".githooks/pre-commit" || row "$NO" ".githooks/pre-commit" "init düşürür"
```

Replace with:

```bash
  echo "EKLENTİ / HOOK"
  have context-mode && row "$OK" "context-mode" || row "$NO" "context-mode" "npm install -g context-mode"
  has_file .githooks/pre-commit && row "$OK" ".githooks/pre-commit" || row "$NO" ".githooks/pre-commit" "init düşürür"
```

- [ ] **Step 2: Add test coverage in `tests/audit_test.sh`**

This machine may or may not have `context-mode` on PATH, so the test must check whichever branch is actually true — this is the same pattern already used for `jq`-conditional tests elsewhere in this repo (e.g. `tests/init_test.sh`'s `if command -v jq >/dev/null 2>&1; then ... fi` guard).

In `tests/audit_test.sh`, find:

```bash
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

echo "audit_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 3: Run the affected test**

Run: `bash tests/audit_test.sh`
Expected: `audit_test: N passed, 0 failed`, no `FAIL` lines.

- [ ] **Step 4: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add skills/vibe-setup/scaffold.sh tests/audit_test.sh
git commit -m "$(cat <<'EOF'
VIB-9 scaffold.sh: audit'e context-mode varlik kontrolu ekle

have() helper'i tekrar kullanarak EKLENTI/HOOK bolumune context-mode
satiri eklendi (jq/shellcheck ile ayni desen). Eksikse SCORE'a dahil
edilir (--, opsiyonel degil).
EOF
)"
```

---

### Task 2: SKILL.md Faz 3 — unconditional context-mode install+wire flow

**Files:**
- Modify: `skills/vibe-setup/SKILL.md` (Faz 3 "Agnostik iskeletler" section)

**Interfaces:**
- Consumes: nothing new — this is orchestration prose describing shell commands (`npm install -g context-mode`) and JSON-merge instructions for the LLM to perform itself.
- Produces: nothing consumed by Task 3 (Task 3 touches unrelated locations: Faz 4's "Plugin/MCP paylaşımı" bullet and Faz 6's user-action table).

This is the core of the feature — the actual mandatory install+wire instructions. It's one cohesive sub-flow (can't meaningfully split "install for Claude" from "install for Cursor" — they're steps of the same unconditional pass), so it's one task with its own verification.

- [ ] **Step 1: Insert the context-mode sub-flow into Faz 3**

In `skills/vibe-setup/SKILL.md`, find:

```markdown
### 3. Agnostik iskeletler
- `bash "$SKILL_DIR/scaffold.sh" init .` → AGENTS.md, docs/ + ADR template, .gitmessage,
  PR/MR template (VCS'e göre GitHub `.github/` ya da GitLab `.gitlab/merge_request_templates/`),
  .githooks/pre-commit (stack komutları + fmt-scope substitüe edilmiş),
  .githooks/commit-msg (ticket-key OPSİYONEL: `git config vibe.ticketre` set edilirse zorlar —
  Faz 2'de kullanıcıya sordun; ayarsız = bloklamaz), .claude/settings.json iskeleti.
- Kullanıcı **Cursor** dediyse: `bash "$SKILL_DIR/scaffold.sh" init-cursor .` → `.cursor/rules/project.mdc`
  + `.cursorrules` (ikisi de CLAUDE.md'ye yönlendirir).
- Kullanıcı **Gemini** dediyse: `bash "$SKILL_DIR/scaffold.sh" init-gemini .` → `GEMINI.md`
  (`@CLAUDE.md` importu — Gemini CLI içeriği doğrudan çeker, pointer değil).
- Script var olanı **ezmez** (SKIP). Çıktıdaki NEW/SKIP/EDIT'i kullanıcıya aktar.
```

Replace with:

```markdown
### 3. Agnostik iskeletler
- `bash "$SKILL_DIR/scaffold.sh" init .` → AGENTS.md, docs/ + ADR template, .gitmessage,
  PR/MR template (VCS'e göre GitHub `.github/` ya da GitLab `.gitlab/merge_request_templates/`),
  .githooks/pre-commit (stack komutları + fmt-scope substitüe edilmiş),
  .githooks/commit-msg (ticket-key OPSİYONEL: `git config vibe.ticketre` set edilirse zorlar —
  Faz 2'de kullanıcıya sordun; ayarsız = bloklamaz), .claude/settings.json iskeleti.
- Kullanıcı **Cursor** dediyse: `bash "$SKILL_DIR/scaffold.sh" init-cursor .` → `.cursor/rules/project.mdc`
  + `.cursorrules` (ikisi de CLAUDE.md'ye yönlendirir).
- Kullanıcı **Gemini** dediyse: `bash "$SKILL_DIR/scaffold.sh" init-gemini .` → `GEMINI.md`
  (`@CLAUDE.md` importu — Gemini CLI içeriği doğrudan çeker, pointer değil).
- **context-mode kurulumu (HER ZAMAN, sorulmadan — zorunlu bağımlılık, artık opsiyonel değil):**
  1. `npm install -g context-mode` çalıştır, çıktıyı kullanıcıya göster.
  2. `.claude/settings.json`'ı **oku** (bu noktada `init .` zaten oluşturmuş olmalı), mevcut içeriğe
     aşağıdaki iki alanı **merge et** — var olan `permissions` ya da başka marketplace/plugin
     girdilerini **ezme**, sadece ekle/genişlet:
     ```json
     "extraKnownMarketplaces": {
       "context-mode": { "source": { "source": "github", "repo": "mksglu/context-mode" } }
     },
     "enabledPlugins": {
       "context-mode@context-mode": true
     }
     ```
  3. Kullanıcı **Cursor** dediyse: repo kökünde `.cursor/mcp.json`'ı oku (yoksa oluştur), `mcpServers`
     içine context-mode'u ekle — var olan sunucuları koru, ezme:
     ```json
     "mcpServers": {
       "context-mode": { "command": "npx", "args": ["-y", "context-mode"] }
     }
     ```
  4. **Antigravity için (agy CLI ya da IDE) — tek istisna, repo dışına yazılır:**
     `~/.gemini/config/mcp_config.json` (agy CLI) veya `~/.gemini/antigravity/mcp_config.json`
     (Antigravity IDE) dosyasını oku (yoksa oluştur), `mcpServers` içine context-mode'u ekle —
     var olan sunucuları koru, ezme:
     ```json
     "mcpServers": {
       "context-mode": { "command": "context-mode" }
     }
     ```
     Bu, vibe-setup'ın normalde dokunmadığı bir kapsam (kullanıcının home dizini, repo değil) —
     kullanıcıya **hangi dosyayı düzenlediğini açıkça söyle**, sessizce yapma.
- Script var olanı **ezmez** (SKIP). Çıktıdaki NEW/SKIP/EDIT'i kullanıcıya aktar.
```

- [ ] **Step 2: Verify the edit landed correctly**

Run: `grep -n "npm install -g context-mode\|extraKnownMarketplaces\|antigravity/mcp_config.json\|config/mcp_config.json" skills/vibe-setup/SKILL.md`

Expected: at least 4 matching lines, all inside the new Faz 3 sub-bullet (no matches anywhere else in the file yet — Task 3 hasn't run).

- [ ] **Step 3: Verify placement — still inside Faz 3, not spilling into Faz 4**

Run: `grep -n "^### " skills/vibe-setup/SKILL.md`

Expected: `### 3. Agnostik iskeletler` immediately followed by `### 4. Stack-bağımlı içerik ...` with no new `###` heading introduced in between — confirms the new content is a sub-bullet of Faz 3, not an accidental new phase.

- [ ] **Step 4: Commit**

```bash
git add skills/vibe-setup/SKILL.md
git commit -m "$(cat <<'EOF'
VIB-9 SKILL.md: context-mode'u Faz 3'te zorunlu kur

npm install -g context-mode + .claude/settings.json (her zaman) ve
.cursor/mcp.json (Cursor secildiyse) JSON-merge talimati + Antigravity
icin tek repo-disi istisna (kullaniciya seffaf sekilde global config
duzenlenir).
EOF
)"
```

---

### Task 3: SKILL.md — paste-ready snippets + remove the old exclusion principle

**Files:**
- Modify: `skills/vibe-setup/SKILL.md` (Faz 4's "Plugin/MCP paylaşımı" bullet, Faz 6's user-action table)

**Interfaces:**
- Consumes: nothing from Task 2 (touches different locations in the same file — Faz 4 and Faz 6, while Task 2 touched Faz 3).
- Produces: nothing consumed elsewhere — final documentation task in this plan.

- [ ] **Step 1: Delete the old "don't embed universal tools" principle bullet**

In `skills/vibe-setup/SKILL.md`, find:

```markdown
  - **Sadece projeye-özgü MCP'yi repoya sabitle** — bu projenin DB'si, iç API doküman MCP'si, Jira board'u
    gibi ekibin ortak kullandığı, domaine bağlı sunucular. Kullanıcıya **"ekibe sabitlenecek projeye-özgü
    MCP var mı?"** diye sor; saydığını pin'le. İki ürünü preselect etme.
  - **Evrensel kişisel araçları repoya GÖMME** (context-mode, context7 vb. — context penceresi/doküman
    yardımcıları). Projeden bağımsız faydalılar → `~/.claude/settings.json` (user-global) öner; repo-pin'lersen
    global'i olanda mükerrer, olmayana dayatma + marketplace erişimi şartı olur.
```

Replace with:

```markdown
  - **Sadece projeye-özgü MCP'yi repoya sabitle** — bu projenin DB'si, iç API doküman MCP'si, Jira board'u
    gibi ekibin ortak kullandığı, domaine bağlı sunucular. Kullanıcıya **"ekibe sabitlenecek projeye-özgü
    MCP var mı?"** diye sor; saydığını pin'le. İki ürünü preselect etme.
```

(This deletes the "Evrensel kişisel araçları repoya GÖMME" bullet entirely — no replacement text. context-mode is no longer an excluded universal tool; it's handled unconditionally in Faz 3, per Task 2.)

- [ ] **Step 2: Add the paste-ready snippet block to Faz 6's user-action table**

In `skills/vibe-setup/SKILL.md`, find:

```markdown
  | Dosya | Gereken aksiyon |
  |---|---|
  | CLAUDE.md | `<TODO>` gotchas'ı tribal bilgiyle doğrula |
  | llms.txt / docs | `<TODO>` placeholder'ları doldur |
  | .gitmessage | `<TICKET-KEY>` formatını projeye uyarla |
  | .claude/settings.json | plugin enable / deny yolları onayı (gerekirse) |
  | … | (sadece gerçekten eksik/insan-gerektiren satırlar) |

  Sadece **açık kalan** maddeleri listele; tamamlananları koyma.
  - **Classifier-bloklanan satırlar** (permissions.allow/deny, plugin enable, MCP pin) için: tabloda
    "snippet'i ekle" demekle yetinme — **paste-hazır snippet'i tablonun hemen altına göm** (hangi dosya,
    hangi anahtar, tam içerik). Aksiyon kendi içinde tamamlanabilir olmalı.
```

Replace with:

```markdown
  | Dosya | Gereken aksiyon |
  |---|---|
  | CLAUDE.md | `<TODO>` gotchas'ı tribal bilgiyle doğrula |
  | llms.txt / docs | `<TODO>` placeholder'ları doldur |
  | .gitmessage | `<TICKET-KEY>` formatını projeye uyarla |
  | .claude/settings.json | plugin enable / deny yolları onayı (gerekirse) |
  | Codex CLI / Gemini CLI (Antigravity dışı) / Kimi Code | context-mode MCP kaydı (opsiyonel — zorunlu değil) |
  | … | (sadece gerçekten eksik/insan-gerektiren satırlar) |

  Sadece **açık kalan** maddeleri listele; tamamlananları koyma.
  - **Classifier-bloklanan satırlar** (permissions.allow/deny, plugin enable, MCP pin) için: tabloda
    "snippet'i ekle" demekle yetinme — **paste-hazır snippet'i tablonun hemen altına göm** (hangi dosya,
    hangi anahtar, tam içerik). Aksiyon kendi içinde tamamlanabilir olmalı.
  - **Codex CLI / Gemini CLI (Antigravity dışı) / Kimi Code için context-mode:** zorunlu değil (Faz 3
    sadece Claude/Cursor/Antigravity'yi zorunlu kurar) — satır tabloda kalıyorsa paste-hazır snippet'i
    tablonun hemen altına göm:
    - Codex CLI (`~/.codex/config.toml`, `[mcp_servers]` bölümü):
      ```toml
      [mcp_servers.context-mode]
      command = "context-mode"
      ```
    - Gemini CLI (`~/.gemini/settings.json`, `mcpServers`):
      ```json
      "mcpServers": { "context-mode": { "command": "context-mode" } }
      ```
    - Kimi Code (`~/.kimi-code/mcp.json`, `mcpServers`):
      ```json
      "mcpServers": { "context-mode": { "command": "context-mode" } }
      ```
```

- [ ] **Step 3: Verify both edits**

Run: `grep -n "Evrensel kişisel araçları\|context-mode MCP kaydı\|mcp_servers.context-mode" skills/vibe-setup/SKILL.md`

Expected: NO match for `Evrensel kişisel araçları` (deleted); matches for `context-mode MCP kaydı` (table row) and `mcp_servers.context-mode` (Codex snippet).

- [ ] **Step 4: Run the full test suite as a final sanity check**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED` (this task doesn't touch any tested code path, but confirms nothing else broke).

- [ ] **Step 5: Commit**

```bash
git add skills/vibe-setup/SKILL.md
git commit -m "$(cat <<'EOF'
VIB-9 SKILL.md: eski context-mode disarida-tutma ilkesini kaldir + Codex/Gemini/Kimi snippet ekle

"Evrensel kisisel araclari repoya GOMME" kurali tamamen silindi (context-mode
artik istisna degil, Faz 3'te zorunlu). Codex/Gemini(Antigravity disi)/Kimi
Code icin opsiyonel paste-hazir MCP snippet'i Faz 6 tablosuna eklendi.
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:** every numbered kapsam kararı in the spec (npm install -g always; Claude mandatory repo-tracked; Cursor mandatory repo-tracked when selected; Antigravity mandatory global with transparency; Codex/Gemini(non-Antigravity)/Kimi snippet-only; new audit row; old principle bullet deleted) has a corresponding task/step. The spec's "kapsam dışı" exclusions (no scaffold.sh JSON-merge code, no auto-install for the three snippet-only tools, no context-mode hook/routing configuration beyond MCP registration) are honored by construction — no task does any of those things.

**Placeholder scan:** no TBD/TODO; every step shows complete text, not a description of what to write.

**Type/name consistency:** `have context-mode` (Task 1) uses the pre-existing `have()` helper unchanged. The JSON shapes quoted in Task 2's Faz 3 edit and the Global Constraints section are identical (same keys, same values) — no drift between what the constraints promise and what the task actually writes. Task 3's snippet block for Codex/Gemini/Kimi correctly reflects that Task 2 only mandated Claude/Cursor/Antigravity, not these three.
