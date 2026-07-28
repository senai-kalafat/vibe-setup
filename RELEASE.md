# Release süreci

vibe-setup'ın paket versiyonu (`.claude-plugin/plugin.json` / `marketplace.json` /
`.cursor-plugin/plugin.json`'daki `"version"`) elle, aşağıdaki adımlarla çıkarılır. Bu,
`scaffold.sh`'ın kendi `VIBE_VERSION`'ından (hedef repolara üretilen dosya şemasının sürümü)
TAMAMEN AYRI bir kavramdır — bkz `CLAUDE.md` Gotchas.

## Adımlar

1. **Bump tipine karar ver** — semver kuralı:
   - `patch`: geriye uyumlu bug fix / küçük dokümantasyon düzeltmesi.
   - `minor`: geriye uyumlu yeni özellik (ör. yeni bir `scaffold.sh` komutu).
   - `major`: geriye uyumsuz değişiklik (ör. mevcut bir komutun davranışı/argümanları değişti).

2. **Sürümü hesapla + yay:**
   ```bash
   bash scripts/release.sh <major|minor|patch>
   ```
   Argüman vermezsen interaktif sorar. Bu, `.claude-plugin/plugin.json`'ı günceller ve
   `scripts/version-sync.sh` ile `marketplace.json` + `.cursor-plugin/plugin.json`'a yayar.
   **Commit ya da tag atmaz** — sıradaki adımlar senin elinde.

3. **Değişikliği gözden geçir:**
   ```bash
   git diff .claude-plugin/ .cursor-plugin/
   ```

4. **Commit at** (bu repo `VIB-N` ticket-key formatı zorunlu kılıyor — `.githooks/commit-msg`):
   ```bash
   git add .claude-plugin/ .cursor-plugin/
   git commit -m "VIB-N vX.Y.Z sürümü"
   ```

5. **Tag at** (commit'ten SONRA — tag, versiyon-bump commit'ini işaret etmeli):
   ```bash
   git tag vX.Y.Z
   ```

6. **Push et:**
   ```bash
   git push && git push --tags
   ```

## Self-update (tüketici tarafı)

vibe-setup'ın kurulu bir kopyasını (git clone / Claude marketplace cache / Cursor plugin symlink)
en son tag'e güncellemek için:
```bash
bash scripts/vibe-update.sh
```
Bu, **branch-HEAD'e değil git tag'e** göre çalışır — bu repo'nun `main`'i sürekli ara-commit
aldığından (spec/plan/task commit'leri), sadece maintainer'ın açıkça taglediği noktalara güncellenir.
Yerel kopya elle değiştirilmişse (sapmışsa) asla otomatik merge etmez — hata verir, elle çözmeni ister.
