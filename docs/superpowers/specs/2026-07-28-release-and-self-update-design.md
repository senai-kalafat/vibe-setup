# vibe-setup: tag-tabanlı release + self-update — design

Date: 2026-07-28
Status: approved

## Problem

vibe-setup'ın kendi kurulu kopyasını (git clone / Claude marketplace cache / Cursor plugin symlink)
GitHub'dan güncelleyecek bir mekanizma yok. Bu, hedef repolardaki scaffold dosyalarını güncelleyen
mevcut `scaffold.sh upgrade`'den TAMAMEN AYRI bir kavram — o `VIBE_VERSION` drift'ine bakar, bu ise
ARACIN KENDİ paket sürümüne (`plugin.json`'daki `"version"`) bakar.

## Neden branch-HEAD değil, tag

Bu repo'nun `main`'i sürekli ara-commit alıyor: spec commit'i, plan commit'i, sonra ayrı task
commit'leri — her commit noktası "tam/bitmiş" değil. Branch-HEAD'e göre bir self-update, kullanıcının
kopyasını bir feature'ın YARISINDA bir commit'e çekebilir. Git **tag**, maintainer'ın açıkça "bu nokta
sağlam, buraya güncelleyin" dediği andır — `VIBE_VERSION`'ın "sadece gerçek değişiklikte artır"
disipliniyle aynı felsefe.

## Kapsam kararları

### 1. `scripts/release.sh [major|minor|patch]`

- Argüman verilmezse `read -p` ile interaktif sorar (major/minor/patch) — hem insan-elle-çalıştırma
  hem agent-otomasyonu (`release.sh minor` gibi) destekler.
- Mevcut versiyonu (`.claude-plugin/plugin.json`'daki `"version"`) parse eder (`IFS='.'` ile
  major/minor/patch), doğru bileşeni artırır, standart semver kuralına göre alt bileşenleri sıfırlar
  (major artınca minor+patch=0; minor artınca patch=0; patch sadece kendini artırır).
- Yeni versiyonu `plugin.json`'a yazar (awk gsub + tmp + mv — `sed -i` yok, mevcut kod tabanı deseni).
- Mevcut `scripts/version-sync.sh`'ı **çağırır** — `marketplace.json` + `.cursor-plugin/plugin.json`'a
  yayılım için (yeni kod tekrarı yok, var olan script'i reuse eder).
- **Commit atmaz, tag atmaz.** Bu bilinçli bir sınır: commit mesajı bu repo'da `VIB-N` ticket-key
  zorunlu (`.githooks/commit-msg`), ticket-key seçimi insan/LLM kararı — script'in kararı değil.
  release.sh sadece dosyaları hazırlar; commit + tag sonraki adımlar (`RELEASE.md`'de belgeli).

### 2. `RELEASE.md` (repo kökü)

Tam release süreci, adım adım:
1. `bash scripts/release.sh <major|minor|patch>` çalıştır.
2. `git diff` ile değişen 3 manifest dosyasını gözden geçir.
3. `git add .claude-plugin/ .cursor-plugin/ && git commit -m "VIB-N vX.Y.Z sürümü"` (uygun ticket-key ile).
4. `git tag vX.Y.Z` (commit'ten SONRA — tag, versiyon-bump commit'ini işaret etmeli).
5. `git push && git push --tags`.

### 3. `scripts/vibe-update.sh`

- Kendi script konumundan repo köküne çıkar (`BASH_SOURCE` ile) — hedef repo değil, vibe-setup'ın
  KENDİ kopyası üzerinde çalışır.
- `.git` yoksa net hata, exit 1 (self-update yapılamaz).
- `git fetch origin --tags`; `git tag --list 'v*' --sort=-version:refname | head -1` ile en son tag'i
  bulur. Hiç tag yoksa net hata, exit 1.
- **Zaten o tag'deyse** → "güncel" mesajı, exit 0.
- **Local, tag'den daha yeniyse** (henüz taglenmemiş local commit'ler var — örn. bir geliştiricinin
  kendi çalışma kopyası) → bilgilendirici mesaj, exit 0, hiçbir şey yapmaz.
- **Local, tag'den SAPMIŞSA** (elle değiştirilmiş) → **asla otomatik merge etmez** — net hata + elle
  çözüm önerisi (`git status`/`git diff`, gerekirse yeniden klonlama). vibe-setup'ın her yerdeki
  "asla ezmez" ilkesiyle birebir.
- **Temiz fast-forward mümkünse** → nelerin geldiğini (`git log --oneline`) gösterir, `git merge
  --ff-only <tag>` yapar.

### 4. `CLAUDE.md` güncellemesi

- "Komutlar" bölümüne iki yeni satır: `release.sh` ve `vibe-update.sh`, `RELEASE.md`'ye pointer.
- Gerekirse mevcut "Paket versiyonu ≠ VIBE_VERSION" gotcha'sına release.sh/vibe-update.sh referansı
  eklenir (aynı ayrımın parçası, tekrar açıklama gerekmez — sadece pointer).

## Kapsam dışı (bilinçli)

- Otomatik commit/tag/push — hepsi insan onayı ister, script'ler sadece hazırlık yapar.
- SKILL.md/audit akışına self-update'i bağlamak (audit sırasında "yeni sürüm var mı" network çağrısı) —
  ayrı, elle-tetiklenen bir maintenance komutu olarak kalır.
- CI/otomatik release pipeline'ı — bu iş sadece manuel script+doküman kuruyor.
