---
name: vibe-setup
description: >
  Audit any repository for AI/agent ("vibe coding") readiness and set up the missing pieces —
  stack- and language-agnostic. Use when the user wants to check or bootstrap a project's
  agent-friendliness: CLAUDE.md, AGENTS.md, llms.txt, docs/ knowledge base + ADRs, a test harness,
  a real (human + AI) git pre-commit hook (fmt/lint/doc-sync), .claude/settings.json permissions,
  commit/PR templates, and the reusable vibe checklist. It NEVER modifies existing source, config, CI or
  test files — it only adds new files and appends to doc/meta files; any step that would require touching
  live code is skipped and reported instead. Setup also installs two mandatory tooling
  dependencies globally (context-mode and caveman) — this writes outside the repo (npm global,
  ~/.claude, ~/.config/opencode, ~/.gemini); both are listed and confirmed before anything runs.
  Also UPGRADES an already-set-up repo to a newer
  skill version: re-applies changed managed templates (e.g. hook fixes) without clobbering human edits.
  Also REMOVES what it created (dry-run by default, explicit confirmation before deleting): only
  vibe-setup-created files that are still unchanged, never pre-existing or hand-edited ones.
  Triggers: "vibe checklist", "vibe-setup", "audit this project for agent readiness", "make this repo
  agent/AI friendly", "set up CLAUDE.md and hooks", "vibe-setup güncelle / yeni sürüme geç", "upgrade
  vibe-setup", "boş projeyi vibe checklist'e göre kur", "vibe-setup'ı kaldır", "remove vibe-setup",
  "vibe-remove", "vibe-setup'ı geri al". Works for Go, Node/TS, Python, Java, Kotlin,
  Swift, Rust, Ruby, .NET, PHP, Elixir, and blank repos.
---

# vibe-setup

Bir repoyu AI/agent destekli geliştirmeye hazır hale getirir. İş ikiye ayrılır:
**deterministik** (script: tespit + agnostik iskelet) ve **akıllı** (sen: repoyu okuyup içerik üret).

Repo **zaten kuruluysa** (`.vibe-setup.json` ya da managed dosyalar var) ve yeni sürümdeysen: sıfırdan
init değil, **`## Upgrade akışı`**'nı izle (aşağıda) — engine değişen template'leri taşır, elle düzenlenmiş
dosyaları CONFLICT olarak sana getirir, sen merge edersin.

Kullanıcı **kaldırmak/geri almak** istiyorsa: init/upgrade değil, doğrudan **`## Remove akışı`**'nı izle
(aşağıda).

Bundled dosyalar bu skill dizinindedir: `scaffold.sh`, `stack-profiles.md`, `vibe-checklist-template.md`,
`legacy-runbook.md`. Aşağıda `SKILL_DIR` = bu SKILL.md'nin bulunduğu dizin.

> **Legacy repo** (kod var, agent altyapısı yok, test/doküman yok, README bayat) ile uğraşıyorsan —
> ve YALNIZCA o zaman — `SKILL_DIR/legacy-runbook.md`'yi oku; sıralama + legacy tuzakları orada.
> Yeni/boş projede okuma, gereksiz bağlam. Aşağıdaki akış zaten yeterli.

## Akış (sırayla)

### 1. Tespit + audit (ÖNCE skoru)
- `bash "$SKILL_DIR/scaffold.sh" profile .` → stack, MODULE_DIR ve komutları al.
- `bash "$SKILL_DIR/scaffold.sh" audit .` → ✅/❌/— tablosu + `SCORE=N/M` footer.
- **Sürüm kontrolü (her çalıştırmada):** audit çıktısında `UPDATE_AVAILABLE=vX->vY` satırı varsa
  kullanıcıya **SOR**: "Repo vibe-setup vX ile kurulmuş, yeni sürüm vY var — şimdi upgrade edeyim mi?"
  - **Evet** → `## Upgrade akışı`nı izle, sonra bu akışa dön.
  - **Hayır** → zorlamadan normal devam et (satır bir sonraki çalıştırmada yine çıkar).
  - Sormadan upgrade ÇALIŞTIRMA; satır yoksa (güncel/manifest yok) hiç bahsetme.
- **BEFORE skorunu sakla** (hem `SCORE=N/M` hem her satırın ✅/❌'i) — sonda karşılaştıracaksın.
- Stack `unknown` ise: kullanıcıya dili/komutları sor (fmt/lint/test/build); cevabı `stack-profiles.md`
  formatında not et. Boş repo ise: agnostik iskeleti kur, stack maddelerini "kod gelince" diye işaretle.

### 2. Rapor + onay (+ hedef araçlar)
- Audit tablosunu kullanıcıya göster. Eksikleri iki grupta özetle:
  **agnostik** (script düşürür) ve **stack-bağımlı** (sen dolduracaksın).
- **Kurulacaklar listesini de göster** (Faz 3'te ne düşeceği): agnostik iskeletler + **context-mode**
  (`npm install -g` + JSON-merge) + **caveman** (`install.sh --with-init`). caveman'in repo DIŞINA da
  yazdığını (`~/.claude`, `~/.config/opencode`, `~/.gemini`, `~/.openclaw/workspace`) burada açıkça yaz —
  onay bilinçli olsun.

- **Sonra TEK `AskUserQuestion` çağrısı — 4 soru birlikte.** Bunları ayrı ayrı SORMA; geliştiriciyi
  4 round-trip bekletmek bu skill'in en büyük sürtünmesiydi. Sorular:
  1. **Ayrı context dosyası?** (multiSelect: Cursor / Gemini CLI / Aider / Hiçbiri). Claude varsayılan
     ve AGENTS.md geniş bir ekosistemi zaten kapsar (Codex, Kimi Code, Zed, Warp, VS Code, Devin, Amp,
     RooCode, Kilo Code, GitHub Copilot coding agent, Windsurf, Augment Code, goose, opencode, Junie,
     Phoenix, Semgrep, Ona, Factory, Jules) — bunların hiçbiri ekstra dosya istemez. Seçilenler için
     Faz 3'te `init-cursor` / `init-gemini` / `init-aider` çalışır.
  2. **Commit'te ticket-key zorlansın mı?** (Hayır — varsayılan / `ABC-1234` / özel regex). Evet ise
     Faz 3 sonrasında `git config vibe.ticketre '^[A-Z]{3}-[0-9]{1,4} '` (ya da kullanıcının regex'i).
     Hayır ise hiçbir şey yapma — hook bloklamaz. **Formatı ayrı bir soru olarak sorma**, şıkların
     içine göm.
  3. **doc-sync blocking olsun mu?** (Evet — önerilen / Hayır). Kaynak değişip doküman değişmezse
     commit engellensin mi? Evet ise Faz 3 sonrasında `git config vibe.strictdocs true`. Hayır ise
     hook advisory kalır.
  4. **Kurulum onayı** (Hepsi / Sadece agnostik / Seçmeli). Bu, dosya üretiminin kapısı — onaysız
     üretme. Şık açıklamalarında **tehlikeli/dışa-dönük** olanları açıkça yaz (plugin enable, harici
     repo'dan `install.sh` çalıştırma, home dizinine yazma, izin genişletme); güvenlik sınıflandırıcısı
     bunları ayrıca bloklayabilir. "Seçmeli" derse — ve **yalnızca o zaman** — hangi maddeler diye tek
     ek soru sor.

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
- Kullanıcı **Aider** dediyse: `bash "$SKILL_DIR/scaffold.sh" init-aider .` → `.aider.conf.yml`
  (`read: AGENTS.md` — Aider AGENTS.md'yi native okumaz, açıkça işaretlenmesi gerekir).
- **SessionStart hook kaydı (HER ZAMAN, sorulmadan):** `init` `.claude/hooks/vibe-session-check.sh`'i
  düşürdü (managed, +x, v9+) — ama Claude Code'un onu çalıştırması için `.claude/settings.json`'a
  kayıt gerek. settings.json'ı **oku**, aşağıdaki alanı **merge et** (var olan `hooks` girdilerini
  **ezme**, sadece ekle; aynı komut zaten varsa tekrar ekleme):
  ```json
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/vibe-session-check.sh", "timeout": 5 } ] }
    ]
  }
  ```
  Hook **sessizdir** (her şey yolundaysa hiçbir şey basmaz) ve **asla bloklamaz** (her yolda `exit 0`).
  Repo-tracked → git'e girer, repoyu klonlayan tüm ekip için çalışır. Kullanıcıya bunu tek cümleyle
  söyle: "ekip geneli, sessiz, bloklamaz".
- **context-mode kurulumu (HER ZAMAN, sorulmadan — zorunlu bağımlılık, opsiyonel değil):**
  0. **Önce guard:** `command -v npm` boş dönerse **adımı tamamen atla** — kurmayı deneme, hata gösterme.
     "npm yok, context-mode atlandı" diye tek satır bas ve Faz 6 tablosuna satır ekle. Faz 3 durmaz.
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
- **caveman kurulumu (HER ZAMAN, sorulmadan — zorunlu bağımlılık, opsiyonel değil):**
  caveman çıktı-sıkıştırma modudur (~%75 output token tasarrufu, teknik doğruluk korunur).
  Kurulum Faz 2'nin 4. sorusunda zaten onaylandı — **burada tekrar onay isteme.**
  0. **Önce guard:** `command -v curl` boş dönerse (ya da Windows/PowerShell ortamındaysan) `install.sh`
     yerine PowerShell yolunu kullan:
     ```powershell
     irm https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.ps1 | iex
     ```
     İkisi de yoksa **adımı tamamen atla** — "curl yok, caveman atlandı" diye tek satır bas, Faz 6
     tablosuna satır ekle. Faz 3 durmaz.
  1. Dry-run çalıştır, çıktıyı **bilgi olarak** bas (hangi agent'lar tespit edildi, ne yazılacak) —
     durup cevap bekleme:
     ```bash
     curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash -s -- --dry-run --with-init
     ```
  2. Hemen ardından aynı komutu `--dry-run` **olmadan** çalıştır. Installer makinedeki tüm agent'ları
     auto-detect eder (Claude Code, Cursor, Codex, Gemini CLI, opencode, Windsurf, Copilot … 34 tane),
     her biri için o agent'ın native kurulum yolunu işletir. Tekrar çalıştırmak güvenli (idempotent).
  3. **Repo dışına yazılan yolları açıkça raporla** — `~/.claude`, `~/.config/opencode`, `~/.gemini`,
     `~/.openclaw/workspace`. Bu, Antigravity `mcp_config.json` kuralının aynısı: kullanıcının home
     dizini vibe-setup'ın normal kapsamı değil, **sessizce yapma**.
  3.5. **Clobber guard:** `install.sh` repo-içi rule dosyalarına yazar ve var olanı koruduğu garanti
     DEĞİL. Çalıştırmadan **önce** var olanların sha'sını al (`.cursor/rules/caveman.mdc`,
     `.windsurf/rules/caveman.md`, `.clinerules/caveman.md`, `.github/copilot-instructions.md`,
     `.opencode/AGENTS.md`), **sonra** karşılaştır. Önceden var olan bir dosya değiştiyse: kullanıcıya
     **açıkça bildir** ve `git diff` ile ne değiştiğini göster (repo git'liyse zaten kurtarılabilir;
     değilse bunu da söyle). Sessizce geçme.
  4. `--with-init`'in **repoya** düşürdüklerini NEW olarak listele: `.cursor/rules/caveman.mdc`,
     `.windsurf/rules/caveman.md`, `.clinerules/caveman.md`, `.github/copilot-instructions.md`,
     `.opencode/AGENTS.md`. (`AGENTS.md`'deki caveman satırı bunlardan bağımsız — o `init`'in
     managed template'inden gelir, v8+.)
  5. Kullanıcı Faz 2'de "Sadece agnostik" dediyse ya da pipe-to-shell'e itiraz ederse, ısrar etme —
     indir-oku-çalıştır alternatifini bilgi olarak bırak:
     ```bash
     curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh -o install.sh
     # incele, sonra:
     bash install.sh --with-init
     ```
  6. Kurulum başarısız olursa ya da atlandıysa **Faz 3 durmaz** — uyarı bas, Faz 6
     kullanıcı-aksiyon tablosuna satır ekle.
- Script var olanı **ezmez** (SKIP). Çıktıdaki NEW/SKIP/EDIT'i kullanıcıya aktar.

### 4. Stack-bağımlı içerik (sen üret — repoyu OKU, uydurma)

> **Bu fazın sert sınırı:** repoyu **oku**, mevcut kaynak/config/test dosyalarını **yazma**. Bu fazda
> ürettiğin her şey ya yeni dosya ya da doküman-meta dosyasına ekleme. Bir madde ancak canlı koda
> dokunarak tamamlanabiliyorsa → **atla + Faz 6'ya satır**. Bkz `## İlkeler`.

Onaylanan her madde için:
- **CLAUDE.md**: modül kökü kuralı, komutlar (profilden), mimari özet, **Gotchas** (koddan çıkarılması zor
  tuzaklar — gerçek koddan çıkar), git workflow. İşaretçi tarzı: docs'a yönlendir, içerik dökme.
  Ayrıca CLAUDE.md'ye **çıktı modu kuralı** yaz: bu repoda caveman modu (seviye `full`) zorunludur —
  aktif değilse `/caveman full` çalıştır; kod, commit mesajı ve PR metni normal yazılır. Bu kural
  hook'suz agent'lar için (Codex, Warp, Kilo Code, Roo Code, goose, Devin…) zorlamanın **tek**
  dayanağıdır — onlarda kurulum otomatik aktive olmaz.
  Gotchas'a şunu da ekle: **subagent/alt-görev başlatan bir akış varsa, o subagent'lara hem context-mode
  hem caveman kullanım talimatı açıkça verilmeli** — subagent taze context alır, parent'ın context-mode
  ve caveman kurallarını miras almaz (Faz 3 ikisini de zorunlu kurdu; bu, o kurulumun subagent'lara da
  işlemesini sağlayan tribal bilgi).
- **docs**: iskeletteki `<TODO>`'ları gerçek içerikle değiştir (kod haritası, conventions).
- **README mimari diagramı (zorunlu deliverable):** README.md'nin başına (girişten hemen sonra) tek bir
  mermaid diagram + 2-3 cümle özet **ekle** — mevcut metni yeniden yazma/yeniden düzenleme, sadece insert.
  Zaten bir mimari diagram varsa dokunma, Faz 6'da "mevcut diagram korundu" de. — proje tek kutu, çevresinde **dış bağlantılar** (DB, harici
  API'ler, 3rd-party servisler, kullanıcı/istemci). Çok detaya girme, sadece sistem-sınırı görünümü.
  Repoyu **oku**, gerçek bağlantıları çıkar — uydurma. Proje gerçekten diagram'a uygun değilse (ör.
  tek-dosyalık script), Faz 6'da bunu gerekçeli olarak not düş — sessizce atlama.
  `docs/architecture/overview.md`'ye (`<TODO>`'yu doldurarak) daha DETAYLI diagramlar (modül/veri akışı)
  ekle, README'ye link ver.
- **(ops) llms.txt**: init bunu **düşürmez** (iç repoda tüketicisi yok). Sadece dış LLM/dokümantasyon
  sitesi tüketecekse `llmstxt.org` formatında elle ekle.
- **Test harness**: MODULE_DIR'de saf/deterministik bir fonksiyon bul, dile uygun **gerçek geçen** test yaz
  (profil `TEST_FIND` deseni). Çalıştır, geçtiğini doğrula. Test **yeni dosyadır** — mevcut test dosyasına
  ekleme yapma, mevcut testleri düzenleme.
  - **Uygun fonksiyon yoksa kodu test edilebilir hale GETİRME** (export etme, imzayı değiştirme, bağımlılık
    enjekte etme, dosya bölme — hepsi yasak). Test adımını **atla**, Faz 6 tablosuna "test harness: saf
    fonksiyon bulunamadı, önce şu refaktör gerekiyor (öneri, uygulanmadı)" satırı düş.
- **pre-commit**: nested module ise `cd <MODULE_DIR>` ekle (staged yolları MODULE_DIR'e göre düzelt).
  Hook fmt'i **otomatik** ayarlar: file-capable stack'te sadece staged dosyalar (eski dirt bloklamaz),
  scope edilemeyen stack'te (java/rust/dotnet) advisory + "CI zorlasın". Tool kurulu değilse atlar.
  doc-sync default advisory (`git config vibe.strictdocs true` ile blocking — Faz 2'de sordun).
  `git config core.hooksPath .githooks` + `git config commit.template .gitmessage` öner.
- **settings.json `permissions.allow`**: profil `TEST`/`BUILD`/`FMT` + salt-okunur git (`status/diff/log/
  show/branch`). Mutasyon yapanları (`git add`, `git commit`) **dahil etme**.
- **settings.json `permissions.deny`**: büyük üretilmiş/vendor asset'leri (lockfile değil — derlenmiş
  bundle, swagger, dist/, generated). `Read(<path>)` olarak ekle. **Sorma — ekle ve Faz 6'da hangi
  yolları eklediğini raporla** (geri alması tek satır silmek; blocking soru etmeye değmez).
- **Plugin/MCP paylaşımı**: `extraKnownMarketplaces` + `enabledPlugins` (ya da bare server için tracked
  `.mcp.json`). Harici repo → açık onay; classifier bloklarsa kullanıcıya elle ekletecek snippet ver.
  - **Sadece projeye-özgü MCP'yi repoya sabitle** — bu projenin DB'si, iç API doküman MCP'si, Jira board'u
    gibi ekibin ortak kullandığı, domaine bağlı sunucular. **Kanıt yoksa SORMA:** repoda zaten `.mcp.json`
    ya da bir MCP izi varsa onu pin'le; yoksa soru sorma, Faz 6 tablosuna "ekibe sabitlenecek projeye-özgü
    MCP varsa ekle" satırı koy. İki ürünü preselect etme.

### 5. Doğrula
- Üretilen her şeyi çalıştırarak doğrula: test (`TEST`), fmt (`FMT`), build (`BUILD`), hook kuru-çalıştırma.
  - `FMT` profilden gelir ve **check-only**'dir. Write-mode'a çevirme. Mevcut kodda önceden var olan fmt
    ihlallerini **düzeltme** — raporla, Faz 6 tablosuna satır düş, geç.
  - `TEST` mevcut testleri kırıyorsa: senin eklediğin test yüzünden değilse **dokunma** — bu repo zaten
    kırıktı. Raporla, Faz 6'ya satır, akışı durdurma.
- settings.json düzenledikten sonra JSON geçerliliğini kontrol et.
- Hiçbir şeyi "tamam" deme önce çalıştırmadan.

- **Zorunlu bağımlılık smoke check (atlanmaz).** Faz 3 kurulumu "çalıştı" demek yetmez — kurulumun
  gerçekten tuttuğunu doğrula. Hepsi offline, ağsız, saniyeler:
  ```bash
  # caveman: aktivasyon hook'u flag dosyası yazar
  ls "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.caveman-active" 2>/dev/null && echo "caveman: flag var" || echo "caveman: flag YOK"
  # context-mode: binary PATH'te mi
  command -v context-mode >/dev/null && echo "context-mode: binary var" || echo "context-mode: binary YOK"
  # repo-tracked kayıtlar gerçekten merge oldu mu (jq varsa; yoksa grep)
  grep -q 'context-mode' .claude/settings.json && echo "settings.json: context-mode kayıtlı" || echo "settings.json: context-mode YOK"
  ```
  Sonuçları **tablo olarak** kullanıcıya bas. Bir madde başarısızsa:
  - Faz 6 kullanıcı-aksiyon tablosuna düzeltme komutuyla satır düş,
  - **akışı durdurma, tekrar kurmayı deneme** (kurulum zaten çalıştı; ikinci deneme aynı sonucu verir),
  - "kuruldu" DEME — smoke geçmediyse raporda açıkça "kurulum doğrulanamadı" yaz.
  - `.caveman-active` yoksa bu **normal de olabilir**: flag'i caveman'in `SessionStart` hook'u yazar,
    yani ilk kurulumdan sonra **yeni bir session açılana kadar** görünmez. Bunu böyle raporla —
    "caveman kuruldu, aktivasyon bir sonraki session'da doğrulanacak" — arıza gibi gösterme.

### 6. AFTER audit + checklist + özet
- `bash "$SKILL_DIR/scaffold.sh" audit .` tekrar çalıştır → AFTER `SCORE=N/M` + satır marklar.
- **Before/After uyumluluk tablosu** göster (her kategori + toplam):

  | Kategori | Önce | Sonra |
  |---|---|---|
  | BAĞLAM | x/n | y/n |
  | … | | |
  | **TOPLAM** | **N₀/M** | **N₁/M** |

  (Önce = Faz 1'de sakladığın, Sonra = bu audit. Kategori sayıları satır marklarından.)
- `vibe-checklist-template.md`'yi repo köküne `vibe-checklist.md` olarak kopyala, `[x]`/`[ ]` doldur,
  her satıra dosya referansı koy.

- **Kullanıcı-aksiyon tablosu** (zorunlu çıktı) — insanın doldurması/karar vermesi gereken her şey:

  | Dosya | Gereken aksiyon |
  |---|---|
  | CLAUDE.md | `<TODO>` gotchas'ı tribal bilgiyle doğrula |
  | llms.txt / docs | `<TODO>` placeholder'ları doldur |
  | .gitmessage | `<TICKET-KEY>` formatını projeye uyarla |
  | .claude/settings.json | eklenen `permissions.deny` yollarını gözden geçir (Faz 4 sormadan ekledi) |
  | .mcp.json / settings.json | ekibe sabitlenecek projeye-özgü MCP varsa ekle (kanıt yoktu, sorulmadı) |
  | Codex CLI / Gemini CLI (Antigravity dışı) / Kimi Code | context-mode MCP kaydı (opsiyonel — zorunlu değil) |
  | test harness (atlandı) | saf fonksiyon yoktu — önerilen refaktör (uygulanmadı, canlı koda dokunulmaz) |
  | mevcut fmt/test ihlalleri | repoda önceden vardı — düzeltilmedi, canlı koda dokunulmaz |
  | context-mode (npm yoktu → atlandı / smoke geçmedi) | Node/npm kurup `npm install -g context-mode` |
  | caveman (kurulum reddedildi / atlandı / agent tespit edilemedi) | tek-agent kurulum komutu — snippet aşağıda |
  | README mimari diagramı | bilinçli atlandıysa: neden (proje uygun değil) burada gerekçelendirilir |
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
  - **caveman tek-agent kurulumu** (auto-detect kaçırdıysa ya da kurulum reddedildiyse):
    ```bash
    npx skills add JuliusBrussee/caveman -a <agent-id>   # cursor | codex | windsurf | cline | kilo | roo | warp | goose | …
    ```
    Rule dosyası düşmeyen agent'larda caveman **session başına** `/caveman full` ile açılır.

- **Token raporu:** süreç maliyetli değilse kullanıcıya **`/cost`** çalıştırmasını öner (Claude Code'un
  built-in kesin token/maliyet komutu). Skill kendi token sayamaz — uydurma sayı verme; `/cost`'a yönlendir.

- Kısa kapanış: önce→sonra skor, ne kuruldu, ne kullanıcı kararına kaldı, sonraki adım.

## Upgrade akışı (zaten kurulu repo + yeni sürüm)

Repo daha önce kurulduysa ve engine/skill yeni sürümdeyse — **sıfırdan init DEĞİL**. Sıfırdan init eksikleri
düşürür ama mevcut dosyaları SKIP'ler → eski/buggy bir managed dosya init'le **asla** güncellenmez. Upgrade
dokunulmamış olanları sürüme taşır, elle düzenlenmişleri CONFLICT olarak sana getirir.

### 1. upgrade çalıştır
`bash "$SKILL_DIR/scaffold.sh" upgrade .` → makine-okur rapor:
- `UPDATE=` — **dokunulmamış** managed dosyalar yeni template'e otomatik güncellendi (sha ile kanıtlı; restamp + manifest).
- `ADD=` — eksik dosya (silinmiş ya da yeni sürümde gelen).
- `CONFLICT=` — **elle düzenlenmiş** managed dosya; engine **EZMEDİ**, sana bıraktı.
- `MIGRATED=` — dosya-dışı dönüşümler (alan rename vb.).

### 2. UPDATE / ADD / MIGRATED — otomatik; sadece bildir
- UPDATE: engine zaten regen etti. Hangileri değişti söyle, `git diff` öner.
  - `.githooks/pre-commit` UPDATE edildiyse **ve** `git config --get --local vibe.strictdocs` boş
    dönerse: Faz 2'deki AYNI soruyu sor — **"doc-sync'i zorlayıcı (blocking) yapayım mı?"** Evet ise
    `git config vibe.strictdocs true` çalıştır.
- ADD: `bash "$SKILL_DIR/scaffold.sh" init .` eksikleri düşürür (idempotent; var olanı ezmez).
  - `.claude/hooks/vibe-session-check.sh` ADD edildiyse (v8 → v9 geçişi): dosya düştü ama **kaydı
    düşmedi** — `.claude/settings.json` `seed` sınıfı, engine ona hiç dokunmaz. Faz 3'teki `hooks.SessionStart`
    bloğunu settings.json'a **merge et** (var olan `hooks` girdilerini ezme, aynı komut varsa tekrar ekleme).
    Bu adım atlanırsa hook repoda durur ama hiç çalışmaz.
- MIGRATED: ne yapıldığını aktar.

### 3. CONFLICT — sen (LLM) merge et, ASLA körlemesine ezme
Her CONFLICT dosyası elle düzenlenmiş; engine değdirmedi. Her biri için:
- Mevcut dosyayı **OKU**; yeni template'i gör (geçici bir dizine `init` çalıştırıp aynı yolu üret, ya da
  `scaffold.sh`'taki `render_artifact` içeriğiyle kıyasla).
- **3-yönlü merge sende:** kullanıcının kasıtlı düzenlemesini **KORU**, yeni sürümün getirdiği iyileştirmeyi
  (ör. bug fix) üstüne uygula. İkisini birleştiren tek dosya öner.
- Diff göster + **onay al**. Onaysız yazma. Kullanıcı "benimkini koru" derse dokunma (CONFLICT kalır, sorun değil).

### 4. LLM artifact'leri (CLAUDE.md, test, docs, deny) — re-audit
Manifest'te `llm` listesindekiler; engine **hiç dokunmaz**. Yeni sürüm checklist'e madde eklediyse:
- `audit` çalıştır → yeni ❌'leri gör.
- Sadece **gerçekten yeni** gereksinim için hedefli içerik öner (yeni bölüm/append). Mevcut CLAUDE.md'yi
  **toptan yeniden yazma** — gotchas/domain bilgisini koru (önceki turdaki "re-run ezer" riski tam burada).

### 5. Doğrula + kapat
- `audit` tekrar → SCORE. Üretilen/merge edilen her şeyi çalıştırarak doğrula (test/fmt/hook).
- Kısa özet: ne otomatik güncellendi (UPDATE/ADD/MIGRATED), CONFLICT'ler nasıl merge edildi, llm tarafında ne eklendi.

## Remove akışı (vibe-setup'ı kaldır)

Kullanıcı **açıkça** "kaldır"/"remove"/"geri al" dediğinde çalışır — asla proaktif önerilmez, audit/init/
upgrade akışının hiçbir noktasında "kaldırmak ister misin" diye sorulmaz.

### 1. Dry-run (her zaman önce)
`bash "$SKILL_DIR/scaffold.sh" remove .` — **`--apply` OLMADAN**.
- Çıktı "Manifest yok" derse: "Bu repoda vibe-setup kurulu değil (ya da zaten kaldırılmış)." de, bitir.
- SİLİNECEK bloğu **sadece** `(yok)` satırından ibaretse (altında `.gitignore: "..." satırı` gibi ek
  bir madde YOKSA) **ve** ELLE DÜZENLENMİŞ de `(yok)` ise: "Kaldırılacak bir şey yok." de, bitir — onay
  isteme. SİLİNECEK altında dosya listesi boş olsa bile bir `.gitignore` satırı görünüyorsa, bu kısayolu
  ATLA — normal onay akışına devam et.

### 2. Göster + onay
Dry-run çıktısını (SİLİNECEK / ELLE DÜZENLENMİŞ / ÖNCEDEN VARDI / KAPSAM DIŞI) olduğu gibi kullanıcıya
göster — zaten insan-okur, yeniden formatlama yok. Açıkça sor: **"Listelenen dosyaları sileyim mi?"**
Hayır ise dur (dry-run zaten hiçbir şey silmedi).

### 3. Uygula
Evet ise: `bash "$SKILL_DIR/scaffold.sh" remove . --apply`.

### 4. Git config temizliği (sadece gerçekten set edilmişse)
`vibe-remove-report.md`'yi (repo kökü, `--apply` bunu yazdı) oku. Rapor üç git config komutunu
(`core.hooksPath`, `commit.template`, `vibe.ticketre`) koşulsuz listeler — ama hangisinin bu repoda
**gerçekten** set edildiğini scaffold.sh bilmiyor (bunları o set etmedi — `vibe.ticketre`'yi Faz 2'de
sorup set ettin, `core.hooksPath`/`commit.template`'i Faz 4'te önerdin; kullanıcı elle de çalıştırmış
olabilir). Kontrol et:
```
git config --get --local core.hooksPath
git config --get --local commit.template
git config --get --local vibe.ticketre
```
Sadece **boş dönmeyenler** için kullanıcıya sor: "Bu ayarları da kaldırayım mı?" Evet ise sadece
onaylananlar için `git config --local --unset <key>` çalıştır — hepsini birden değil, tek tek sorulanı.

### 5. Kapanış
- Kapsam dışı hatırlat: CLAUDE.md, docs/, tests/, .claude/settings.json içeriği, vibe-checklist.md elle
  gözden geçirilmeli — bunlara hiç dokunulmadı.
- **Ölü hook kaydı uyarısı:** `remove` `.claude/hooks/vibe-session-check.sh`'i (managed olduğu için)
  sildiyse, `settings.json`'daki `hooks.SessionStart` kaydı **geride kalır** — settings.json kapsam dışı,
  engine ona dokunmaz. Kullanıcıya söyle: o bloğu elle sil, yoksa Claude Code her session'da var olmayan
  bir dosyayı çalıştırmaya çalışır.
- `vibe-remove-report.md`'nin repo kökünde kalıcı kayıt olarak durduğunu söyle (silinmez, bu işlemin
  tek receipt'i).
- **caveman kapsam dışı** — `vibe-remove` onu kaldırmaz (context-mode gibi). Kullanıcı isterse:
  ```bash
  npx -y github:JuliusBrussee/caveman -- --uninstall   # hook'lar, plugin, extension, opencode plugin
  npx skills remove caveman                            # `npx skills add` ile kurulanlar (ayrı CLI)
  ```
  Bu iki komut da `--with-init`'in düşürdüğü repo-içi rule dosyalarını **silmez**
  (`.cursor/rules/`, `.windsurf/rules/`, `.clinerules/`, `.github/copilot-instructions.md`,
  `.opencode/AGENTS.md`) — elle silinir. `AGENTS.md`'deki caveman satırı ise vibe-setup'ın managed
  template'inin parçası; `remove` onu zaten kendi kuralına göre ele alır.

## İlkeler
- **Canlı koda ASLA dokunma.** Bu skill agent altyapısı kurar — çalışan yazılımı değiştirmez.
  Mevcut **kaynak, config ve test** dosyaları (uygulama kodu, `package.json`/`go.mod`/`pyproject.toml`
  gibi manifestler, CI tanımları, var olan testler) **hiçbir koşulda** düzenlenmez, taşınmaz, yeniden
  formatlanmaz, refaktör edilmez. "Sadece şu importu düzeltsem", "şu fonksiyonu test edilebilir yapsam",
  "bu arada şunu da formatlasam" — **hayır.** Bir adım ancak koda dokunarak tamamlanabiliyorsa: o adımı
  **ATLA**, Faz 6 kullanıcı-aksiyon tablosuna gerekçesiyle satır düş, akışı durdurma.
  - Yeni **dosya eklemek** serbest (test dosyası, docs, hook) — mevcut dosyayı **değiştirmek** değil.
  - Doküman/meta dosyalara (`README.md`, `.gitignore`, `AGENT.md`) **ekleme** yapılabilir: mevcut içerik
    silinmeden, append/insert. İçerik yeniden yazılmaz, yeniden düzenlenmez.
  - Formatter'lar zaten check-only (`gofmt -l`, `prettier --check`, `ruff format --check`,
    `dotnet format --verify-no-changes`, `shfmt -d` …) — **asla** write-mode varyantına (`-w`, `--write`,
    `fix`) çevirme.
- **Önce onay**, sonra üret. Toplu dosya bombardımanı yok.
- **Az soru.** Sorular tek `AskUserQuestion` çağrısında toplanır; ardışık tek-soru round-trip'i yok.
  Tipik kurulum **1 soru** (Faz 2 batch'i); upgrade varsa +1, stack `unknown` ise +1. Varsayılanı olan
  hiçbir şey ayrıca sorulmaz — takip sorusu yerine şıkların içine gömülür.
- **Oku, uydurma.** Stack-bağımlı içerik gerçek koddan gelir.
- **Doğrulanmadan tamam yok.** Her artefakt çalıştırılır.
- **Agnostik kal.** Dile özgü tek şey `stack-profiles.md` tablosu; geri kalan her dilde aynı.
- **Idempotent.** Tekrar çalıştırmak güvenli; script var olanı ezmez, sen de etme.
- **Sürümlü + üzerine-yazmaz.** Zaten kuruluysa init değil **upgrade**. Engine elle düzenlenmiş managed
  dosyayı **asla körlemesine ezmez** — CONFLICT olarak sana getirir, sen 3-yönlü merge edersin.
