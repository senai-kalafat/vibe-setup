# CLAUDE.md — vibe-setup

Repoyu AI/agent geliştirmeye hazırlayan Claude Code plugin'i. Audit + scaffold; stack-agnostik.

## Komutlar (repo kökünden)
- Test: `bash tests/run.sh` (bağımsız, dış dep yok)
- Audit (dogfood): `bash skills/vibe-setup/scaffold.sh audit .`
- Upgrade (dogfood): `bash skills/vibe-setup/scaffold.sh upgrade .` — sürümlü drift; UPDATE/ADD/CONFLICT raporu
- Profil: `bash skills/vibe-setup/scaffold.sh profile .`
- Lint (ops): `shellcheck skills/vibe-setup/scaffold.sh` — kurulu değilse atla
- Format (ops): `shfmt -d skills/vibe-setup/scaffold.sh` — kurulu değilse atla

## Mimari
İş ikiye ayrılır (bkz [SKILL.md](skills/vibe-setup/SKILL.md)):
- **Deterministik** — [scaffold.sh](skills/vibe-setup/scaffold.sh): stack tespit, agnostik iskelet, komut
  substitüsyonu, **sürümlü upgrade** (sha-drift tespiti). Saf bash; tek opsiyonel dep `jq` (yoksa audit izin satırlarını atlar).
- **Akıllı (LLM)** — SKILL.md akışı: repoyu okuyup CLAUDE.md prose, gerçek test, deny yollarını üretir; **upgrade'de CONFLICT'leri merge eder**.
- **Sürümleme** — `VIBE_VERSION` (scaffold.sh). init, managed dosyalara `vibe-setup:vN` stamp + repo köküne
  `.vibe-setup.json` manifest (v+sha) yazar. `upgrade` dokunulmamışları yeni template'e taşır, elle
  düzenlenmişleri CONFLICT'e bırakır (asla ezmez). Akış: [SKILL.md](skills/vibe-setup/SKILL.md) `## Upgrade akışı`.

Dosyalar:
- `skills/vibe-setup/SKILL.md` — orkestrasyon akışı (init + upgrade + remove)
- `skills/vibe-setup/scaffold.sh` — motor (`audit|init|init-cursor|init-gemini|upgrade|remove|profile`)
- `skills/vibe-setup/stack-profiles.md` — stack komut tablosu (insan-okur ayna)
- `skills/vibe-setup/{vibe-checklist-template,legacy-runbook}.md`
- `.claude-plugin/{plugin,marketplace}.json` — plugin manifest

Detay: [docs/](docs/).

## Gotchas (koddan çıkmaz, tribal)
- **scaffold.sh kanonik, stack-profiles.md ayna.** Profil eklerken İKİSİNİ de güncelle — yoksa drift
  (geçmişte `.csproj`/`.sln` drift etmişti).
- **`detect_profile` printf = 9 alan**, sonuncu `FMT_FILE_OK` (`1`=staged-scope fmt, `0`=repo-advisory).
  Alan eklersen `IFS read` satırını + `profile` çıktısını da güncelle. (`profile` komutu ayrıca `VIBE_VERSION`
  basar → 10 satır; ama `detect_profile` hâlâ 9 tab-alan.)
- **`init` asla ezmez** (SKIP). Idempotent — tekrar çalıştırmak güvenli. (Tek istisna `.vibe-setup.json`:
  her init/upgrade'de yeniden yazılır — lockfile gibi meta.)
- **Sürüm yükseltirken 3 yer:** bir managed template değişince (a) `VIBE_VERSION`++ (b) `artifact_changed_in`'de
  o dosyanın sürümü (c) template'in kendisi (`render_artifact`/`render_precommit`). Dosya-dışı dönüşüm
  gerekiyorsa `run_migrations`'a probe-guarded adım (UPDATE yolu dosya-template'leri zaten taşır).
- **`render_artifact` tek-kaynak**: managed içerik orada; init + upgrade ikisi de oradan üretir →
  sha tutarlı. `artifact_class`: **synced** (engine sürdürür: AGENTS/ADR/pre-commit/commit-msg) vs **seed**
  (bir kez düşer, drift normal: settings.json/gitmessage/docs-README/PR). Yeni managed dosya = `managed_paths`
  + `render_artifact` + `artifact_class` + `artifact_changed_in` (DÖRT yer).
- **`.vibe-setup.json` jq-suz** grep/awk ile parse (kontrollü flat şekil — tek-satır-per-entry). `write_manifest`
  body'yi ÖNCE kurar SONRA yazar: `> file` redirect'i trunc'lar; eski değerler önce okunmalı. `write_manifest`
  `init`/`upgrade`/`init-cursor`/`init-gemini` DÖRDÜNDEN de çağrılır — bu yüzden sha/v/vibeVersion varsayılanı
  **koru**dur: sadece `WRITTEN_PATHS`'te olan (bu çalıştırmada gerçekten yazılan) yollar tazelenir, gerisi
  manifestteki önceki değeri korur (yoksa örn. `init-gemini` arada elle düzenlenmiş bir dosyayı "blessed" eder →
  `remove` onu güvenle silinebilir sanır, ya da sonraki `upgrade` CONFLICT'i ezer).
- **Üretilen dosyalar Türkçe.** İng. ekip için şablonları çevir.
- **fmt-scope:** go/node/python/ruby/php/shell → sadece staged (eski dirt temiz commit'i bloklamaz);
  java/rust/dotnet → repo-geneli, advisory; asıl enforcement CI.
- **Hook tool yoksa atlar** (`command -v`). Bu repoda shellcheck/shfmt kurulu olmayabilir → fmt/lint
  sessizce atlanır, test yine çalışır.
- **Araç desteği:** Codex ve Kimi Code `AGENTS.md`'yi native okur (`init` zaten düşürür, ekstra dosya
  yok). Cursor (`init-cursor`) ve Gemini CLI (`init-gemini` → `GEMINI.md`, `@CLAUDE.md` importu) ayrı
  context dosyası ister — bunlar `managed_paths`'e GİRMEZ (Cursor ile aynı sınıf: bir kez düşer,
  drift/upgrade takibi yok, audit satırı yok). AGENTS.md'nin metni v4'te değişti (Gemini'nin AGENTS.md
  okuduğu yanlış iddiası düzeltildi) → bkz `VIBE_VERSION`.
- **context-mode zorunlu bağımlılık** (v9+): SKILL.md Faz 3 her çalıştırmada sorulmadan kurar
  (`npm install -g context-mode` + Claude/Cursor repo-tracked JSON-merge + Antigravity global config).
  Subagent dispatch eden bir akış varsa (bu repoda: subagent-driven-development), her dispatch
  prompt'una context-mode kullanım talimatı **açıkça** eklenmeli — subagent taze context alır, parent
  session'ın context-mode kurallarını miras almaz.

## Git workflow
- Branch: `chore/...`, `feat/...`, `fix/...`. Commit: `ABC-1234 emir kipi özet` (3 harf + '-' + ≤4 hane).
  `.githooks/commit-msg` deseni `vibe.ticketre` local config'den okur — **bu repoda set** (zorlar);
  ayarsız repoda bloklamaz (v3 davranışı). Merge/revert muaf, bypass `--no-verify`; bkz `.gitmessage`.
- Hook aktif: `git config core.hooksPath .githooks && git config commit.template .gitmessage
  && git config vibe.ticketre '^[A-Z]{3}-[0-9]{1,4} '`
- PR şablonu: `.github/pull_request_template.md`
