# Remove Command SKILL.md Wiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `scaffold.sh remove [DIR] [--apply]` (already built, tested, and merged to main) actually reachable by a user running the vibe-setup skill, by adding a trigger + orchestration flow to `skills/vibe-setup/SKILL.md`.

**Architecture:** This is a documentation-only change to one markdown file — no code, no tests. `SKILL.md` gains two things: (1) removal-related trigger phrases in its frontmatter `description` so the skill actually loads when a user asks to remove/undo vibe-setup, and (2) a new `## Remove akışı` section, structurally a sibling of the existing `## Upgrade akışı` section, that walks the LLM running the skill through: dry-run first, show output, explicit confirmation, `--apply`, then a conditional (check-before-asking) git-config cleanup step, then a closing reminder about what was intentionally left untouched.

**Tech Stack:** Markdown prose (no code). Verification is via `grep` checks against the edited file, since there's no test harness for skill orchestration text.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-24-remove-skill-wiring-design.md` (approved).
- Scope is `skills/vibe-setup/SKILL.md` only — no changes to `scaffold.sh` or any other file.
- The new section must be placed as a sibling of `## Upgrade akışı` (after it, before `## İlkeler`) — not nested inside the numbered `## Akış` (init) steps, since removal is a distinct user intent from setup/upgrade.
- Removal is **only** ever triggered by explicit user request — the plan must not add any proactive "want to remove?" prompt anywhere in the existing init/audit/upgrade flows.
- Dry-run (`scaffold.sh remove .`, no `--apply`) must always run and be shown to the user **before** any confirmation is asked, and before `--apply` ever runs.
- If the dry-run's `SİLİNECEK` and `ELLE DÜZENLENMİŞ` sections are both `(yok)`, skip the confirmation step entirely and just report nothing to remove.
- The three git-config keys (`core.hooksPath`, `commit.template`, `vibe.ticketre`) must each be checked with `git config --get <key>` **before** asking the user about it — only ask about (and only unset) keys that are actually set. Never blindly run all three.
- CLAUDE.md / docs/ / tests/ / `.claude/settings.json` content must never be touched by this flow — only mentioned as a closing reminder.
- Ticket key for the commit: `VIB-8` (per this repo's `.githooks/commit-msg` convention, `^[A-Z]{3}-[0-9]{1,4} `).

---

### Task 1: Wire `remove` into SKILL.md (frontmatter + new section)

**Files:**
- Modify: `skills/vibe-setup/SKILL.md` (frontmatter `description`, and the body between `## Upgrade akışı` and `## İlkeler`)

**Interfaces:**
- Consumes: `scaffold.sh remove [DIR] [--apply]` (already built, merged) — this task only writes prose instructing the LLM how to call it, no new script interface is created.
- Produces: nothing consumed by other tasks — this is the only task in the plan.

This is a single, self-contained documentation task: one file, two edits (frontmatter + new section), verified by `grep`, no code paths to test.

- [ ] **Step 1: Update the frontmatter `description` with removal triggers**

In `skills/vibe-setup/SKILL.md`, find:

```yaml
---
name: vibe-setup
description: >
  Audit any repository for AI/agent ("vibe coding") readiness and set up the missing pieces —
  stack- and language-agnostic. Use when the user wants to check or bootstrap a project's
  agent-friendliness: CLAUDE.md, AGENTS.md, llms.txt, docs/ knowledge base + ADRs, a test harness,
  a real (human + AI) git pre-commit hook (fmt/lint/doc-sync), .claude/settings.json permissions,
  commit/PR templates, and the reusable vibe checklist. Also UPGRADES an already-set-up repo to a newer
  skill version: re-applies changed managed templates (e.g. hook fixes) without clobbering human edits.
  Triggers: "vibe checklist", "vibe-setup", "audit this project for agent readiness", "make this repo
  agent/AI friendly", "set up CLAUDE.md and hooks", "vibe-setup güncelle / yeni sürüme geç", "upgrade
  vibe-setup", "boş projeyi vibe checklist'e göre kur". Works for Go, Node/TS, Python, Java, Kotlin,
  Swift, Rust, Ruby, .NET, PHP, Elixir, and blank repos.
---
```

Replace with:

```yaml
---
name: vibe-setup
description: >
  Audit any repository for AI/agent ("vibe coding") readiness and set up the missing pieces —
  stack- and language-agnostic. Use when the user wants to check or bootstrap a project's
  agent-friendliness: CLAUDE.md, AGENTS.md, llms.txt, docs/ knowledge base + ADRs, a test harness,
  a real (human + AI) git pre-commit hook (fmt/lint/doc-sync), .claude/settings.json permissions,
  commit/PR templates, and the reusable vibe checklist. Also UPGRADES an already-set-up repo to a newer
  skill version: re-applies changed managed templates (e.g. hook fixes) without clobbering human edits.
  Also REMOVES what it created (dry-run by default, explicit confirmation before deleting): only
  vibe-setup-created files that are still unchanged, never pre-existing or hand-edited ones.
  Triggers: "vibe checklist", "vibe-setup", "audit this project for agent readiness", "make this repo
  agent/AI friendly", "set up CLAUDE.md and hooks", "vibe-setup güncelle / yeni sürüme geç", "upgrade
  vibe-setup", "boş projeyi vibe checklist'e göre kur", "vibe-setup'ı kaldır", "remove vibe-setup",
  "vibe-remove", "vibe-setup'ı geri al". Works for Go, Node/TS, Python, Java, Kotlin,
  Swift, Rust, Ruby, .NET, PHP, Elixir, and blank repos.
---
```

- [ ] **Step 2: Insert the new `## Remove akışı` section**

Find the exact tail of the `## Upgrade akışı` section, immediately before `## İlkeler`:

```markdown
### 5. Doğrula + kapat
- `audit` tekrar → SCORE. Üretilen/merge edilen her şeyi çalıştırarak doğrula (test/fmt/hook).
- Kısa özet: ne otomatik güncellendi (UPDATE/ADD/MIGRATED), CONFLICT'ler nasıl merge edildi, llm tarafında ne eklendi.

## İlkeler
```

Replace with:

```markdown
### 5. Doğrula + kapat
- `audit` tekrar → SCORE. Üretilen/merge edilen her şeyi çalıştırarak doğrula (test/fmt/hook).
- Kısa özet: ne otomatik güncellendi (UPDATE/ADD/MIGRATED), CONFLICT'ler nasıl merge edildi, llm tarafında ne eklendi.

## Remove akışı (vibe-setup'ı kaldır)

Kullanıcı **açıkça** "kaldır"/"remove"/"geri al" dediğinde çalışır — asla proaktif önerilmez, audit/init/
upgrade akışının hiçbir noktasında "kaldırmak ister misin" diye sorulmaz.

### 1. Dry-run (her zaman önce)
`bash "$SKILL_DIR/scaffold.sh" remove .` — **`--apply` OLMADAN**.
- Çıktı "Manifest yok" derse: "Bu repoda vibe-setup kurulu değil (ya da zaten kaldırılmış)." de, bitir.
- SİLİNECEK **ve** ELLE DÜZENLENMİŞ ikisi de `(yok)` ise: "Kaldırılacak bir şey yok." de, bitir —
  onay isteme.

### 2. Göster + onay
Dry-run çıktısını (SİLİNECEK / ELLE DÜZENLENMİŞ / ÖNCEDEN VARDI / KAPSAM DIŞI) olduğu gibi kullanıcıya
göster — zaten insan-okur, yeniden formatlama yok. Açıkça sor: **"Listelenen dosyaları sileyim mi?"**
Hayır ise dur (dry-run zaten hiçbir şey silmedi).

### 3. Uygula
Evet ise: `bash "$SKILL_DIR/scaffold.sh" remove . --apply`.

### 4. Git config temizliği (sadece gerçekten set edilmişse)
`vibe-remove-report.md`'yi (repo kökü, `--apply` bunu yazdı) oku. Rapor üç git config komutunu
(`core.hooksPath`, `commit.template`, `vibe.ticketre`) koşulsuz listeler — ama hangisinin bu repoda
**gerçekten** set edildiğini scaffold.sh bilmiyor (bunları o set etmedi, sen Faz 2'de sorup set
ettin). Kontrol et:
```
git config --get core.hooksPath
git config --get commit.template
git config --get vibe.ticketre
```
Sadece **boş dönmeyenler** için kullanıcıya sor: "Bu ayarları da kaldırayım mı?" Evet ise sadece
onaylananlar için `git config --unset <key>` çalıştır — hepsini birden değil, tek tek sorulanı.

### 5. Kapanış
- Kapsam dışı hatırlat: CLAUDE.md, docs/, tests/, .claude/settings.json içeriği elle gözden
  geçirilmeli — bunlara hiç dokunulmadı.
- `vibe-remove-report.md`'nin repo kökünde kalıcı kayıt olarak durduğunu söyle (silinmez, bu işlemin
  tek receipt'i).

## İlkeler
```

- [ ] **Step 3: Verify both edits landed correctly**

Run: `grep -n "vibe-setup'ı kaldır\|Remove akışı\|vibe-remove-report.md\|git config --get core.hooksPath" skills/vibe-setup/SKILL.md`

Expected: at least 4 matching lines — one from the frontmatter trigger list, one from the new section's heading, references to `vibe-remove-report.md`, and the `git config --get` check. No errors, no empty output.

- [ ] **Step 4: Sanity-check the file is still valid markdown with correct frontmatter**

Run: `head -20 skills/vibe-setup/SKILL.md`

Expected: the YAML frontmatter block (between the two `---` lines) is well-formed — `description: >` followed by the folded block scalar, ending with the second `---` before `# vibe-setup`. Visually confirm no stray `---` was introduced and the block scalar indentation is consistent with the surrounding lines (2-space continuation, matching the rest of the file).

- [ ] **Step 5: Confirm the new section sits between Upgrade akışı and İlkeler, not inside the numbered Akış**

Run: `grep -n "^## " skills/vibe-setup/SKILL.md`

Expected output order: `## vibe-setup` (the H1, will show as `# vibe-setup` not `##` — ignore), `## Akış (sırayla)`, `## Upgrade akışı ...`, `## Remove akışı (vibe-setup'ı kaldır)`, `## İlkeler` — confirming `## Remove akışı` is a sibling section positioned exactly between Upgrade and İlkeler, not nested under `## Akış`.

- [ ] **Step 6: Commit**

```bash
git add skills/vibe-setup/SKILL.md
git commit -m "$(cat <<'EOF'
VIB-8 SKILL.md: remove komutunu akışa kabla

scaffold.sh remove tamamen çalışıyordu ama skill hiçbir zaman
tetikleyemiyordu. Frontmatter'a tetikleyici ifadeler + ayrı "Remove
akışı" bölümü eklendi: her zaman önce dry-run, açık onay, sonra --apply,
sonra sadece gerçekten set edilmiş git config'leri sorup kaldırma.
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:** every numbered step in the spec's "Değişiklikler" section (frontmatter triggers,
dry-run-first, show-and-confirm, apply, conditional git-config-unset, out-of-scope closing reminder,
report-file-persists closing note) appears verbatim in Step 2's replacement text. The spec's edge
cases (manifest-yok, both-empty skip-confirmation) are both explicit sub-bullets under "### 1.
Dry-run" in the new section. Nothing in the approved spec lacks a corresponding line in this plan.

**Placeholder scan:** no TBD/TODO; every step shows the complete text being written, not a
description of what to write.

**Type/name consistency:** the new section references `$SKILL_DIR/scaffold.sh remove` and
`vibe-remove-report.md`, matching the exact command name and report filename established in
`scaffold.sh` (already merged, unchanged by this plan) — no invented names.
