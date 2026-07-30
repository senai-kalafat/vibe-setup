# vibe-setup: hedef repo README'sinde zorunlu üst-seviye mimari diagramı — design

Date: 2026-07-30
Status: approved
Ticket: VIB-14

## Problem

Hedef repolarda README.md'nin bir mimari diagram taşıması şu an ne mekanik olarak denetlenen ne de
LLM'e açıkça zorunlu bir deliverable olarak yazılmış bir şey. `vibe-checklist-template.md`'nin BİLGİ
TABANI kategorisinde "Mimari genel bakış + akış diyagramları (mermaid)" diye bir madde var ama bu
`docs/` katmanında, checklist-skorlu, audit-görünür değil. `audit()` README.md için sadece varlığını
kontrol ediyor (`has_file`), içeriğini hiç. Sonuç: bir repoya ilk bakan insanın (ya da agent'ın) sistemi
hızlıca kavraması için gereken üst-seviye görsel özet, tutarlı biçimde üretilmiyor.

Bu repo (vibe-setup) kendi kendini dogfood ederken bu boşluğu somut olarak gösteriyor: kendi
`README.md`'sinde hiç diagram yok; `docs/architecture/overview.md`'de bir mermaid akış diagramı var
ama bu "detaylı" katman, "ilk bakışta anla" katmanı değil.

## Kapsam kararları

### 1. Konum: README özet + `docs/architecture/overview.md` detay (mevcut split'in üzerine)

README.md'nin **başına** (giriş/açıklamadan hemen sonra, ilk ana bölümlerden önce) yeni bir kısa bölüm:
tek mermaid diagram (proje = tek kutu, çevresinde dış bağlantılar — DB, harici API'ler, 3rd-party
servisler, kullanıcı/istemci) + 2-3 cümlelik "ne iş yapar" özeti. **Çok detaya girmez** — modül/iç
bileşen kırılımı burada YOK, sadece sistem-sınırı görünümü.

Daha detaylı diagramlar (modül/bileşen düzeyi, veri akışı, sequence) `docs/architecture/overview.md`'ye
gider — bu repo zaten bu deseni dogfood ediyor, `docs/README.md` şablonundaki mevcut
`- [Genel Bakış](architecture/overview.md) <TODO>` stub'ı buna hazır (scaffold.sh bu dosyayı hiç
üretmiyor — LLM Faz 4'te dolduruyor).

### 2. Format: mermaid

Version-controllable, GitHub/GitLab native render eder, bu repo zaten `docs/architecture/overview.md`'de
kullanıyor. Alternatif format değerlendirilmedi — tek kanonik format.

### 3. `audit()` — yeni mekanik kontrol (BAĞLAM kategorisi)

Mevcut README.md satırının hemen altına yeni bir satır (mevcut `test suite` satırının NA/OK/NO
desenini izler):

```bash
has_file README.md   && row "$OK" "README.md" || row "$NO" "README.md" "yok"
if ! has_file README.md; then row "$NA" "README mimari diagramı" "README.md yok"
elif grep -q '```mermaid' README.md; then row "$OK" "README mimari diagramı"
else row "$NO" "README mimari diagramı" "LLM: üst-seviye özet diagram ekle (dış bağlantılar + ne iş yaptığı) — docs/architecture/overview.md'ye detay linki ver"
fi
```

Bu, `SCORE=N/M`'yi etkiler (yeni bir OK/NO satırı) — **varsayılan güçlü sinyal**, `llms.txt` gibi
"(ops)"/NA-varsayılan değil.

### 4. Bilinçli-atlama (kör-zorunlu değil)

Her proje diagram'a uygun olmayabilir (ör. tek-dosyalık script). Audit satırı yine de ❌ basar (mekanik
kontrol proje bağlamını bilmez) — ama SKILL.md akışı, LLM'in bunu **kullanıcıya gerekçelendirip bilinçli
atlamasına** izin verir: Faz 6'nın kullanıcı-aksiyon tablosunda "neden atlandı" notu düşülür. Yani ❌
kalıcı olabilir ama sessizce görmezden gelinmez — insan kararına taşınır.

### 5. `SKILL.md` değişiklikleri

- **Faz 4 (Stack-bağımlı içerik):** yeni açık madde — README özet-diagramı + `docs/architecture/
  overview.md` detay-diagramı **zorunlu deliverable**'lar olarak listelenir (şu an sadece genel "docs
  TODO'larını doldur" satırı var, spesifik bir talimat yok). Diagram içeriği repoyu **okuyarak**
  çıkarılır (gerçek dış bağlantılar — config'te görülen DB/API/servis referansları), uydurulmaz.
- **Faz 6 (kapanış / kullanıcı-aksiyon tablosu):** eğer diagram bilinçli atlandıysa, bunun için bir satır
  + kısa gerekçe eklenir.

### 6. `vibe-checklist-template.md` — mevcut madde ikiye ayrılır

BİLGİ TABANI'ndaki "Mimari genel bakış + akış diyagramları (mermaid)" maddesi:
- BAĞLAM'a taşınan yeni madde: "README — üst-seviye mimari diagram (mermaid, dış bağlantılar + ne iş
  yaptığı; çok detaya girmez)" — yeni audit satırıyla eşleşsin.
- BİLGİ TABANI'nda kalan: "docs/ — detaylı mimari diagramlar (modül/veri akışı)".

### 7. `docs/README.md` şablonu — küçük netleştirme

Mevcut stub satırı:
```markdown
- [Genel Bakış](architecture/overview.md) <TODO>
```
netleştirilir:
```markdown
- [Genel Bakış](architecture/overview.md) <TODO> — detaylı diagramlar burada (README'deki özet
  diagrama ek)
```

## Sürüm etkisi

**`VIBE_VERSION` bump GEREKMİYOR.** README.md `managed_paths()`'te değil — scaffold.sh bu dosyayı hiç
üretmiyor/render etmiyor, sadece audit ediyor. Bu değişiklik context-mode'un audit satırı eklenmesiyle
aynı sınıf: yeni bir audit-check, yeni bir managed-dosya-şeması değil. `docs/README.md` şablonundaki
stub metni değişikliği de ("Genel Bakış" satırı) `seed` sınıfında (`artifact_class` zaten `docs/README.md`'yi
`seed` olarak işaretliyor — bir kez düşer, sonra kullanıcı sahibi) — bu yüzden mevcut kurulu repolarda
`upgrade` bu satırı asla dokunmaz/ezmez; sadece yeni `init` çalıştıran repolar güncel stub'ı görür. Bu
kasıtlı ve tutarlı (seed dosyaların doğası).

## Kapsam dışı (bilinçli)

- Bu deterministik olarak `scaffold.sh`'ın ÜRETMESİ (README.md ya da diagramı otomatik yazması) —
  içerik LLM'in okuyup çıkarması gereken bir şey, mekanik şablonla üretilemez.
- `docs/architecture/overview.md`'nin `scaffold.sh` tarafından managed-path olarak eklenmesi — kapsam
  dışı, mevcut "seed benzeri, LLM doldurur" modeli korunuyor (bu repo da bunu böyle dogfood ediyor).
- Bu reponun (vibe-setup'ın kendisinin) kendi README.md'sine bu diagramın eklenmesi — ayrı, isteğe
  bağlı bir dogfood/ops kararı, bu spec sadece hedef repolara düşen MEKANİZMAYI kapsıyor.
- `docs/architecture/overview.md`'de bulunan bağımsız bir eski `STRICT_DOCS=1` referansı (VIB-13
  sonrası kalmış doküman taşması) — bu spec'in konusu değil, ayrı bir küçük düzeltme.
