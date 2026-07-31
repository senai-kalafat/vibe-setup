# vibe-setup: `doctor` — kurulum teşhisi + otomatik bayatlık sinyali — design

Date: 2026-07-31
Status: approved
Ticket: VIB-17

## Problem

v0.4.0 çıktıktan sonra iki ayrı makinede kurulum güncellenmeye çalışıldı ve üç ayrı arıza yaşandı.
Hiçbiri kullanıcıya kendini açıkça göstermedi — hepsi yanıltıcı ya da sessiz:

1. **"Already latest" yalanı.** `claude plugin update` "zaten en güncel, v0.2.0" dedi. Sebep: o
   makinedeki marketplace **kaynak cache'i** bayattı; araç kendi bildiği en son sürümü doğru
   raporluyordu ama o sürüm gerçek değildi.
2. **İki-konum karışıklığı.** `claude plugin marketplace update` kaynağı tazeledi ama kurulu plugin
   ayrı bir snapshot olduğu için sürüm değişmedi (`plugin list` hâlâ 0.2.0). Tek komut yetmiyor;
   ikisi ayrı yerler:
   - kaynak: `~/.claude/plugins/marketplaces/<ad>/`
   - kurulu snapshot: `~/.claude/plugins/cache/<ad>/<ad>/<sürüm>/`
3. **Yanlış kaynak.** Bir makinede `marketplace.json`=0.1.0 + `plugin.json`=0.2.0 görüldü. Bu repo'nun
   geçmişinde böyle bir kombinasyon **hiç yok** (iki dosya `scripts/version-sync.sh` ile hep senkron:
   0.2.0 → 0.3.0 → 0.4.0). Yani o kopya bizim release akışımızdan geçmemiş — farklı/elle-düzenlenmiş
   bir kaynak. Kullanıcının bunu fark etmesinin hiçbir yolu yoktu.

Ortak payda: **kurulumun sağlığını sorgulayacak bir mekanizma yok.** `audit` hedef repoyu denetliyor,
aracın kendi kurulumunu denetleyen hiçbir şey yok.

## Kapsam kararları

### 1. Yeni komut: `scaffold.sh doctor [DIR]`

`audit` *hedef repoyu* denetler, `doctor` *aracın kendi kurulumunu*. Ayrı komut olması VIB-11'de
alınan "self-update'i audit akışına bağlama, elle-tetiklenen ayrı maintenance komutu olarak kalsın"
kararıyla tutarlı.

`DIR` argümanı diğer komutlarla aynı sözleşme (varsayılan `.`) — ama doctor'ın asıl referansı
**çalışan kopyanın kendi kökü** (`BASH_SOURCE` ile bulunur). Bu bilinçli: bir dev klonundan doctor
çalıştırıp Claude'un başka bir kopyayı kullandığını görebilmek teşhisin parçası.

### 2. Kontroller (üç grup)

**KURULUM** (Claude CLI varsa)
- kayıtlı marketplace kaynağı `senai-kalafat/vibe-setup` mı? (yanlış-kaynak arızası)
- kurulu sürüm (`plugin list --json` → `version`) ↔ kaynak cache'indeki `plugin.json` sürümü
  (**"already latest" yalanını yakalayan kontrol**; tamamen offline)
- kurulu snapshot yolu + kaynak cache yolu ikisi de basılır (iki-konum karışıklığı)

**MANIFEST TUTARLILIĞI** (her zaman, offline, dep yok)
- çalışan kopyada `.claude-plugin/plugin.json` == `.claude-plugin/marketplace.json` (İKİ alan) ==
  `.cursor-plugin/plugin.json`
- uyuşmazlık → bu kopya `scripts/version-sync.sh`'tan geçmemiş (0.1.0/0.2.0 arızası)

**KOPYA** (her zaman)
- çalışan kopyanın kökü, git repo mu, hangi commit/tag
- `origin` remote'u kanonik repo mu
- `--online` verildiyse: `git ls-remote --tags` ile upstream'de daha yeni `v*` tag var mı

### 3. Çıktı sözleşmesi

`audit`'in mevcut deseni birebir korunur: `✅/❌/—` satırları + `SCORE=N/M` footer. Her `❌`
**yapıştırılabilir düzeltme komutu** basar — teşhis edip çözümü söylemeyen satır olmaz.

Makine-okur sinyaller (SKILL.md bunlara tepki verir):
- `TOOL_UPDATE_AVAILABLE=<kurulu>-><mevcut>` — kurulu sürüm kaynaktakinden eski
- `TOOL_SOURCE_MISMATCH=<bulunan-repo>` — marketplace kaynağı kanonik repo değil
- `TOOL_MANIFEST_DRIFT=<dosya>:<sürüm>,...` — manifest sürümleri ayrışmış

Sinyaller sadece **gerçekten sorun varsa** basılır (audit'in `UPDATE_AVAILABLE` deseni gibi) — temizse
hiç görünmez, gürültü olmaz.

### 4. Otomatik yakalama: SKILL.md Faz 1

Faz 1 zaten hedef repo için `UPDATE_AVAILABLE=vX->vY` görünce kullanıcıya soruyor. Aynı desen araç
için de uygulanır: Faz 1'de `doctor` (offline, ağsız) çalıştırılır; yukarıdaki sinyallerden biri
varsa kullanıcıya **SORULUR**, sormadan hiçbir şey yapılmaz.

- `TOOL_UPDATE_AVAILABLE` → "Kurulu vibe-setup 0.2.0, kaynakta 0.4.0 var — güncelleme komutlarını
  vereyim mi?" (komutlar basılır; skill kullanıcının kabuğunda çalıştırmaz — `claude plugin …`
  Claude'un kendi kurulumunu değiştirir, açık onay ister)
- `TOOL_SOURCE_MISMATCH` / `TOOL_MANIFEST_DRIFT` → uyarı + temiz kurulum adımları

Ağ çağrısı yok: kurulu sürüm ile yerel kaynak cache'ini karşılaştırmak yaşanan üç arızanın da
**hepsini** yakalıyor. `--online` yalnızca elle `doctor` çağrısında anlamlı.

### 5. Bağımlılık ve graceful degradation

`jq` **opsiyonel kalır** (mevcut ilke). `audit`'in izin satırlarındaki desen birebir tekrarlanır:
- `jq` varsa → `claude plugin list --json` / `marketplace list --json` tam parse edilir
- `jq` yoksa → Claude'a özel satırlar `—` (NA) basar, sebebi yazılır; manifest + kopya kontrolleri
  yine tam çalışır (bunlar grep tabanlı, dep'siz)
- `claude` CLI yoksa (Cursor/klon kurulumu) → Claude satırları `—` basar; git-klon kontrolleri çalışır

Yani hiçbir ortamda çökmez, sadece görebildiği kadarını raporlar.

### 6. Sürüm etkisi

**`VIBE_VERSION` bump YOK.** `doctor` yeni bir komut; hiçbir managed template değişmiyor. VIB-14'teki
audit-satırı eklemesiyle aynı sınıf. Paket sürümü (`plugin.json`) bir sonraki release'te artar.

### 7. Dokümantasyon

- `README.md` Kurulum bölümüne: sorun yaşayan için tek satır — `bash …/scaffold.sh doctor`
- `CLAUDE.md` Komutlar bölümüne `doctor` satırı
- `SKILL.md` Faz 1'e sinyal-kontrolü akışı

## Kapsam dışı (bilinçli)

- **Otomatik güncelleme.** Sinyal + soru; sormadan `claude plugin update` çalıştırmak yok (repo'nun
  "önce onay" ilkesi + kullanıcının Claude kurulumuna dokunmak açık onay ister).
- **`audit`'e gömmek.** Ayrı komut kalır; `audit` hedef repo hakkındadır, karıştırılmaz.
- **Kurulum onarımı (`doctor --fix`).** Teşhis + yapıştırılabilir komut yeterli; otomatik onarım
  ayrı ve daha riskli bir karar.
- **Cursor/Gemini/Aider kurulum durumunun denetlenmesi.** Bu araçların merkezî bir kurulum kaydı yok;
  git-klon kontrolleri onları zaten kapsıyor.
- **`vibe-update.sh` ile birleştirmek.** O bir *eylem* (güncelle), doctor bir *teşhis*. Ayrı kalırlar;
  doctor gerektiğinde `vibe-update.sh`'ı öneren satır basar.
