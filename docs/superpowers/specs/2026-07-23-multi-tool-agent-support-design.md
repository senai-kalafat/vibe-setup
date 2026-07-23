# vibe-setup: Codex / Gemini / Kimi desteği — design

Date: 2026-07-23
Status: approved

## Problem

vibe-setup bugün yalnızca Claude Code (CLAUDE.md, .claude/settings.json) ve Cursor
(`init-cursor`) için gerçek bir pointer/artifact üretiyor. AGENTS.md metni "Cursor / Codex /
Gemini / Copilot dahil tüm agent'lar oradan başlasın" diyor ama bu iddia Gemini için yanlış:
Gemini CLI AGENTS.md okumaz, kendi `GEMINI.md` dosyasını okur.

## Araştırma bulguları (kaynak: resmi dokümanlar, 2026-07)

- **Codex CLI** (OpenAI): repo kökünde `AGENTS.md`'i native okur. — zaten kapsanıyor, yeni dosya gerekmez.
  https://developers.openai.com/codex/guides/agents-md
- **Kimi Code CLI** (Moonshot): repo kökünde `AGENTS.md`'i native okur (`/init` de bu dosyayı üretir). —
  zaten kapsanıyor, yeni dosya gerekmez.
  https://moonshotai.github.io/kimi-code/en/customization/agents
- **Gemini CLI** (Google): AGENTS.md okumaz; kendi `GEMINI.md` dosyasını (hiyerarşik, proje
  kökünden yukarı doğru) okur. `@file.md` import sözdizimini destekler — başka bir dosyanın
  içeriğini doğrudan çeker.
  https://google-gemini.github.io/gemini-cli/docs/cli/gemini-md.html

## Kapsam

- **Codex, Kimi Code**: kod değişikliği yok. Sadece AGENTS.md'nin metni düzeltiliyor (yanlış
  Gemini iddiasını kaldır, Codex/Kimi Code'u isimlendir).
- **Gemini CLI**: yeni `init-gemini` subcommand'ı → `GEMINI.md` üretir, içeriği `@CLAUDE.md`
  (gerçek içerik importu, salt pointer değil).
- **Copilot**: kapsam dışı (kullanıcı onayladı) — SKILL.md'deki mevcut referansa dokunulmuyor.

## Değişiklikler

### 1. `skills/vibe-setup/scaffold.sh`

- `write_managed_cursor` → `write_extra` olarak yeniden adlandırılır (artık Cursor'a özel değil,
  iki araç tarafından paylaşılan "asla ezme" yazıcısı).
- Yeni `init_gemini()`:
  ```
  # Gemini CLI context — tek doğruluk kaynağı CLAUDE.md
  @CLAUDE.md
  ```
  → `GEMINI.md`'ye yazılır (repo kökü).
- Yeni case: `init-gemini) init_gemini ;;` + kullanım mesajı satırı güncellenir.
- `GEMINI.md`, Cursor dosyaları gibi `managed_paths()`'e **girmez** — versiyon/manifest/upgrade
  takibi yok, audit satırı yok. Bir kez düşer, kullanıcı sahibi olur (Cursor ile aynı davranış
  sınıfı).
- `VIBE_VERSION`: 3 → 4 (AGENTS.md şablon metni değişiyor — mevcut managed/synced artifact'in
  İÇERİĞİ değişiyor, bu zaten var olan UPDATE/CONFLICT drift mekanizmasını tetikler; yeni kod
  gerekmez).
- `artifact_changed_in`: `AGENTS.md) echo 4 ;;` case'i eklenir, yorum: "v4: Codex/Kimi Code
  AGENTS.md okur diye netleştirildi, Gemini'nin ayrı GEMINI.md kullandığı belirtildi".
- `render_artifact` → AGENTS.md şablonu:
  ```
  <!-- vibe-setup:v@VER@ (managed) -->
  # Agent Guide

  Bu projenin tek doğruluk kaynağı **CLAUDE.md**'dir.

  - **AGENTS.md standardını izleyen ajanlar** (Codex, Kimi Code, vb.) bu dosyayı doğrudan okur →
    [CLAUDE.md](CLAUDE.md)'ye bakın.
  - **Kendi context dosyası olan araçlar** ayrı pointer kullanır: Cursor → `.cursor/rules/`,
    Gemini CLI → `GEMINI.md` (ikisi de CLAUDE.md'ye yönlendirir/import eder).

  Ek doküman: [docs/](docs/).
  ```

### 2. `skills/vibe-setup/SKILL.md`

- Faz 2 "Hedef araç sorusu" satırı güncellenir: AGENTS.md'nin Codex/Kimi Code'u zaten kapsadığı,
  ekstra dosya gerekmediği belirtilir; kullanıcıya Cursor ve/veya Gemini CLI pointer'ı sorulur.
- Faz 3: kullanıcı Gemini dediyse `init-gemini` çalıştırılır (mevcut `init-cursor` çağrısının
  yanına).

### 3. `CLAUDE.md` (bu repo, dogfood)

- Gotchas'a kısa not: hangi araç neyi native okur (Codex/Kimi Code → AGENTS.md, Cursor/Gemini →
  ayrı pointer), VIBE_VERSION 4'ün sebebi.

### 4. Testler

- Yeni `tests/init_gemini_test.sh` (`init_cursor_test.sh` paterni): ilk çalıştırma NEW basar,
  `GEMINI.md` içeriğinde `@CLAUDE.md` var, ikinci çalıştırma SKIP basar + kullanıcı edit'i korunur.
- `tests/upgrade_test.sh`: `"vibeVersion": 3` referansları → `4` (iki yer: A ve H testleri);
  A testine `"AGENTS.md": { "v": 4` assertion'ı eklenir.

## Kapsam dışı / bilinçli sınırlamalar

- Copilot desteği (kullanıcı onayı ile kapsam dışı).
- `GEMINI.md` için upgrade/CONFLICT takibi yok — Cursor ile birebir aynı, kabul edilen mevcut
  mimari sınır (extras = seed-once, drift normal).
- Gemini'nin `@file.md` importunun her Gemini CLI sürümünde çalıştığı doğrulanmadı (dokümante
  edilen davranış; runtime doğrulaması yok) — düşük risk, düşerse en kötü ihtimalle statik pointer
  metni gibi davranır.
