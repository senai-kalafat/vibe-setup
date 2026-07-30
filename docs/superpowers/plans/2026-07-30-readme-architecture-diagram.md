# README Architecture Diagram (VIB-14) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a top-level architecture diagram in target repos' `README.md` a mechanically-audited, strongly-signaled requirement (not just checklist prose) — a clean mermaid system-context diagram at the top for first-time readers, with detailed diagrams pushed to `docs/architecture/overview.md`.

**Architecture:** One new mechanical check in `scaffold.sh`'s `audit()` (mirrors the existing `test suite` NA/OK/NO pattern exactly), plus a documentation/instruction pass across `SKILL.md` (new mandatory Faz 4 deliverable + Faz 6 conscious-skip note), `vibe-checklist-template.md` (split existing item), and a small stub-wording tweak in `render_artifact()`'s `docs/README.md` template. No `VIBE_VERSION` bump — `README.md` is not in `managed_paths()`, so this is an audit-check addition, not a managed-file-schema change (same class as the existing `context-mode` audit row).

**Tech Stack:** Pure bash (`scaffold.sh`'s existing style — no new dependencies). Bash test harness (`tests/*_test.sh`, auto-discovered by `tests/run.sh`).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-30-readme-architecture-diagram-design.md` (VIB-14).
- Diagram format: mermaid only (fenced ` ```mermaid ` block) — no alternative formats considered.
- Location split: README.md gets a **summary** diagram only (system-context level — the project as one box, external connections around it: DB, external APIs, 3rd-party services, users/clients — not module-level detail). Detailed diagrams (module/component, data flow) go in `docs/architecture/overview.md`, linked from README.
- The new `audit()` check is a **strong default signal** (❌ when missing), not an `(ops)`/NA-by-default item like `llms.txt`.
- No blind enforcement: a project genuinely unsuited to a diagram (e.g. a trivial single-file script) may consciously skip it — the ❌ row stays, but `SKILL.md`'s Faz 6 user-action table must surface *why* it was skipped rather than silently ignoring it.
- `README.md` is **not** in `managed_paths()` — `scaffold.sh` never creates or renders it, only audits it. This new check therefore requires **no `VIBE_VERSION` bump** and no `artifact_changed_in` entry — it's purely a new audit row, the same class as the existing `context-mode` check.
- `docs/README.md`'s `artifact_class` is `seed` (drops once, then user-owned) — the stub-wording tweak in this plan only reaches *newly-init'd* repos; already-installed repos' `docs/README.md` is never touched by `upgrade` (seed files are never auto-updated). This is intentional, matching seed semantics everywhere else in this codebase.
- Commit ticket key: `VIB-14` (this repo's `.githooks/commit-msg` enforces `^[A-Z]{3}-[0-9]{1,4} `).
- Test runner: `bash tests/run.sh` from repo root — auto-discovers every `tests/*_test.sh`.

---

### Task 1: `audit()` mechanical check + test

**Files:**
- Modify: `skills/vibe-setup/scaffold.sh` (`audit()`'s `BAĞLAM` section)
- Modify: `tests/audit_test.sh` (3 new cases)

**Interfaces:**
- Consumes: existing `has_file()`, `row()`, `$OK`/`$NO`/`$NA` globals — no new helpers introduced.
- Produces: a new audit row labeled `"README mimari diagramı"` in `BAĞLAM`. Task 2's `SKILL.md`/`vibe-checklist-template.md` prose refers to this row by the same label — must match exactly.

- [ ] **Step 1: Write the failing tests**

Open `tests/audit_test.sh`. Find:

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

# 6. README mimari diagramı — 3 durum: README yok (NA), README var ama mermaid yok (❌), mermaid var (✅)
no_readme="$tmp/no-readme"; mkdir -p "$no_readme"
out6="$(bash "$SCAFFOLD" audit "$no_readme" 2>/dev/null)"
printf '%s' "$out6" | grep -qE '— +README mimari diagramı' && ok "README yok: diagram satırı NA" || bad "README yok: diagram satırı NA değil"

no_diagram="$tmp/no-diagram"; mkdir -p "$no_diagram"
echo "# proje" > "$no_diagram/README.md"
out7="$(bash "$SCAFFOLD" audit "$no_diagram" 2>/dev/null)"
printf '%s' "$out7" | grep -qE '❌ +README mimari diagramı' && ok "README var, diagram yok: ❌ basıyor" || bad "diagram yok ama ❌ basmadı"

with_diagram="$tmp/with-diagram"; mkdir -p "$with_diagram"
printf '# proje\n\n```mermaid\nflowchart TD\n  A --> B\n```\n' > "$with_diagram/README.md"
out8="$(bash "$SCAFFOLD" audit "$with_diagram" 2>/dev/null)"
printf '%s' "$out8" | grep -qE '✅ +README mimari diagramı' && ok "README diagram içeriyor: ✅ basıyor" || bad "diagram var ama ✅ basmadı"

echo "audit_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `bash tests/audit_test.sh`
Expected: FAIL on the 3 new assertions — `audit()` doesn't emit a `"README mimari diagramı"` row yet, so none of the three `grep` patterns match anything.

- [ ] **Step 3: Add the mechanical check to `audit()`**

Find:

```bash
  has_file llms.txt    && row "$OK" "llms.txt (ops)" || row "$NA" "llms.txt (ops)" "opsiyonel: dış LLM tüketicisi varsa"
  has_file README.md   && row "$OK" "README.md" || row "$NO" "README.md" "yok"
  echo "BİLGİ TABANI"
```

Replace with:

```bash
  has_file llms.txt    && row "$OK" "llms.txt (ops)" || row "$NA" "llms.txt (ops)" "opsiyonel: dış LLM tüketicisi varsa"
  has_file README.md   && row "$OK" "README.md" || row "$NO" "README.md" "yok"
  if ! has_file README.md; then row "$NA" "README mimari diagramı" "README.md yok"
  elif grep -q '```mermaid' README.md; then row "$OK" "README mimari diagramı"
  else row "$NO" "README mimari diagramı" "LLM: üst-seviye özet diagram ekle (dış bağlantılar + ne iş yaptığı) — docs/architecture/overview.md'ye detay linki ver"
  fi
  echo "BİLGİ TABANI"
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `bash tests/audit_test.sh`
Expected: `audit_test: 11 passed, 0 failed`, no `FAIL` lines.

- [ ] **Step 5: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 6: Commit**

```bash
git add skills/vibe-setup/scaffold.sh tests/audit_test.sh
git commit -m "$(cat <<'EOF'
VIB-14 scaffold.sh: audit() README mimari diagram kontrolu ekle

BAGLAM kategorisine yeni satir: README.md icinde \`\`\`mermaid yoksa
NO (guclu varsayilan sinyal, llms.txt gibi (ops)/NA degil), README.md
hic yoksa NA (mevcut "test suite" NA/OK/NO deseniyle ayni). VIBE_VERSION
bump gerekmiyor - README.md managed_paths'te degil.
EOF
)"
```

---

### Task 2: `SKILL.md` + `vibe-checklist-template.md` + stub wording

**Files:**
- Modify: `skills/vibe-setup/SKILL.md`
- Modify: `skills/vibe-setup/vibe-checklist-template.md`
- Modify: `skills/vibe-setup/scaffold.sh` (`render_artifact()`'s `docs/README.md` template — text-only tweak)

**Interfaces:**
- Consumes: the `"README mimari diagramı"` audit row label from Task 1 — referenced by name in prose, must match.
- Produces: nothing consumed by other tasks — final task in this plan.

- [ ] **Step 1: `SKILL.md` — Faz 4 gets the new mandatory deliverable**

Find:

```markdown
- **docs**: iskeletteki `<TODO>`'ları gerçek içerikle değiştir (kod haritası, conventions).
- **(ops) llms.txt**: init bunu **düşürmez** (iç repoda tüketicisi yok). Sadece dış LLM/dokümantasyon
  sitesi tüketecekse `llmstxt.org` formatında elle ekle.
```

Replace with:

```markdown
- **docs**: iskeletteki `<TODO>`'ları gerçek içerikle değiştir (kod haritası, conventions).
- **README mimari diagramı (zorunlu deliverable):** README.md'nin başına (girişten hemen sonra) tek bir
  mermaid diagram + 2-3 cümle özet ekle — proje tek kutu, çevresinde **dış bağlantılar** (DB, harici
  API'ler, 3rd-party servisler, kullanıcı/istemci). Çok detaya girme, sadece sistem-sınırı görünümü.
  Repoyu **oku**, gerçek bağlantıları çıkar — uydurma. Proje gerçekten diagram'a uygun değilse (ör.
  tek-dosyalık script), Faz 6'da bunu gerekçeli olarak not düş — sessizce atlama.
  `docs/architecture/overview.md`'ye (`<TODO>`'yu doldurarak) daha DETAYLI diagramlar (modül/veri akışı)
  ekle, README'ye link ver.
- **(ops) llms.txt**: init bunu **düşürmez** (iç repoda tüketicisi yok). Sadece dış LLM/dokümantasyon
  sitesi tüketecekse `llmstxt.org` formatında elle ekle.
```

- [ ] **Step 2: `SKILL.md` — Faz 6's kullanıcı-aksiyon tablosu gets a conscious-skip row**

Find:

```markdown
  | Dosya | Gereken aksiyon |
  |---|---|
  | CLAUDE.md | `<TODO>` gotchas'ı tribal bilgiyle doğrula |
  | llms.txt / docs | `<TODO>` placeholder'ları doldur |
  | .gitmessage | `<TICKET-KEY>` formatını projeye uyarla |
  | .claude/settings.json | plugin enable / deny yolları onayı (gerekirse) |
  | Codex CLI / Gemini CLI (Antigravity dışı) / Kimi Code | context-mode MCP kaydı (opsiyonel — zorunlu değil) |
  | … | (sadece gerçekten eksik/insan-gerektiren satırlar) |
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
  | README mimari diagramı | bilinçli atlandıysa: neden (proje uygun değil) burada gerekçelendirilir |
  | … | (sadece gerçekten eksik/insan-gerektiren satırlar) |
```

- [ ] **Step 3: `vibe-checklist-template.md` — split the existing item**

Find:

```markdown
## BAĞLAM
- [ ] CLAUDE.md — yalın, emir kipli, docs'a **işaret eder** (içerik dökmez)
- [ ] Root README — hızlı başlangıç + linkler
- [ ] AGENTS.md — CLAUDE.md'ye ayna (çapraz araç); gerekirse GEMINI.md
```

Replace with:

```markdown
## BAĞLAM
- [ ] CLAUDE.md — yalın, emir kipli, docs'a **işaret eder** (içerik dökmez)
- [ ] Root README — hızlı başlangıç + linkler
- [ ] README mimari diagramı — üst-seviye özet (mermaid, dış bağlantılar + ne iş yaptığı; çok detaya girmez)
- [ ] AGENTS.md — CLAUDE.md'ye ayna (çapraz araç); gerekirse GEMINI.md
```

Find:

```markdown
## BİLGİ TABANI
- [ ] İndeksli docs/ (giriş noktası, ör. docs/README.md)
- [ ] Mimari genel bakış + akış diyagramları (mermaid)
- [ ] ADR'lar (NEDEN) + 0000-template
```

Replace with:

```markdown
## BİLGİ TABANI
- [ ] İndeksli docs/ (giriş noktası, ör. docs/README.md)
- [ ] Detaylı mimari diagramlar (modül/veri akışı; docs/architecture/overview.md)
- [ ] ADR'lar (NEDEN) + 0000-template
```

- [ ] **Step 4: `scaffold.sh` — `docs/README.md` stub wording clarifies "detailed"**

Find:

```bash
## Mimari
- [Genel Bakış](architecture/overview.md) <TODO>
- [Mimari Kararlar (ADR)](architecture/decisions/) — neden böyle yapıldı
```

Replace with:

```bash
## Mimari
- [Genel Bakış](architecture/overview.md) <TODO> — detaylı diagramlar burada (README'deki özet diagrama ek)
- [Mimari Kararlar (ADR)](architecture/decisions/) — neden böyle yapıldı
```

- [ ] **Step 5: Verify all edits landed**

Run: `grep -n "README mimari diagram" skills/vibe-setup/SKILL.md skills/vibe-setup/vibe-checklist-template.md skills/vibe-setup/scaffold.sh`
Expected: at least 4 matching lines (SKILL.md: Faz 4 + Faz 6 = 2; vibe-checklist-template.md: 1;
scaffold.sh: none required to match this exact phrase — the stub tweak doesn't use it, so don't worry
if scaffold.sh doesn't appear here). Also run: `grep -n "detaylı diagramlar" skills/vibe-setup/scaffold.sh
skills/vibe-setup/vibe-checklist-template.md` and confirm both files show a match (stub tweak +
checklist item).

- [ ] **Step 6: Run the full suite**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED` (documentation-only task, but confirms nothing else broke).

- [ ] **Step 7: Commit**

```bash
git add skills/vibe-setup/SKILL.md skills/vibe-setup/vibe-checklist-template.md skills/vibe-setup/scaffold.sh
git commit -m "$(cat <<'EOF'
VIB-14 SKILL.md/checklist: README mimari diagrami zorunlu deliverable olarak dokumante et

Faz 4'e yeni zorunlu madde (README ozet-diagram + docs/architecture/
overview.md detay-diagram), Faz 6'ya bilincli-atlama gerekcelendirme
satiri. vibe-checklist-template.md'deki mevcut madde ikiye ayrildi:
BAGLAM'da README ozeti, BILGI TABANI'nda detayli diagramlar. docs/
README.md sablonundaki stub metni netlestirildi.
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:** Madde 1 (konum: README özet + docs/architecture/overview.md detay) → Task 2 Step 1
(Faz 4 talimatı) + Step 4 (stub tweak). Madde 2 (format: mermaid) → Task 1's `grep -q '```mermaid'`
check + Task 2's Faz 4 talimatı. Madde 3 (audit mekanik kontrol) → Task 1. Madde 4 (bilinçli-atlama) →
Task 2 Step 1 (Faz 4'te not) + Step 2 (Faz 6 tablosu). Madde 5 (SKILL.md değişiklikleri) → Task 2 Steps
1-2. Madde 6 (checklist maddesi ikiye ayrılması) → Task 2 Step 3. Madde 7 (docs/README.md stub) → Task
2 Step 4. Sürüm etkisi (VIBE_VERSION bump yok) → Global Constraints'te açıkça belirtildi, hiçbir task
`VIBE_VERSION`/`artifact_changed_in`'e dokunmuyor.

**Placeholder scan:** no TBD/TODO (spec'in kendi `<TODO>` referansları placeholder değil, mevcut
template'in gerçek, kasıtlı `<TODO>` metni — Task 2 Step 4 bunu aynen koruyor, sadece yanına açıklama
ekliyor).

**Type/name consistency:** `"README mimari diagramı"` audit-row etiketi Task 1'in `row()` çağrısında ve
Task 2'nin SKILL.md/vibe-checklist-template.md metinlerinde birebir aynı ifadeyle geçiyor (küçük
farklarla — "README mimari diagramı" ana etiket, checklist'te "README mimari diagramı — üst-seviye
özet..." olarak genişletiliyor, ama kök ifade tutarlı). `docs/architecture/overview.md` yolu her yerde
aynı — Task 2 Step 1, Step 4, spec'in madde 1'i.
