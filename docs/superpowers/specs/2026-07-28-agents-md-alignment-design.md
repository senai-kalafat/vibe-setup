# vibe-setup: AGENTS.md ekosistemiyle hizalanma (4 madde) — design

Date: 2026-07-28
Status: approved
Ticket: VIB-12

## Kaynak

Resmi AGENTS.md standardı (https://agents.md/) incelendi (context-mode ile fetch+index edilip
sorgulandı). vibe-setup zaten bu standardı üretip koruyan bir araç; bu inceleme "onlarla rekabet"
değil, "onların tanımladığı ekosistemi ne kadar tam kapsıyoruz" sorusuna cevap arıyor. 4 somut boşluk
bulundu, kullanıcı onayladı.

## Plan bölünmesi

Bu spec 4 maddeyi kapsıyor ama implementasyon **iki ayrı plana** bölünecek:
- **Plan A** — Madde 2 (init-aider) + Madde 3 (dokümantasyon) + Madde 4 (legacy AGENT.md migrasyonu):
  küçük, birbirine yakın, tek plana sığar.
- **Plan B** — Madde 1 (nested/monorepo): büyük, ayrı implementation plan.

## Kapsam kararları

### 1. `init-nested` — monorepo/nested AGENTS.md desteği

**Problem:** Resmi standart "closest AGENTS.md wins" modelini öneriyor — büyük monorepo'da her
alt-paket kendi AGENTS.md'sini taşıyabilir (örn. OpenAI'nin kendi reposunda 88 tane var). vibe-setup
şu an `detect_profile` ile TEK stack tespit ediyor (ilk eşleşen manifest); `audit()` çoklu-manifest
durumunda sadece "Not: nested module ... elle teyit et" diye bir uyarı basıyor, hiçbir otomasyon yok.

**Karar:**
- `scaffold.sh`'a yeni komut: `init-nested <SUBDIR>`.
- `detect_profile`'ın mantığı `SUBDIR` köküne göre çalışacak şekilde parametrize edilir (mevcut
  `manifest_dir`/`detect_profile` fonksiyonları `.` yerine verilen kökten arar).
- SADECE `<SUBDIR>/AGENTS.md` + `<SUBDIR>/CLAUDE.md` (yeni, boş iskelet — LLM dolduracak, SUBDIR'in
  kendi stack'ine göre komutlar) düşürülür.
- **Git-hook / PR template / .gitmessage / .claude/settings.json DOKUNULMAZ** — bunlar repo-geneli,
  zaten kökte bir kez var; per-paket tekrar üretmek anlamsız ve `init()`'in "her komut tek iş yapar"
  ilkesini bozar.
- `<SUBDIR>/AGENTS.md` içeriği kök template'in küçük bir varyasyonu: "Bu alt-paketin kendi kural
  dosyası; kök `CLAUDE.md` genel repo kurallarını, `<SUBDIR>/CLAUDE.md` SADECE bu paketin farklarını
  içerir."
- **Manifest genişlemesi:** `.vibe-setup.json`'a yeni üst-seviye `nested` bölümü —
  `{ "<SUBDIR>/AGENTS.md": {...}, "<SUBDIR>/CLAUDE.md": {...} }`, `managed`/`extras` ile AYNI
  provenance şeması (v/sha/created). VIB-11'in `write_manifest` dersi burada da geçerli: yeni bir
  managed-benzeri yol eklenince `WRITTEN_PATHS`/`STAMP_VERSION` gate'ine düşmezse, başka bir komut
  (`upgrade`/`init-cursor` vb.) onu yanlışlıkla "blessed" edip `remove`'un güvenle silinebilir
  sanmasına yol açar — bu yüzden `nested` yolları da `sha_for_manifest`/`v_for_manifest`/
  `created_for_manifest`'in WRITTEN_PATHS kontrolünden geçmeli.
- `audit()` genişler: `manifest_dir`-tarzı arama artık İLK eşleşeni değil, TÜM eşleşen manifest
  dizinlerini (depth 3, aynı hariç-tutmalarla) listeler → "N ayrı stack bulundu: <dizin listesi>"
  şeklinde makine-okur bir sinyal basar (mevcut `UPDATE_AVAILABLE=` sinyaliyle aynı desen).
- `remove()` ve `upgrade()` mantığı `nested` bölümünü de `managed_paths`/`extra_paths` gibi tarar
  (aynı never-clobber / CONFLICT kuralları).
- **SKILL.md akışı:** audit'te çoklu-stack sinyali görülürse kullanıcıya sor: "Bu bir monorepo gibi
  görünüyor (N paket: X, Y, Z). Her paket için ayrı AGENTS.md/CLAUDE.md ister misin?" — evetse
  onaylanan her SUBDIR için `init-nested` çağrılır, sonra LLM her `<SUBDIR>/CLAUDE.md`'yi o paketin
  GERÇEK komutlarıyla doldurur (aynı "oku, uydurma" disiplini).

**Boyut notu:** Bu madde tek başına audit-çoklu-tespit + yeni komut + yeni render template + manifest
şema genişlemesi (upgrade/remove'un ikisini de etkiler) + SKILL.md akış değişikliği + testler
gerektiriyor — diğer 3 maddeden çok daha büyük. **Ayrı bir implementation plan olarak ele alınacak**
(bu spec kapsıyor, ama `writing-plans` bunun için ayrı bir plan dosyası üretecek).

### 2. `init-aider` — Aider desteği

**Problem:** Aider, AGENTS.md'yi native okumuyor; `.aider.conf.yml` içine `read: AGENTS.md`
eklemek gerekiyor (resmi FAQ'dan doğrulandı). Bu, `init-cursor`/`init-gemini` ile TAM AYNI sınıf:
ince bir adapter dosyası, ekstra dosya isteyen bir araç.

**Karar:**
- Yeni `init_aider()` fonksiyonu, `init_cursor()`/`init_gemini()` ile birebir aynı kalıp:
  ```
  init_aider() {
    echo "vibe-setup init-aider — $(pwd)"
    write_extra .aider.conf.yml <<'EOF'
  # vibe-setup — Aider AGENTS.md'yi native okumaz; acikca isaretle.
  read: AGENTS.md
  EOF
    write_manifest
  }
  ```
- `write_extra` zaten "var olan dosyayı asla ezme" davranışını veriyor (kullanıcının kendi
  `.aider.conf.yml`'i varsa — model ayarları vb. — SKIP basılır, dokunulmaz; aynı Cursor/Gemini
  limitasyonu, gotcha'da belgelenir).
- `.aider.conf.yml` → `extra_paths()`'e eklenir (managed_paths'e GİRMEZ — Cursor/Gemini ile aynı
  sınıf: bir kez düşer, drift/upgrade takibi yok, audit satırı yok).
- `case "$CMD"` içine `init-aider) init_aider ;;` eklenir; kullanım mesajı ve script başlığındaki
  komut listesi güncellenir.
- **SKILL.md:** Faz 2'nin "hedef araç sorusu" üçlenir: "Cursor ve/veya Gemini CLI ve/veya Aider için
  ayrı context dosyası ister misin?" Faz 3'e `init-aider` çağrısı eklenir.
- **CLAUDE.md gotcha** "Araç desteği" satırına Aider eklenir.
- **README:** Kurulum bölümüne Aider için kısa bir satır (Cursor/Gemini paragraflarının yanına,
  ayrıntılı prose madde 3'te).

### 3. "Araç desteği" dokümantasyonunu genişlet

**Problem:** CLAUDE.md'nin "Araç desteği" gotcha'sı ve README sadece Codex + Kimi Code'u "AGENTS.md
native okur" diye anıyor. Resmi sayfa AGENTS.md'yi native okuyan çok daha geniş bir liste veriyor:
Zed, Warp, VS Code, Devin, Amp, RooCode, Kilo Code, GitHub Copilot coding agent, Windsurf, Augment
Code, goose, opencode, Junie, Phoenix, Semgrep, Ona, Factory, Jules — bunların HİÇBİRİ ekstra dosya
istemiyor (Cursor/Gemini/Aider'ın aksine).

**Karar (saf dokümantasyon, kod değişikliği yok):**
- CLAUDE.md'nin "Araç desteği" gotcha'sı güncellenir: "Codex ve Kimi Code" yerine tam liste (gruplu,
  okunur bir cümle — hepsini tek tek saymak yerine "AGENTS.md'yi native okuyan geniş bir ekosistem
  var (Zed, Warp, VS Code, Devin, Amp, RooCode, Kilo Code, GitHub Copilot coding agent, Windsurf,
  Augment Code, goose, opencode, Junie, Phoenix, Semgrep, Ona, Factory, Jules, Codex, Kimi Code) —
  bunların hiçbiri ekstra dosya istemez; sadece Cursor/Gemini CLI/Aider ayrı context dosyası ister."
- README'nin "Nasıl çalışır" / Kurulum bölümlerinde aynı liste-genişlemesi yansıtılır.
- SKILL.md Faz 2'nin hedef-araç sorusuna bir bilgi notu eklenir (yukarıdaki liste bir kez daha
  anılmaz, sadece "AGENTS.md zaten geniş bir ekosistemi kapsar" diye kısa referans — tekrar
  şişirmemek için tam liste sadece CLAUDE.md/README'de).

### 4. Legacy tekil `AGENT.md` tespiti + migrasyon

**Problem:** Resmi migrasyon tavsiyesi: `mv AGENT.md AGENTS.md && ln -s AGENTS.md AGENT.md` (eski
adı sembolik link olarak geri bırak, geriye uyumluluk). vibe-setup'ın `init()`'i bunu tanımıyor —
`AGENT.md` (tekil) var olan bir repoda `init` çalıştırılırsa, `AGENTS.md` yokmuş gibi davranıp
sıfırdan boş bir `AGENTS.md` template'i düşürür; kullanıcının `AGENT.md`'deki içeriği (varsa) yetim
kalır.

**Karar:**
- `write_managed`'in `AGENTS.md`'ye özel bir ön-adımı: `AGENTS.md` yoksa VE `AGENT.md` (tekil) VARSA
  → normal template render etmek yerine `mv AGENT.md AGENTS.md && ln -s AGENTS.md AGENT.md` çalıştırır,
  `EDIT`-sınıfı bir mesaj basar (mevcut `.gitignore` satır-ekleme mesajının şeffaflık deseniyle aynı:
  "  MIGRATE AGENT.md → AGENTS.md (+ symlink geri bırakıldı)").
- **Provenance kritik nokta:** Bu içerik vibe-setup'ın ÜRETTİĞİ template değil, kullanıcının
  TAŞINMIŞ içeriği — manifestte `created: false` olarak işaretlenmeli (mevcut `created_for_manifest`
  mantığı zaten "NEW_PATHS'te değilse false" diyor; migration NEW_PATHS'e EKLENMEMELİ, sadece
  WRITTEN_PATHS'e eklenmeli ki sha güncel kalsın ama `remove` bunu asla silmeye kalkışmasın — aynı
  "önceden vardı, dokunulmadı" sınıfı).
- `audit()`'e tespit satırı eklenir: `AGENT.md` var + `AGENTS.md` yoksa → `row "$NO" "AGENTS.md"
  "legacy AGENT.md bulundu → init migrate eder"` (init çalışmadan ÖNCE bile sinyal versin).
- SKILL.md'de ekstra bir onay adımı GEREKMİYOR — bu işlem yıkıcı değil (içerik kaybı yok, sadece
  taşıma + geriye-uyumlu symlink), `init`'in zaten "asla ezmez" ilkesiyle aynı güvenlik sınıfında;
  `init` zaten kullanıcı onayıyla (Faz 2) çalıştırılıyor, ayrıca sormaya gerek yok.

## Kapsam dışı (bilinçli)

- Madde 1 (nested) için: nested `CLAUDE.md`'lerin İÇERİĞİNİ otomatik doldurmak — bu LLM/SKILL.md'nin
  işi, scaffold.sh sadece iskelet düşürür.
- Madde 1 için: `upgrade`/`remove`'un `nested` bölümünü tam desteklemesi bu spec'in parçası (tasarım
  kararı olarak yukarıda var) ama gerçek implementasyon detayları (kod) plan aşamasında netleşecek.
- Madde 4 için: çoklu `AGENT.md` (ör. alt-dizinlerde) — sadece kök dizin taranır, nested-AGENT.md
  migrasyonu kapsam dışı (madde 1 ile karışmasın diye bilinçli sınır).
- Diğer araçlar için native-okuma iddialarının HER BİRİNİN elle doğrulanması (agents.md'nin kendi
  listesine güveniliyor) — bu bir üçüncü-parti kaynağın aktarımı, vibe-setup'ın kendi testi değil.
