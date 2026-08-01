# caveman Zorunlu Bağımlılık — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** vibe-setup skill'i kurduğu her repoda caveman'i otomatik kursun (`install.sh --with-init`) ve her session'da aktif olmasını zorlasın — context-mode ile aynı kalıpta.

**Architecture:** İş iki katmana ayrılır. (1) **Deterministik** — `scaffold.sh`'ın `AGENTS.md` template'ine caveman aktivasyon satırı eklenir; bu bir managed-template değişimi olduğu için `VIBE_VERSION` 7→8 bump'ı + `artifact_changed_in` güncellemesi gerekir (repo CLAUDE.md'deki "3 yer" kuralı). (2) **Akıllı (LLM)** — `SKILL.md`'ye Faz 3 kurulum bloğu, Faz 4 CLAUDE.md kuralı + subagent gotcha'sı, Faz 6 fallback satırları, Remove akışına kaldırma yolu. `install.sh` hiçbir testte çalıştırılmaz (ağ + global kurulum).

**Tech Stack:** Saf bash (scaffold.sh), markdown (SKILL.md/CLAUDE.md/ADR), `tests/*_test.sh` (bağımsız, dış dep yok).

**Kaynak spec:** `docs/superpowers/specs/2026-08-02-caveman-mandatory-design.md`

## Global Constraints

- `scaffold.sh` saf bash kalır; tek opsiyonel dep `jq`. **Yeni bağımlılık eklenmez.**
- Testler bağımsız: `bash tests/run.sh` dış dep istemez. **`install.sh` çalıştıran test yazılmaz** (ağ + global kurulum).
- Üretilen dosya içerikleri **Türkçe**.
- Managed template değişiminde **üç yer** birlikte güncellenir: `VIBE_VERSION`, `artifact_changed_in`, template'in kendisi.
- `VIBE_VERSION` (şema sürümü) ≠ `plugin.json` semver'i. **Bu planda `plugin.json` / `marketplace.json` / `.cursor-plugin/plugin.json` sürümlerine DOKUNULMAZ.**
- caveman `managed_paths`'e **girmez**, `artifact_class`'a **girmez**, `audit` satırı **eklenmez**. Tek istisna: `AGENTS.md` içindeki satır (AGENTS.md zaten managed/synced).
- `run_migrations`'a dokunulmaz — dosya-template değişimi `upgrade`'in UPDATE yolu tarafından taşınır.
- Commit mesajı formatı: `VIB-18 emir kipi özet` (repo `.githooks/commit-msg` `vibe.ticketre` deseni zorluyor).
- Branch zaten var: `feat/caveman-mandatory`.

## File Structure

| Dosya | Sorumluluk | İşlem |
|---|---|---|
| `skills/vibe-setup/scaffold.sh` | motor: sürüm, artifact metadata, AGENTS.md template | Modify (3 nokta) |
| `tests/init_test.sh` | init çıktısı + manifest alanları | Modify (v8, caveman satırı) |
| `tests/upgrade_test.sh` | drift/UPDATE/CONFLICT | Modify (v8) + yeni case J |
| `tests/profile_test.sh` | detect_profile alanları | Modify (VIBE_VERSION=8) |
| `skills/vibe-setup/SKILL.md` | LLM orkestrasyon akışı | Modify (Faz 3, 4, 6, Remove) |
| `CLAUDE.md` | bu repo, dogfood gotcha | Modify |
| `docs/architecture/decisions/0001-caveman-zorunlu-bagimlilik.md` | ADR | Create |

---

### Task 1: scaffold.sh — AGENTS.md template + v8 bump

Managed template değişimi. Testler önce güncellenir (v8 + caveman satırı beklenir), kırmızı görülür, sonra motor değişir.

**Files:**
- Modify: `skills/vibe-setup/scaffold.sh:21` (VIBE_VERSION), `:111` (artifact_changed_in), `:274-286` (AGENTS.md template)
- Test: `tests/init_test.sh`, `tests/upgrade_test.sh`, `tests/profile_test.sh`

**Interfaces:**
- Consumes: yok (ilk task).
- Produces: `AGENTS.md` template'inde şu satır — sonraki task'lar (SKILL.md Faz 4, CLAUDE.md) **birebir aynı ifadeyi** kullanır:
  `bu repoda caveman modu (seviye \`full\`) zorunludur — aktif değilse \`/caveman full\` çalıştır. Kod, commit mesajı ve PR metni normal yazılır.`
- Produces: `VIBE_VERSION=8`, `artifact_changed_in AGENTS.md → 8`, AGENTS.md stamp'i `vibe-setup:v8`.

- [ ] **Step 1: init_test.sh — manifest sürümünü v8'e çek + caveman satırı assertion'ı ekle**

`tests/init_test.sh:64` satırını değiştir:

```bash
grep -q '"AGENTS.md": { "v": 8, "sha": "[0-9]*", "created": true' "$pre/.vibe-setup.json" && ok "yeni yazilan AGENTS.md created:true" || bad "AGENTS.md created:true degil"
```

Dosyanın **sonuna** (9. bloktan sonra, `echo` özet satırından önce) yeni blok ekle:

```bash
# 10. AGENTS.md caveman aktivasyon satırı (v8) — template'te olmalı, stamp v8
grep -q 'caveman modu' "$work/AGENTS.md" && ok "AGENTS.md caveman satiri icerir" || bad "AGENTS.md caveman satiri yok"
grep -q '/caveman full' "$work/AGENTS.md" && ok "AGENTS.md /caveman full komutu icerir" || bad "/caveman full komutu yok"
grep -q 'vibe-setup:v8' "$work/AGENTS.md" && ok "AGENTS.md stamp v8" || bad "AGENTS.md stamp v8 degil"
```

- [ ] **Step 2: upgrade_test.sh — tüm v7/v4 literal'lerini v8'e çek**

`tests/upgrade_test.sh` içinde şu **tam** değişiklikler (satır numaraları kaymış olabilir; string eşleşmesiyle bul):

```bash
# satır 22
grep -q '"vibeVersion": 8' "$d/.vibe-setup.json" && ok "vibeVersion=8" || bad "vibeVersion yok/yanlış"
# satır 24
grep -q '"AGENTS.md": { "v": 8' "$d/.vibe-setup.json" && ok "AGENTS.md v8 kayıtlı" || bad "AGENTS.md v kaydı yok"
# satır 79
grep -q '"vibeVersion": 8' "$d/.vibe-setup.json" && ok "manifest v8'e yükseltildi" || bad "manifest sürümü yükselmedi"
# satır 121
grep -q '"AGENTS.md": { "v": 8, "sha": "[0-9]*", "created": false' "$d/.vibe-setup.json" && ok "L: migrate sonrasi AGENTS.md created:false" || bad "L: migrate sonrasi created:false degil"
```

Üç adet `awk` downgrade helper'ında da `7` → `8` (satır 76, 87, 109 — bunlar mevcut sürümü düşürerek eski-manifest simülasyonu yapar, mevcut sürümle eşleşmezse test sessizce anlamsızlaşır):

```bash
awk '{ sub(/"vibeVersion": 8/, "\"vibeVersion\": 1"); print }' "$d/.vibe-setup.json" > "$d/.vibe-setup.json.t" && mv "$d/.vibe-setup.json.t" "$d/.vibe-setup.json"
```

(109. satırdaki hedef `1` değil `2`'dir — orada sadece `8` kısmını değiştir, `"vibeVersion": 2` hedefini koru.)

- [ ] **Step 3: upgrade_test.sh — AGENTS.md için UPDATE + CONFLICT case'i ekle**

Dosyanın sonuna (özet `echo` satırından önce) ekle:

```bash
# J. AGENTS.md v8 geçişi — dokunulmamış eski içerik UPDATE, elle düzenlenmiş CONFLICT
d="$(fresh J1)"
printf '<!-- vibe-setup:v4 (managed) -->\n# Agent Guide\n\nEski icerik.\n' > "$d/AGENTS.md"
set_msha "$d/.vibe-setup.json" "AGENTS.md" "$(shaf "$d/AGENTS.md")"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
printf '%s\n' "$(field "$out" UPDATE)" | grep -q 'AGENTS.md' && ok "J: dokunulmamış eski AGENTS.md → UPDATE" || bad "J: UPDATE beklenirken: '$(field "$out" UPDATE)'"
grep -q 'caveman modu' "$d/AGENTS.md" && ok "J: regen caveman satırını getirdi" || bad "J: regen'de caveman satırı yok"
grep -q 'vibe-setup:v8' "$d/AGENTS.md" && ok "J: regen stamp v8" || bad "J: regen stamp v8 değil"

d="$(fresh J2)"
printf '\n<!-- KULLANICI OZEL SATIR -->\n' >> "$d/AGENTS.md"
out="$(bash "$SCAFFOLD" upgrade "$d" 2>/dev/null)"
printf '%s\n' "$(field "$out" CONFLICT)" | grep -q 'AGENTS.md' && ok "J: elle düzenlenmiş AGENTS.md → CONFLICT" || bad "J: CONFLICT beklenirken: '$(field "$out" CONFLICT)'"
grep -q 'KULLANICI OZEL SATIR' "$d/AGENTS.md" && ok "J: kullanıcı edit'i korundu" || bad "J: kullanıcı edit'i ezildi!"
```

- [ ] **Step 4: profile_test.sh — VIBE_VERSION alanı assertion'ı ekle**

`tests/profile_test.sh` sonuna (özet `echo` satırından önce):

```bash
# VIBE_VERSION: profile çıktısı şema sürümünü basar (11. satır)
[ "$(field_of "$tmp/go" VIBE_VERSION)" = "8" ] && { echo "  ok: profile VIBE_VERSION=8"; pass=$((pass+1)); } || { echo "  FAIL: profile VIBE_VERSION — beklenen 8, gelen '$(field_of "$tmp/go" VIBE_VERSION)'"; fail=$((fail+1)); }
```

- [ ] **Step 5: Testleri çalıştır — KIRMIZI olmalı**

Run: `bash tests/run.sh`
Expected: `TESTS FAILED`. Kırılanlar: `init_test` (caveman satırı yok, v8 yok), `upgrade_test` (vibeVersion 7), `profile_test` (VIBE_VERSION 7). Bu beklenen — motor henüz değişmedi.

- [ ] **Step 6: scaffold.sh — VIBE_VERSION bump**

`skills/vibe-setup/scaffold.sh:21`:

```bash
VIBE_VERSION=8
```

- [ ] **Step 7: scaffold.sh — artifact_changed_in güncelle**

`skills/vibe-setup/scaffold.sh:111` satırını değiştir:

```bash
  AGENTS.md)            echo 8 ;;   # v8: caveman aktivasyon satırı (v4: Gemini AGENTS.md okumaz iddiası düzeltilmişti)
```

- [ ] **Step 8: scaffold.sh — AGENTS.md template'ine caveman satırı ekle**

`render_artifact` içindeki `AGENTS.md)` bloğunu (`skills/vibe-setup/scaffold.sh:274-286`) şununla değiştir:

```bash
    AGENTS.md) emit "$1" <<'EOF'
<!-- vibe-setup:v@VER@ (managed) -->
# Agent Guide

Bu projenin tek doğruluk kaynağı **CLAUDE.md**'dir.

- **AGENTS.md standardını izleyen ajanlar** (Codex, Kimi Code, vb.) bu dosyayı doğrudan okur →
  [CLAUDE.md](CLAUDE.md)'ye bakın.
- **Kendi context dosyası olan araçlar** ayrı pointer kullanır: Cursor → `.cursor/rules/`,
  Gemini CLI → `GEMINI.md` (ikisi de CLAUDE.md'ye yönlendirir/import eder).
- **Çıktı modu:** bu repoda caveman modu (seviye `full`) zorunludur — aktif değilse `/caveman full`
  çalıştır. Kod, commit mesajı ve PR metni normal yazılır.

Ek doküman: [docs/](docs/).
EOF
```

- [ ] **Step 9: Testleri çalıştır — YEŞİL olmalı**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 10: Bu repoyu kendi yeni sürümüne taşı (dogfood)**

Run: `bash skills/vibe-setup/scaffold.sh upgrade .`
Expected: `AGENTS.md` UPDATE ya da CONFLICT olarak listelenir.
- **UPDATE** ise: dosya otomatik yenilendi, `git diff AGENTS.md` ile caveman satırının geldiğini doğrula.
- **CONFLICT** ise: `AGENTS.md`'yi elle merge et — mevcut repo-özel içeriği koru, caveman satırını + `vibe-setup:v8` stamp'ini ekle. **Körlemesine ezme.**

- [ ] **Step 11: Commit**

```bash
git add skills/vibe-setup/scaffold.sh tests/init_test.sh tests/upgrade_test.sh tests/profile_test.sh AGENTS.md .vibe-setup.json
git commit -m "VIB-18 AGENTS.md template'ine caveman aktivasyon satiri ekle (VIBE_VERSION v8)"
```

---

### Task 2: SKILL.md — Faz 3 caveman kurulum bloğu

**Files:**
- Modify: `skills/vibe-setup/SKILL.md` — Faz 3 (`### 3. Agnostik iskeletler`), context-mode bloğunun (`:85-115`) hemen ardı, `- Script var olanı **ezmez**` satırından (`:116`) önce.

**Interfaces:**
- Consumes: Task 1'in ürettiği AGENTS.md satırı (bu blok AGENTS.md'ye ayrıca yazmaz — template zaten içeriyor).
- Produces: Faz 6'nın (Task 3) atıfta bulunduğu "install.sh reddedildi / agent tespit edilemedi" durumu.

- [ ] **Step 1: Faz 3'e caveman bloğunu ekle**

`- Script var olanı **ezmez** (SKIP). Çıktıdaki NEW/SKIP/EDIT'i kullanıcıya aktar.` satırının **hemen üstüne** ekle:

```markdown
- **caveman kurulumu (HER ZAMAN, sorulmadan — zorunlu bağımlılık, opsiyonel değil):**
  caveman çıktı-sıkıştırma modudur (~%75 output token tasarrufu, teknik doğruluk korunur).
  1. **Önce dry-run**, çıktıyı kullanıcıya göster (hangi agent'lar tespit edildi, hangi dosyalar yazılacak):
     ```bash
     curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash -s -- --dry-run --with-init
     ```
  2. Onay sonrası aynı komutu `--dry-run` **olmadan** çalıştır. Installer makinedeki tüm agent'ları
     auto-detect eder (Claude Code, Cursor, Codex, Gemini CLI, opencode, Windsurf, Copilot … 34 tane),
     her biri için o agent'ın native kurulum yolunu işletir. Tekrar çalıştırmak güvenli (idempotent).
  3. **Repo dışına yazılan yolları açıkça raporla** — `~/.claude`, `~/.config/opencode`, `~/.gemini`,
     `~/.openclaw/workspace`. Bu, Antigravity `mcp_config.json` kuralının aynısı: kullanıcının home
     dizini vibe-setup'ın normal kapsamı değil, **sessizce yapma**.
  4. `--with-init`'in **repoya** düşürdüklerini NEW olarak listele: `.cursor/rules/caveman.mdc`,
     `.windsurf/rules/caveman.md`, `.clinerules/caveman.md`, `.github/copilot-instructions.md`,
     `.opencode/AGENTS.md`. (`AGENTS.md`'deki caveman satırı bunlardan bağımsız — o `init`'in
     managed template'inden gelir, v8+.)
  5. Kullanıcı pipe-to-shell'i reddederse indir-oku-çalıştır alternatifini sun:
     ```bash
     curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh -o install.sh
     # incele, sonra:
     bash install.sh --with-init
     ```
  6. Kurulum başarısız olursa ya da kullanıcı tümüyle reddederse **Faz 3 durmaz** — uyarı bas, Faz 6
     kullanıcı-aksiyon tablosuna satır ekle.
```

- [ ] **Step 2: Doğrula — SKILL.md okunabilir, markdown bozulmadı**

Run: `grep -n "caveman" skills/vibe-setup/SKILL.md`
Expected: Faz 3 bloğunun satırları listelenir; kod fence'leri dengeli (```bash açılışları kapanışlarıyla eşit).

Run: `expr $(grep -c '^ *```' skills/vibe-setup/SKILL.md) % 2`
Expected: `0` (çift sayıda fence → dengeli). Dosyadaki fence'lerin çoğu liste içinde **girintili**,
bu yüzden `^```` değil `^ *```` aranır. Değişiklikten önceki taban değer 14; Task 2 sonrası 18 olmalı.

- [ ] **Step 3: Testler hâlâ yeşil**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED` (SKILL.md testlerde referans edilmiyor; regresyon kontrolü).

- [ ] **Step 4: Commit**

```bash
git add skills/vibe-setup/SKILL.md
git commit -m "VIB-18 SKILL.md Faz 3: caveman kurulumunu zorunlu adim olarak ekle"
```

---

### Task 3: SKILL.md — Faz 4 zorlama kuralı, Faz 6 fallback, Remove kaldırma yolu

**Files:**
- Modify: `skills/vibe-setup/SKILL.md` — Faz 4 (`:120-125` CLAUDE.md maddesi), Faz 6 kullanıcı-aksiyon tablosu (`:172-202`), Remove Kapanış (`:284-288`)

**Interfaces:**
- Consumes: Task 1'in AGENTS.md satırı (birebir aynı ifade kullanılır), Task 2'nin Faz 3 bloğu (reddedilme durumuna atıf).
- Produces: yok (terminal task).

- [ ] **Step 1: Faz 4 — CLAUDE.md kuralı + birleşik subagent gotcha'sı**

`### 4. Stack-bağımlı içerik` altındaki **CLAUDE.md** maddesinin sonundaki mevcut gotcha cümlesini
(`Gotchas'a şunu da ekle: **subagent/alt-görev başlatan bir akış varsa…` ile başlayan, `sağlayan tribal
bilgi).` ile biten paragraf) şununla **değiştir**:

```markdown
  Ayrıca CLAUDE.md'ye **çıktı modu kuralı** yaz: bu repoda caveman modu (seviye `full`) zorunludur —
  aktif değilse `/caveman full` çalıştır; kod, commit mesajı ve PR metni normal yazılır. Bu kural
  hook'suz agent'lar için (Codex, Warp, Kilo Code, Roo Code, goose, Devin…) zorlamanın **tek**
  dayanağıdır — onlarda kurulum otomatik aktive olmaz.
  Gotchas'a şunu da ekle: **subagent/alt-görev başlatan bir akış varsa, o subagent'lara hem context-mode
  hem caveman kullanım talimatı açıkça verilmeli** — subagent taze context alır, parent'ın context-mode
  ve caveman kurallarını miras almaz (Faz 3 ikisini de zorunlu kurdu; bu, o kurulumun subagent'lara da
  işlemesini sağlayan tribal bilgi).
```

- [ ] **Step 2: Faz 6 — kullanıcı-aksiyon tablosuna caveman satırı**

Tablodaki `| Codex CLI / Gemini CLI (Antigravity dışı) / Kimi Code | context-mode MCP kaydı (opsiyonel — zorunlu değil) |`
satırının **hemen altına** ekle:

```markdown
  | caveman (kurulum reddedildi / agent tespit edilemedi) | tek-agent kurulum komutu — snippet aşağıda |
```

Ve tablonun altındaki snippet bölümüne (Kimi Code `mcpServers` snippet'inin ardına) ekle:

```markdown
  - **caveman tek-agent kurulumu** (auto-detect kaçırdıysa ya da kurulum reddedildiyse):
    ```bash
    npx skills add JuliusBrussee/caveman -a <agent-id>   # cursor | codex | windsurf | cline | kilo | roo | warp | goose | …
    ```
    Rule dosyası düşmeyen agent'larda caveman **session başına** `/caveman full` ile açılır.
```

- [ ] **Step 3: Remove akışı — Kapanışa caveman satırı**

`### 5. Kapanış` altındaki mevcut iki maddenin **ardına** ekle:

```markdown
- **caveman kapsam dışı** — `vibe-remove` onu kaldırmaz (context-mode gibi). Kullanıcı isterse:
  ```bash
  npx -y github:JuliusBrussee/caveman -- --uninstall   # hook'lar, plugin, extension, opencode plugin
  npx skills remove caveman                            # `npx skills add` ile kurulanlar (ayrı CLI)
  ```
  Bu iki komut da `--with-init`'in düşürdüğü repo-içi rule dosyalarını **silmez**
  (`.cursor/rules/`, `.windsurf/rules/`, `.clinerules/`, `.github/copilot-instructions.md`,
  `.opencode/AGENTS.md`) — elle silinir. `AGENTS.md`'deki caveman satırı ise vibe-setup'ın managed
  template'inin parçası; `remove` onu zaten kendi kuralına göre ele alır.
```

- [ ] **Step 4: Fence dengesi + testler**

Run: `expr $(grep -c '^ *```' skills/vibe-setup/SKILL.md) % 2`
Expected: `0` (Task 2 sonrası taban 18; Task 3 iki fence çifti daha ekler → 22).

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add skills/vibe-setup/SKILL.md
git commit -m "VIB-18 SKILL.md: caveman zorlama kurali, kullanici-aksiyon fallback'i ve kaldirma yolu"
```

---

### Task 4: Repo dogfood — CLAUDE.md gotcha + ADR

**Files:**
- Modify: `CLAUDE.md` (bu repo) — Gotchas bölümü, `**context-mode zorunlu bağımlılık**` maddesinin ardı
- Create: `docs/architecture/decisions/0001-caveman-zorunlu-bagimlilik.md`

**Interfaces:**
- Consumes: Task 1-3'ün tümü.
- Produces: yok (terminal task).

- [ ] **Step 1: CLAUDE.md Gotchas — caveman maddesi**

`- **context-mode zorunlu bağımlılık** (v9+):` ile başlayan maddenin **hemen ardına** ekle:

```markdown
- **caveman zorunlu bağımlılık** (v8+): SKILL.md Faz 3 her çalıştırmada sorulmadan kurar
  (`install.sh --with-init` → tüm agent'lar auto-detect + repo-içi rule dosyaları). Seviye `full`.
  `AGENTS.md` template'inde aktivasyon satırı var (v8 — bu yüzden `VIBE_VERSION` 7→8 bump'landı);
  hook'suz agent'larda zorlamanın tek dayanağı CLAUDE.md/AGENTS.md prose'u. caveman `managed_paths`'e
  GİRMEZ, `vibe-remove` onu kaldırmaz. Subagent dispatch eden akışlarda context-mode gibi caveman
  talimatı da her prompt'a açıkça eklenmeli.
```

- [ ] **Step 2: ADR yaz**

`docs/architecture/decisions/0001-caveman-zorunlu-bagimlilik.md` oluştur:

```markdown
# 1. caveman zorunlu bağımlılık

- Status: accepted
- Date: 2026-08-02

## Context

vibe-setup kurduğu repolarda agent çıktısının token maliyeti kalıcı bir gider. caveman
(github.com/JuliusBrussee/caveman) çıktıyı ~%75 sıkıştırır, teknik doğruluğu (kod, komut, hata
string'i, terimler) aynen korur. Tek seferlik kurulumla kalıcı kazanç sağlar; context-mode'un
(girdi/context tarafı) tamamlayıcısıdır.

Alternatif: opsiyonel bırakıp kullanıcı-aksiyon tablosunda önermek. Pratikte opsiyonel satırlar
uygulanmıyor — context-mode'da da aynı sebeple zorunluya geçildi.

## Decision

caveman zorunlu bağımlılık. SKILL.md Faz 3 her kurulumda `install.sh --with-init` çalıştırır
(dry-run önce gösterilir, repo dışına yazılan yollar açıkça raporlanır). Varsayılan seviye `full`.
Hook'suz agent'lar için zorlama `AGENTS.md` (managed template, v8) + CLAUDE.md prose'u ile sağlanır.

caveman `managed_paths`'e girmez, `vibe-remove` kapsamına alınmaz — context-mode ile aynı sınıf.

## Consequences

**Artı:** çıktı token maliyeti kalıcı düşer; 34 agent tek komutta kapsanır; rule-file destekleyen
agent'larda gerçekten always-on.

**Eksi:** paylaşılan repoda çıktı stili tüm ekibe dayatılır — bilinçli takas. Kullanıcı kendi
session'ında `/caveman lite` veya "stop caveman" ile geçebilir. Ayrıca üçüncü-parti bir GitHub
projesine bağımlılık doğar; kurulum başarısız olursa Faz 3 durmaz, uyarı basıp devam eder.

**Sürüm etkisi:** `AGENTS.md` template'i değiştiği için `VIBE_VERSION` 7→8. Kurulu repolar
`scaffold.sh upgrade` ile satırı alır (dokunulmamışsa UPDATE, elle düzenlenmişse CONFLICT → LLM merge).
```

- [ ] **Step 3: Doğrula**

Run: `bash tests/run.sh`
Expected: `ALL TESTS PASSED`

Run: `bash skills/vibe-setup/scaffold.sh audit .`
Expected: skor düşmedi; `AGENTS.md` satırı `OK`.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/architecture/decisions/0001-caveman-zorunlu-bagimlilik.md
git commit -m "VIB-18 dogfood: CLAUDE.md caveman gotcha'si + ADR-0001"
```

---

## Kapsam dışı (bu planda yapılmaz)

- `plugin.json` / `marketplace.json` / `.cursor-plugin/plugin.json` semver bump'ı — ayrı release kararı (`RELEASE.md`).
- `install.sh`'ın kendi davranışını değiştirmek (upstream proje).
- caveman'i `managed_paths` / `artifact_class` / `audit` satırına eklemek.
- `vibe-remove`'a caveman temizliği eklemek.
- CLAUDE.md'deki "context-mode zorunlu bağımlılık **(v9+)**" ibaresinin yanlışlığı — ayrı iş, ayrı commit.
