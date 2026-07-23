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

# vibe-setup

Bir repoyu AI/agent destekli geliştirmeye hazır hale getirir. İş ikiye ayrılır:
**deterministik** (script: tespit + agnostik iskelet) ve **akıllı** (sen: repoyu okuyup içerik üret).

Repo **zaten kuruluysa** (`.vibe-setup.json` ya da managed dosyalar var) ve yeni sürümdeysen: sıfırdan
init değil, **`## Upgrade akışı`**'nı izle (aşağıda) — engine değişen template'leri taşır, elle düzenlenmiş
dosyaları CONFLICT olarak sana getirir, sen merge edersin.

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
- **Hedef araç sorusu:** Claude varsayılan. AGENTS.md zaten Codex ve Kimi Code'u kapsar — bu ikisi
  ekstra dosya istemez, hiçbir şey yapma. Kullanıcıya sor: **"Cursor ve/veya Gemini CLI için ayrı
  context dosyası ister misin?"** Evet ise Faz 3'te ilgili `init-cursor` / `init-gemini`'yi çalıştır.
- **Ticket-key sorusu (zorunlu SOR, varsayma):** commit mesajında ticket-key zorlansın mı?
  Varsayılan **zorlamasız** (hook hiçbir şeyi bloklamaz). Kullanıcı isterse formatı da sor —
  standart `ABC-1234` mi, özel regex mi? Cevaba göre Faz 3 sonrasında:
  `git config vibe.ticketre '^[A-Z]{3}-[0-9]{1,4} '` (ya da kullanıcının regex'i). İstemezse hiçbir şey yapma.
- **Hangi maddeleri kuralım?** diye sor. Kullanıcı seçmeden dosya üretme.
  Tehlikeli/dışa-dönük olanları (plugin enable, harici repo, izin genişletme) ayrıca işaretle —
  bunlar açık onay ister, güvenlik sınıflandırıcısı da bloklayabilir.

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

### 4. Stack-bağımlı içerik (sen üret — repoyu OKU, uydurma)
Onaylanan her madde için:
- **CLAUDE.md**: modül kökü kuralı, komutlar (profilden), mimari özet, **Gotchas** (koddan çıkarılması zor
  tuzaklar — gerçek koddan çıkar), git workflow. İşaretçi tarzı: docs'a yönlendir, içerik dökme.
- **docs**: iskeletteki `<TODO>`'ları gerçek içerikle değiştir (kod haritası, conventions).
- **(ops) llms.txt**: init bunu **düşürmez** (iç repoda tüketicisi yok). Sadece dış LLM/dokümantasyon
  sitesi tüketecekse `llmstxt.org` formatında elle ekle.
- **Test harness**: MODULE_DIR'de saf/deterministik bir fonksiyon bul, dile uygun **gerçek geçen** test yaz
  (profil `TEST_FIND` deseni). Çalıştır, geçtiğini doğrula.
- **pre-commit**: nested module ise `cd <MODULE_DIR>` ekle (staged yolları MODULE_DIR'e göre düzelt).
  Hook fmt'i **otomatik** ayarlar: file-capable stack'te sadece staged dosyalar (eski dirt bloklamaz),
  scope edilemeyen stack'te (java/rust/dotnet) advisory + "CI zorlasın". Tool kurulu değilse atlar.
  doc-sync default advisory (`STRICT_DOCS=1` ile blocking). `git config core.hooksPath .githooks` +
  `git config commit.template .gitmessage` öner.
- **settings.json `permissions.allow`**: profil `TEST`/`BUILD`/`FMT` + salt-okunur git (`status/diff/log/
  show/branch`). Mutasyon yapanları (`git add`, `git commit`) **dahil etme**.
- **settings.json `permissions.deny`**: büyük üretilmiş/vendor asset'leri (lockfile değil — derlenmiş
  bundle, swagger, dist/, generated). `Read(<path>)` olarak ekle. Önce kullanıcıya doğrula.
- **Plugin/MCP paylaşımı** (istenirse): `extraKnownMarketplaces` + `enabledPlugins` (ya da bare server için
  tracked `.mcp.json`). Harici repo → açık onay; classifier bloklarsa kullanıcıya elle ekletecek snippet ver.
  - **Sadece projeye-özgü MCP'yi repoya sabitle** — bu projenin DB'si, iç API doküman MCP'si, Jira board'u
    gibi ekibin ortak kullandığı, domaine bağlı sunucular. Kullanıcıya **"ekibe sabitlenecek projeye-özgü
    MCP var mı?"** diye sor; saydığını pin'le. İki ürünü preselect etme.
  - **Evrensel kişisel araçları repoya GÖMME** (context-mode, context7 vb. — context penceresi/doküman
    yardımcıları). Projeden bağımsız faydalılar → `~/.claude/settings.json` (user-global) öner; repo-pin'lersen
    global'i olanda mükerrer, olmayana dayatma + marketplace erişimi şartı olur.

### 5. Doğrula
- Üretilen her şeyi çalıştırarak doğrula: test (`TEST`), fmt (`FMT`), build (`BUILD`), hook kuru-çalıştırma.
- settings.json düzenledikten sonra JSON geçerliliğini kontrol et.
- Hiçbir şeyi "tamam" deme önce çalıştırmadan.

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
  | .claude/settings.json | plugin enable / deny yolları onayı (gerekirse) |
  | … | (sadece gerçekten eksik/insan-gerektiren satırlar) |

  Sadece **açık kalan** maddeleri listele; tamamlananları koyma.
  - **Classifier-bloklanan satırlar** (permissions.allow/deny, plugin enable, MCP pin) için: tabloda
    "snippet'i ekle" demekle yetinme — **paste-hazır snippet'i tablonun hemen altına göm** (hangi dosya,
    hangi anahtar, tam içerik). Aksiyon kendi içinde tamamlanabilir olmalı.

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
- ADD: `bash "$SKILL_DIR/scaffold.sh" init .` eksikleri düşürür (idempotent; var olanı ezmez).
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

## İlkeler
- **Önce onay**, sonra üret. Toplu dosya bombardımanı yok.
- **Oku, uydurma.** Stack-bağımlı içerik gerçek koddan gelir.
- **Doğrulanmadan tamam yok.** Her artefakt çalıştırılır.
- **Agnostik kal.** Dile özgü tek şey `stack-profiles.md` tablosu; geri kalan her dilde aynı.
- **Idempotent.** Tekrar çalıştırmak güvenli; script var olanı ezmez, sen de etme.
- **Sürümlü + üzerine-yazmaz.** Zaten kuruluysa init değil **upgrade**. Engine elle düzenlenmiş managed
  dosyayı **asla körlemesine ezmez** — CONFLICT olarak sana getirir, sen 3-yönlü merge edersin.
