# CLAUDE.md — vibe-setup

Repoyu AI/agent geliştirmeye hazırlayan Claude Code plugin'i. Audit + scaffold; stack-agnostik.

## Komutlar (repo kökünden)
- Test: `bash tests/run.sh` (bağımsız, dış dep yok)
- Audit (dogfood): `bash skills/vibe-setup/scaffold.sh audit .`
- Upgrade (dogfood): `bash skills/vibe-setup/scaffold.sh upgrade .` — sürümlü drift; UPDATE/ADD/CONFLICT raporu
- Profil: `bash skills/vibe-setup/scaffold.sh profile .`
- Versiyon senkron: `bash scripts/version-sync.sh` — `.claude-plugin/plugin.json`'daki `"version"`'ı
  `marketplace.json` + `.cursor-plugin/plugin.json`'a yayar (release'te elle çalıştır).
- Release çıkar: `bash scripts/release.sh <major|minor|patch>` — sürümü hesaplar + yayar (commit/tag
  atmaz); tam süreç: `RELEASE.md`.
- Self-update (tüketici tarafı): `bash scripts/vibe-update.sh` — kurulu kopyayı en son git tag'e
  günceller (branch-HEAD değil; commit geçmişi sapmışsa asla otomatik merge etmez).
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
- `skills/vibe-setup/scaffold.sh` — motor (`audit|init|init-cursor|init-gemini|init-aider|upgrade|remove|profile`)
- `skills/vibe-setup/stack-profiles.md` — stack komut tablosu (insan-okur ayna)
- `skills/vibe-setup/{vibe-checklist-template,legacy-runbook}.md`
- `.claude-plugin/{plugin,marketplace}.json` — plugin manifest

Detay: [docs/](docs/).

## Gotchas (koddan çıkmaz, tribal)
- **scaffold.sh kanonik, stack-profiles.md ayna.** Profil eklerken İKİSİNİ de güncelle — yoksa drift
  (geçmişte `.csproj`/`.sln` drift etmişti).
- **`detect_profile` printf = 10 alan**, son ikisi `FMT_FILE_OK` (`1`=staged-scope fmt blocking,
  `0`=repo-geneli advisory) ve `LINT_FILE_OK` (`1`=lint dosya listesi alır → staged kaynaklar geçilir,
  staged kaynak yoksa adım atlanır; `0`=argümansız repo-geneli). **Lint her iki modda da advisory.**
  Bugün sadece `shell` `LINT_FILE_OK=1` (shellcheck dosya ister); diğer tüm stack'ler `0`.
  Alan eklersen `IFS read` satırını + `profile` çıktısını da güncelle. (`profile` komutu ayrıca
  `VIBE_VERSION` basar → 11 satır; ama `detect_profile` hâlâ 10 tab-alan.)
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
- **Araç desteği:** AGENTS.md'yi native okuyan geniş bir ekosistem var — Codex, Kimi Code, Zed, Warp,
  VS Code, Devin, Amp, RooCode, Kilo Code, GitHub Copilot coding agent, Windsurf, Augment Code, goose,
  opencode, Junie, Phoenix, Semgrep, Ona, Factory, Jules — hiçbiri ekstra dosya istemez (`init` zaten
  yeterli). Cursor (`init-cursor`), Gemini CLI (`init-gemini` → `GEMINI.md`, `@CLAUDE.md` importu) ve
  Aider (`init-aider` → `.aider.conf.yml`, `read: AGENTS.md`) ayrı context dosyası ister — bunlar
  `managed_paths`'e GİRMEZ (aynı sınıf: bir kez düşer, drift/upgrade takibi yok, audit satırı yok; var
  olan `.cursorrules`/`GEMINI.md`/`.aider.conf.yml` varsa asla ezilmez). AGENTS.md'nin metni v4'te
  değişti (Gemini'nin AGENTS.md okuduğu yanlış iddiası düzeltildi) → bkz `VIBE_VERSION`.
- **Legacy tekil `AGENT.md`:** `init` çalışırken `AGENTS.md` yok + `AGENT.md` (tekil) varsa, template
  render ETMEZ — `mv AGENT.md AGENTS.md && ln -s AGENTS.md AGENT.md` yapar (resmi AGENTS.md migrasyon
  tavsiyesi). Bu vibe-setup'ın ÜRETTİĞİ içerik DEĞİL — manifestte `created:false` işaretlenir (aynı
  "önceden vardı" sınıfı), yani `remove` bunu ASLA silmeye kalkışmaz (`migrate_legacy_agent_md`
  `NEW_PATHS`'e eklemez, sadece `WRITTEN_PATHS`'e — sha tazelenir ama provenance "ben ürettim" demez).
  `audit` da bunu init'ten önce sinyal verir.
- **context-mode zorunlu bağımlılık** (v9+): SKILL.md Faz 3 her çalıştırmada sorulmadan kurar
  (`npm install -g context-mode` + Claude/Cursor repo-tracked JSON-merge + Antigravity global config).
  Subagent dispatch eden bir akış varsa (bu repoda: subagent-driven-development), her dispatch
  prompt'una context-mode kullanım talimatı **açıkça** eklenmeli — subagent taze context alır, parent
  session'ın context-mode kurallarını miras almaz.
- **caveman zorunlu bağımlılık** (v8+): SKILL.md Faz 3 her çalıştırmada sorulmadan kurar
  (`install.sh --with-init` → tüm agent'lar auto-detect + repo-içi rule dosyaları). Seviye `full`.
  `AGENTS.md` template'inde aktivasyon satırı var (v8 — bu yüzden `VIBE_VERSION` 7→8 bump'landı);
  hook'suz agent'larda (Codex, Warp, Kilo, Roo, goose…) zorlamanın tek dayanağı CLAUDE.md/AGENTS.md
  prose'u. caveman `managed_paths`'e GİRMEZ, `vibe-remove` onu kaldırmaz. Subagent dispatch eden
  akışlarda context-mode gibi caveman talimatı da her prompt'a açıkça eklenmeli.
- **Paket versiyonu ≠ `VIBE_VERSION`.** `.claude-plugin/plugin.json` / `marketplace.json` /
  `.cursor-plugin/plugin.json`'daki `"version"` bu PLUGIN'in kendi sürümü — `scripts/version-sync.sh`
  ile senkron tutulur, `plugin.json` tek kaynak. `scaffold.sh`'taki `VIBE_VERSION` TAMAMEN AYRI bir
  kavram: scaffold.sh'ın hedef repolara ÜRETTİĞİ dosya şemasının sürümü (upgrade'in drift tespiti
  için). Biri artınca diğeri otomatik artmaz — ikisini karıştırma. Release çıkarma + self-update tam
  süreci: `RELEASE.md`. `scripts/vibe-update.sh` de bu ayrımı miras alır — `scaffold.sh upgrade`
  (hedef repo, VIBE_VERSION) değil, git TAG bazlı (bu repo'nun kendi kopyası) çalışır.

## Git workflow
- Branch: `chore/...`, `feat/...`, `fix/...`. Commit: `ABC-1234 emir kipi özet` (3 harf + '-' + ≤4 hane).
  `.githooks/commit-msg` deseni `vibe.ticketre` local config'den okur — **bu repoda set** (zorlar);
  ayarsız repoda bloklamaz (v3 davranışı). Merge/revert muaf, bypass `--no-verify`; bkz `.gitmessage`.
- Hook aktif: `git config core.hooksPath .githooks && git config commit.template .gitmessage
  && git config vibe.ticketre '^[A-Z]{3}-[0-9]{1,4} '`
- PR şablonu: `.github/pull_request_template.md`
