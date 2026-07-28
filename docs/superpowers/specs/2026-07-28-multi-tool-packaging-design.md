# vibe-setup: çok-araçlı kurulabilir + versiyonlu paketleme — design

Date: 2026-07-28
Status: approved

## Problem

vibe-setup bugün sadece bir Claude Code plugin'i (`.claude-plugin/plugin.json` + `marketplace.json`).
Cursor kendi plugin/discovery mekanizmasını okuyamıyor; Codex/Gemini CLI zaten repo kökündeki
`AGENTS.md`/`GEMINI.md` üzerinden bu repoyu native okuyabiliyor ama bu hiç doğrulanıp
dokümante edilmemiş. Ayrıca paket versiyonu (`plugin.json`/`marketplace.json`'daki `"version"`)
elle senkron tutuluyor — üçüncü bir manifest eklenince (Cursor) bu elle-senkron kırılganlığı büyür.

## Referans model

`context-mode` paketi (`~/.claude/plugins/marketplaces/context-mode/`) aynı sorunu çözmüş: tek
kanonik içerik (server/skill), yanında ince araç-özel manifestler (`.claude-plugin/`,
`.cursor-plugin/plugin.json`, `.codex-plugin/plugin.json`), hepsi aynı içeriğe işaret eder. Versiyon
tek kaynaktan (kendi `package.json`'ı) `scripts/version-sync.mjs` ile diğerlerine yayılır.

## Kapsam kararları

1. **Cursor — yeni `.cursor-plugin/plugin.json`.** context-mode'un formatını izler:
   `name/version/description/author/homepage/repository/keywords` + `"rules": "./.cursor-plugin/vibe-setup.mdc"`
   + `"skills": "./skills/"`. MCP/hooks alanı YOK — vibe-setup bir MCP server değil, pasif bir skill.
2. **Yeni `.cursor-plugin/vibe-setup.mdc`** — Cursor'ın agent'ına: kullanıcı vibe-setup/audit/agent-readiness
   istediğinde `skills/vibe-setup/SKILL.md`'yi oku ve izle, der. vibe-setup'ın kendi ürettiği OUTPUT-side
   `.cursor/rules/project.mdc` ile aynı desen (bkz `scaffold.sh`'taki `init_cursor()`), farklı hedef dosya
   (SKILL.md, hedef reponun CLAUDE.md'si değil — çünkü burada tanımlanan bu repo'nun KENDİ yeteneği).
3. **Codex/Gemini CLI — yeni manifest YOK.** Zaten repo kökündeki `AGENTS.md` → `CLAUDE.md` üzerinden bu
   repoyu native okuyorlar; `CLAUDE.md`'nin "Komutlar" bölümü zaten `scaffold.sh audit/init/upgrade` gibi
   komutları listeliyor. Ekstra paketleme gereksiz kapsam genişlemesi olurdu.
4. **`scripts/version-sync.sh` — yeni, saf bash.** Node.js YOK (proje hiç `package.json` içermiyor, "saf
   bash" ilkesiyle tutarlı kalınır — bkz mevcut `CLAUDE.md` gotcha'ları). `sed -i` YOK (BSD/GNU
   portability farkı) — mevcut kod tabanının `awk gsub + tmp-dosya + mv` deseni kullanılır (bkz
   `tests/upgrade_test.sh`'taki `set_msha` fonksiyonu, aynı desen).
   - **Tek kaynak:** `.claude-plugin/plugin.json`'daki `"version"` alanı.
   - **Yayılan hedefler:** `.claude-plugin/marketplace.json` (İKİ occurrence: `metadata.version` +
     `plugins[0].version` — awk gsub dosyanın HER satırını işlediği için ikisi de otomatik güncellenir,
     özel kod gerekmez) ve yeni `.cursor-plugin/plugin.json`.
   - **Manuel çalıştırılır** (release anında maintainer tarafından) — git hook'a bağlanmaz, CI
     zorlamaz. Bu bilinçli bir kapsam sınırı: otomatik zorlama ayrı, daha büyük bir karar.
5. **`CLAUDE.md` güncellemesi:**
   - "Komutlar" bölümüne yeni satır: `Versiyon senkron: bash scripts/version-sync.sh`.
   - Yeni Gotcha: **paket versiyonu** (`plugin.json`/`marketplace.json`/`cursor-plugin.json`'daki
     `"version"`) ile scaffold.sh'ın kendi `VIBE_VERSION`'ı (OUTPUT-drift takip şeması) TAMAMEN AYRI
     kavramlar — biri "bu plugin'in sürümü", diğeri "scaffold.sh'ın ürettiği dosya şemasının sürümü".
     Karıştırılmamalı.

## Kapsam dışı (bilinçli)

- Cursor/başka bir marketplace'e resmi submission — bu iş sadece repo yapısını kurulabilir/keşfedilebilir
  hale getiriyor, dağıtım kanalına başvuru ayrı bir adım.
- Versiyon senkronunu git hook/CI'a bağlamak — manuel kalır, otomatikleştirme ayrı karar.
- README'ye Cursor kurulum talimatı eklemek — küçük, isteğe bağlı, bu planın çekirdeği değil (istenirse
  ayrı, ufak bir takip işi).
- Codex/Gemini için herhangi bir yeni dosya/manifest — zaten çalışıyorlar, kapsam dışı.
