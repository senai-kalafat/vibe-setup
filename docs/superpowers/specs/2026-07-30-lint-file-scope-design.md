# vibe-setup: lint için dosya-scope (`LINT_FILE_OK`) — design

Date: 2026-07-30
Status: approved
Ticket: VIB-16

## Problem

Üretilen `.githooks/pre-commit`'in lint adımı, stack'in `LINT` komutunu **argümansız** çalıştırıyor:

```bash
lint_bin="$(printf '%s' "@LINT@" | awk '{print $1}')"
if [ "@LINT@" != "-" ] && command -v "$lint_bin" >/dev/null 2>&1; then
  lint_out="$(mktemp)"
  @LINT@ >"$lint_out" 2>&1 || true
  ...
```

Çoğu stack'in lint komutu argümansız çalışır (`go vet ./...`, `ruff check .`, `npx eslint .`,
`cargo clippy`, `rubocop`, `swiftlint`, `mix credo`) — ama **shell** profilinin `shellcheck`'i dosya
ister. Sonuç: shellcheck kurulu her shell-stack hedef repoda, her commit'te lint çıktısı olarak
shellcheck'in **usage hatası** basılıyor.

Advisory olduğu için commit'i bloklamıyor (gürültü, korelasyon değil), ama:
- kullanıcıya anlamsız çıktı gösteriyor,
- shell repolarında lint fiilen **hiç çalışmıyor** (gerçek bulgu üretmiyor).

Bulgu, shellcheck bu makineye kurulunca ortaya çıktı — öncesinde `command -v` guard'ı adımı sessizce
atlıyordu, yani hata uzun süredir gizliydi.

## Kök neden

Mimaride fmt'in **dosya-scope kavramı var** (`FMT_FILE_OK`, 9. profil alanı: `1`=staged dosya listesi
geçilebilir → staged-scope blocking; `0`=sadece repo-geneli → advisory), ama **lint'in yok**. Lint her
zaman argümansız/repo-geneli varsayılıyor. Dosya-odaklı bir linter (shellcheck) bu varsayıma uymuyor.

## Kapsam kararları

### 1. `LINT_FILE_OK` — 10. profil alanı (FMT_FILE_OK ile simetrik)

`detect_profile` printf'ine 10. alan eklenir. Anlamı `FMT_FILE_OK` ile birebir aynı sözleşme:
- `1` → lint komutu dosya listesi kabul eder; hook **staged kaynak dosyalarını** geçer.
- `0` → lint komutu sadece bütün-proje çalışır; hook bugünkü gibi argümansız çalıştırır.

### 2. Değer atamaları — sadece `shell=1`, gerisi `0`

| Stack | LINT | LINT_FILE_OK | Gerekçe |
|---|---|---|---|
| shell | `shellcheck` | **1** | Dosya ister — düzeltilen asıl bug |
| go / python / node(eslint) / rust / ruby / swift / elixir | argümansız çalışan komutlar | 0 | Bugünkü davranış korunur |
| php | `phpstan analyse` | 0 | Normalde `phpstan.neon` ile çalışır; `1` yapmak çalışan kurulumları bozar |
| java / kotlin / dotnet / node(biome) | `-` | 0 | Lint yok, alan anlamsız ama şema tutarlılığı için `0` |
| unknown | `-` | 0 | — |

Bilinçli minimum patlama yarıçapı: `shell` dışındaki hiçbir stack'in hook davranışı değişmez.

### 3. Hook mantığı — lint ADVISORY kalır

`LINT_FILE_OK=1` modunda bile lint **bloklamaz**. Mevcut felsefe korunur (`CLAUDE.md` gotcha: "lint
advisory"; fmt blocking, lint/doc-sync advisory). Lint'i blocking yapmak ayrı bir karar, bu spec'in
kapsamı değil.

Staged kaynak dosyası yoksa (ör. sadece `.md` değişmiş) `LINT_FILE_OK=1` modunda lint adımı **tamamen
atlanır** — argümansız çağırıp usage hatası bastırmak yerine.

### 4. `staged_src` tek kaynağa çıkarılır (küçük refactor)

Bugün `staged_src` yalnızca fmt bloğunun `FMT_FILE_OK=1` dalının içinde hesaplanıyor. Lint de aynı
listeye ihtiyaç duyduğundan, hesaplama hook'un başına (`staged` hesabının hemen ardına) taşınır ve iki
blok da onu kullanır. Kopyala-yapıştır yerine tek kaynak — hem fmt hem lint aynı `@SRCRE@` tanımını
paylaşır.

### 5. Sürüm etkisi

Managed template (`render_precommit`) değişiyor → `CLAUDE.md`'nin "Sürüm yükseltirken 3 yer"
gotcha'sı gereği:
- `VIBE_VERSION` 6 → 7
- `artifact_changed_in ".githooks/pre-commit"` 6 → 7
- template'in kendisi

`tests/upgrade_test.sh`'taki hardcoded `6`/`v6` değerleri de güncellenir.

### 6. Dogfood

Bu repo kendi hook'unu `.githooks/pre-commit` + `.vibe-setup.json` ile takip ediyor (VIB-15'te v6'ya
yenilendi). Template değiştiği için kendi hook'u da yeni template'ten yeniden üretilir ve manifest
tazelenir — yoksa VIB-15'te kapatılan "kendi hook'u bayat" boşluğu hemen geri açılır.

Bu, düzeltmenin **kendi üzerinde de doğrulanması** anlamına gelir: bu repo shell-stack, yani hatayı
bizzat yaşayan profil. Düzeltme sonrası kendi commit'lerinde shellcheck usage gürültüsü kalkmalı ve
lint gerçekten staged `.sh` dosyaları üzerinde çalışmalı.

### 7. Dokümantasyon

- `CLAUDE.md`: "`detect_profile` printf = 9 alan" gotcha'sı **10 alan**'a güncellenir, son alan
  `LINT_FILE_OK` olarak tarif edilir (mevcut `FMT_FILE_OK` açıklamasının yanına).
- `skills/vibe-setup/stack-profiles.md`: tabloya `lint-scope` sütunu + "9 alan" notu **10 alan**'a.

## Kapsam dışı (bilinçli)

- Lint'i blocking yapmak — ayrı karar, mevcut advisory felsefesi korunuyor.
- `php`/`phpstan` davranışını değiştirmek — çalışan kurulumları bozma riski, `0` bırakılıyor.
- Lint'in `MODULE_DIR`'e göre scope'lanması — mevcut mimaride lint zaten repo-kökünden çalışıyor,
  bu spec o davranışa dokunmuyor.
- `SC2015`/`SC2094` gibi `info` seviyesi shellcheck bulgularının temizlenmesi — VIB-15'te bilinçli
  olarak kabul edildi (kasıtlı desen), burada da kapsam dışı.
