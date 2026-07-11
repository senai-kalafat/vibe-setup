# Legacy Proje Runbook

> SADECE büyük/legacy bir repoda (kod var, agent altyapısı yok, muhtemelen test/doküman yok, README bayat)
> vibe-setup uygularken oku. Yeni/boş projede gerek yok — SKILL.md akışı yeterli.

## 0. Hazırlık
- Yeni branch (`chore/agent-readiness`). Asıl dala dokunma.
- Mevcut build/test'i bir kez çalıştır → baseline. Zaten kırıksa not et (sonra karışmasın).
- Kök dosyaları + klasör ağacı + manifest yerini tara.

## 1. Audit
- `scaffold.sh audit .` → ✅/❌ tablosu + stack + MODULE_DIR. Legacy'de çoğu ❌ normal; sıra önemli.

## 2. Stack + module doğrula
- `scaffold.sh profile .` → komutlar doğru mu, MODULE_DIR (nested/monorepo) doğru mu.
- `unknown`/çok-modül → fmt/lint/test/build'i elle teyit et.

## 3. Agnostik iskelet (risksiz)
- `scaffold.sh init .` — var olanı ezmez, sadece boş çatı.

## 4. CLAUDE.md — EN KRİTİK (koddan çıkar, bayat README'ye güvenme)
- Komutlar (profil + gerçekten çalışan), modül kökü/çalıştırma kuralı.
- Mimari özet: katmanlar, giriş noktaları, veri akışı — kodu gezerek.
- **Gotchas (altın):** tribal knowledge — "dokunma", "bu env'de farklı", "bu sıra önemli", "sessizce patlar".
  Eski geliştiricilere sor + git log/issue'lardan çıkar. Legacy'nin en pahalı, en kırılgan bilgisi.
- İşaretçi tarzı: detay docs'a, CLAUDE.md ince.

## 5. docs/ + ilk ADR'lar
- overview.md: mevcut yapıyı **olduğu gibi** belgele (ideal değil, gerçek).
- Geçmiş kararları 2-3 ADR'la dondur ("neden bu DB/pattern") → agent tekrar tartışmasın.
- Domain sözlüğü: projeye özgü jargon.

## 6. Test harness — ilk yeşil test
- Baseline yeşil değilse önce derlenir hale getir (ayrı iş).
- Saf/deterministik bir fonksiyon bul → dile uygun **gerçek geçen** test. Amaç doğrulama döngüsü, %100 kapsam değil.
- Çalıştır, gör. CLAUDE.md'ye "tek test nasıl çalıştırılır" ekle.

## 7. Git hook — legacy tuzağı
- **fmt baseline kirli** (legacy'de kesin gibi): tüm repoyu tek commit'te formatlama → devasa diff. Ya fmt'i
  **advisory** bırak, ya ayrı "format the world" commit'i at sonra blocking yap.
- **lint/vet eski uyarı doluysa** → advisory; temizleyince blocking.
- doc-sync = blocking. `git config core.hooksPath .githooks`. Bypass: `SKIP_DOCS=1` / `--no-verify`.

## 8. settings.json
- **allow:** test/build/fmt + salt-okunur git. Mutasyon (`git add/commit`) hariç.
- **deny (legacy'de bol):** `dist/`, `build/`, `vendor/`, minified bundle, generated swagger/proto. `Read(<path>)` ile engelle → bağlam patlamasın.

## 9. llms.txt + AGENTS.md
- İskelet `<TODO>`'ları gerçek kod haritası + conventions ile değiştir.

## 10. (Ops.) Plugin/MCP paylaşımı
- Ortak bağlam aracı varsa `enabledPlugins`. Harici repo → açık onay (classifier bloklarsa elle ekletecek snippet ver).

## 11. Checklist + DOĞRULA
- `vibe-checklist.md` doldur (dosya referanslı). Her şeyi çalıştırarak doğrula (test/fmt/build/hook/JSON). Çalıştırmadan "tamam" deme.

## 12. Ekip devri
- README/CLAUDE'a: `git config core.hooksPath .githooks && git config commit.template .gitmessage`. Tek MR, baştan commit conventions.

---

## Legacy altın kurallar
- **Boil the ocean yapma.** Öncelik: CLAUDE.md (gotchas) → ilk test → hook. Gerisi artımlı.
- **Koda güven, README/yoruma güvenme.**
- **fmt/lint'i tek seferde dayatma** — advisory başla, temizleyince blocking.
- **Gotchas'ı insanlardan topla** — koddan çıkmayan bilgi en değerli.
- **İdempotent + küçük commit'ler** — her adım geri alınabilir.
