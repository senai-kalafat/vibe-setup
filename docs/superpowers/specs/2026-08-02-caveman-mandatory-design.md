# caveman'i zorunlu bağımlılık yap (context-mode kalıbı)

Tarih: 2026-08-02
Durum: tasarım onaylandı, plan bekliyor

## Amaç

`vibe-setup` skill'i, kurduğu her repoda **caveman**'i (çıktı-sıkıştırma modu, ~%75 output token
tasarrufu) otomatik kursun ve **her session'da aktif olmasını zorlasın** — tıpkı context-mode gibi,
sorulmadan, opsiyonel değil.

Bugün caveman repoda hiç geçmiyor; kullanıcının kendi Claude kurulumunda plugin olarak yüklü. Bu
tasarım onu vibe-setup'ın ürettiği kuruluma taşır.

## Kapsam kararları

| Karar | Seçim | Gerekçe |
|---|---|---|
| Kurulum yolu | `install.sh` — makinedeki **tüm** agent'ları auto-detect | 34 agent tek komutta; her biri için native yol |
| Zorlama (hook'suz agent'lar) | `--with-init` rule dosyaları **+** CLAUDE.md/AGENTS.md kuralı | rule-file destekleyende always-on, gerisinde context dosyası prose'u |
| Varsayılan seviye | `full` | caveman'in kendi varsayılanı; teknik doğruluk %100 korunur |
| AGENTS.md çakışması | caveman satırı **template'e alınır** (`VIBE_VERSION` 7→8) | drift kaynağında yok edilir; upgrade temiz kalır |

## Mimari sınıflandırma

caveman, context-mode ile **aynı sınıfa** girer:

- `scaffold.sh`'ın `managed_paths`'ine **girmez** — caveman'in kendi installer'ı yazar, vibe-setup değil.
- drift/upgrade takibi yok, `audit` satırı yok.
- `vibe-remove` caveman'i **silmez**; kapanışta `caveman uninstall` yolu bildirilir.

Tek istisna: AGENTS.md'ye düşen aktivasyon satırı — o vibe-setup'ın **synced managed** template'inin
parçası olur (aşağıda).

## Değişiklikler

### 1. `SKILL.md` — Faz 3 (Agnostik iskeletler)

context-mode bloğunun **hemen ardına** yeni madde:
`caveman kurulumu (HER ZAMAN, sorulmadan — zorunlu bağımlılık)`

Adımlar:

1. `curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash -s -- --dry-run --with-init`
   çalıştır, çıktıyı kullanıcıya göster (hangi agent'lar tespit edildi, hangi dosyalar yazılacak).
2. Onay sonrası aynı komutu `--dry-run` olmadan çalıştır.
3. **Repo dışına yazılan yolları açıkça raporla** (`~/.claude`, `~/.config/opencode`, `~/.gemini`,
   `~/.openclaw/workspace` …). Bu, Antigravity `mcp_config.json` kuralının aynısı: kullanıcının home
   dizini vibe-setup'ın normal kapsamı değil, sessizce yapılmaz.
4. `--with-init`'in repoya düşürdüklerini NEW olarak listele:
   `.cursor/rules/caveman.mdc`, `.windsurf/rules/caveman.md`, `.clinerules/caveman.md`,
   `.github/copilot-instructions.md`, `.opencode/AGENTS.md`.
5. Kullanıcı `install.sh`'ı reddederse: pipe-to-shell yerine indir-oku-çalıştır alternatifini sun
   (`curl -o install.sh` → incele → `bash install.sh --with-init`). Reddederse adımı atla ve
   kullanıcı-aksiyon tablosuna satır ekle.

Not: `install.sh` idempotent, tekrar çalıştırmak güvenli (upgrade akışında da çalıştırılabilir).

### 2. `scaffold.sh` — AGENTS.md template + sürüm

Repo gotcha'sındaki **üç yer** kuralı işletilir:

| Yer | Değişiklik |
|---|---|
| `VIBE_VERSION` | `7` → `8` |
| `artifact_changed_in` | `AGENTS.md)` → `echo 8` (yorum: v8 caveman aktivasyon satırı) |
| `render_artifact` `AGENTS.md)` | template'e caveman satırı eklenir |

Template'e eklenen satır (mevcut madde listesinin altına):

```
- **Çıktı modu:** bu repoda caveman modu (seviye `full`) zorunludur — aktif değilse `/caveman full`
  çalıştır. Kod, commit mesajı ve PR metni normal yazılır.
```

`artifact_class` değişmez — AGENTS.md zaten `synced`.

Migration gerekmez: dosya-template değişimi `upgrade`'in UPDATE yolu tarafından zaten taşınır
(dokunulmamışsa), elle düzenlenmişse CONFLICT'e düşer ve LLM merge eder. `run_migrations`'a
dokunulmaz.

### 3. `SKILL.md` — Faz 4 (Stack-bağımlı içerik)

CLAUDE.md üretimine iki ek:

- **Kural:** caveman seviyesi `full`, aktif değilse `/caveman full`. Kod/commit/PR normal yazılır.
  Hook'suz ~30 agent (Codex, Warp, Kilo, Roo, Goose, Devin …) yalnızca bu satırı görür — zorlamanın
  tek dayanağı orada.
- **Gotcha:** subagent/alt-görev dispatch eden bir akış varsa, **her dispatch prompt'una caveman
  talimatı açıkça eklenmeli** — subagent taze context alır, parent session'ın caveman kuralını miras
  almaz. (context-mode için zaten yazılan gotcha'nın aynısı; ikisi tek maddede birleştirilir.)

### 4. `SKILL.md` — Faz 6 (kullanıcı-aksiyon tablosu)

- `install.sh` reddedildiyse veya bir agent tespit edilemediyse satır ekle: paste-hazır tek-agent
  komutu (`npx skills add JuliusBrussee/caveman -a <id>`).
- Auto-activate **etmeyen** agent'lar için not: rule dosyası düşmediyse session başına `/caveman full`.

### 5. `SKILL.md` — Remove akışı

Kapanışa satır: caveman vibe-remove kapsamında değil. Kaldırma yolu:

```bash
npx -y github:JuliusBrussee/caveman -- --uninstall   # hook'lar, plugin, extension, opencode plugin
npx skills remove caveman                            # `npx skills add` ile kurulanlar (ayrı CLI)
```

Bu iki komut da `--with-init`'in düşürdüğü **repo-içi rule dosyalarını silmez**
(`.cursor/rules/`, `.windsurf/rules/`, `.clinerules/`, `.github/copilot-instructions.md`,
`.opencode/AGENTS.md`) — elle silinir. `AGENTS.md`'deki satır zaten vibe-setup template'inin parçası,
`vibe-remove` onu kendi managed dosyası olarak zaten ele alır.

### 6. Repo `CLAUDE.md` (bu repo, dogfood)

Gotchas'a caveman maddesi — context-mode maddesinin kardeşi: zorunlu bağımlılık, `install.sh
--with-init`, seviye `full`, subagent dispatch'e açık talimat gerekliliği.

### 7. `docs/`

`docs/architecture/decisions/` altına ADR: "caveman zorunlu bağımlılık" — neden opsiyonel değil
(token maliyeti tek seferlik kurulumla kalıcı düşer), ne pahasına (paylaşılan repoda çıktı stili
herkese dayatılır).

## Test

`tests/run.sh` bağımsız ve dış dep istemez; `install.sh` çalıştıran bir test **yazılmaz** (ağ + global
kurulum). Test edilen:

1. `scaffold.sh init` sonrası `AGENTS.md` caveman satırını içeriyor.
2. `AGENTS.md` stamp'i `vibe-setup:v8`.
3. `scaffold.sh profile` çıktısı `VIBE_VERSION=8`.
4. v7 stamp'li dokunulmamış `AGENTS.md` üzerinde `upgrade` → UPDATE (CONFLICT değil).
5. Elle düzenlenmiş `AGENTS.md` üzerinde `upgrade` → CONFLICT (ezmez).

## Riskler

| Risk | Değerlendirme |
|---|---|
| Pipe-to-shell | `--dry-run` önce gösterilir; indir-oku-çalıştır alternatifi sunulur. Installer hook dosyalarını pinlenmiş release tag'inden çeker ve commit'li SHA-256 manifest'e karşı doğrular. |
| Home dizinine yazma | Antigravity precedent'i var; kural: açıkça raporla, sessizce yapma. |
| Stil dayatması | Paylaşılan repoda çıktı stili herkesi etkiler. Bilinçli karar; ADR'de gerekçelendirilir. Kullanıcı `/caveman lite` veya "stop caveman" ile kendi session'ında geçebilir. |
| Üçüncü-parti bağımlılık | caveman harici bir GitHub projesi. `install.sh` başarısız olursa Faz 3 durmaz — uyarı basar, kullanıcı-aksiyon tablosuna satır ekler. |

## Kapsam dışı

- `install.sh`'ın kendi davranışını değiştirmek (upstream proje).
- caveman'i `managed_paths`'e almak / `audit` satırı eklemek.
- `vibe-remove`'a caveman temizliği eklemek.
- Plugin semver bump'ı (`plugin.json`) — bu ayrı bir release kararı, `VIBE_VERSION` ile karıştırılmaz.
