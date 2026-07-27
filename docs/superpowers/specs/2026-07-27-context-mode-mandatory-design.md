# vibe-setup: context-mode'u zorunlu bağımlılık yap — design

Date: 2026-07-27
Status: approved

## Problem

`skills/vibe-setup/SKILL.md` bugün context-mode gibi "evrensel kişisel araçları" bilinçli olarak
repo dışı tutuyor:

> **Evrensel kişisel araçları repoya GÖMME** (context-mode, context7 vb. — context penceresi/doküman
> yardımcıları). Projeden bağımsız faydalılar → `~/.claude/settings.json` (user-global) öner;
> repo-pin'lersen global'i olanda mükerrer, olmayana dayatma + marketplace erişimi şartı olur.

Kullanıcı bu kararı bilinçli olarak tersine çeviriyor: context-mode artık vibe-setup'ın kurduğu her
repoda **zorunlu** bir bağımlılık olacak — sorulmadan kurulacak, ilkeler'den ilgili istisna-dışı-tutma
maddesi tamamen kaldırılacak.

## Araştırma bulguları

context-mode (`~/.claude/plugins/marketplaces/context-mode/`), 17 istemci platformunu destekleyen
gerçek çok-araçlı bir MCP sunucusu + hook paketi. Dağıtım katmanları:

- **Evrensel önkoşul:** `npm install -g context-mode` — binary'yi PATH'e koyar (`context-mode` komutu).
  Bu adım hiçbir aracı gerektirmez, güvenli, makine-geneli tek seferlik kurulum.
- **Claude Code:** `.claude/settings.json`'da `extraKnownMarketplaces` + `enabledPlugins` —
  **repo-tracked**, vibe-setup'ın Faz 4 "Plugin/MCP paylaşımı" bölümünde zaten var olan mekanizma.
- **Cursor:** `.cursor/mcp.json` (`{"command":"npx","args":["-y","context-mode"]}`) —
  **repo-tracked** olabilir (proje-seviyesi `.cursor/mcp.json` context-mode'un kendi
  `.cursor-plugin/plugin.json`'ında da kullanılan resmi format).
- **Antigravity (CLI `agy` + IDE):** `~/.gemini/config/mcp_config.json` (agy) ya da
  `~/.gemini/antigravity/mcp_config.json` (IDE) — **sadece kullanıcı-global**, repo-seviyesi
  eşdeğeri dokümante edilmemiş.
- **Codex CLI, Gemini CLI (Antigravity dışı), Kimi Code:** kendi kullanıcı-global config dosyaları
  (`~/.codex/config.toml`, `~/.kimi-code/mcp.json` vb.) — bu işin kapsamında zorunlu değil.

Üç dosyanın (`.claude/settings.json`, `.cursor/mcp.json`, Antigravity'nin global config'i) hepsi
**JSON merge** gerektiriyor (var olan içeriğe key ekleme, dosyayı topyekûn yazma değil). Bu,
vibe-setup'ın "akıllı (LLM)" katmanının işi — LLM kendi Read/Edit aracıyla merge eder; `scaffold.sh`'a
(saf bash, `jq` opsiyonel) yeni JSON-merge kodu eklemeye gerek yok. Sadece deterministik bir
**varlık kontrolü** (`have context-mode`) `scaffold.sh`'a eklenir.

## Kapsam kararları

1. **`npm install -g context-mode`** — her vibe-setup çalıştırmasında (artık soru yok, doğrudan
   çalıştırılır, çıktı kullanıcıya gösterilir).
2. **Claude Code — zorunlu, repo-tracked.**
3. **Cursor — zorunlu, repo-tracked, SADECE Cursor Faz 2'de seçildiyse** (yani `init-cursor`
   çalıştırıldıysa) — Cursor seçilmemiş bir repoda `.cursor/mcp.json` düşürmenin anlamı yok.
4. **Antigravity — zorunlu, kullanıcı-global dosya düzenlenir.** Bu, vibe-setup'ın normalde
   yapmadığı bir şey (repo dışına, makineye yazmak) ama kullanıcı bunu açıkça istedi; LLM her
   çalıştırmada bu adımı şeffaf şekilde gösterir (ne düzenlediğini söyler), sessizce yapmaz.
5. **Codex CLI, Gemini CLI (Antigravity dışı), Kimi Code — zorunlu DEĞİL.** Faz 6'nın mevcut
   "paste-hazır snippet" desenine (classifier-bloklanan satırlar için zaten kullanılan) tam
   MCP config örneği eklenir; kullanıcı isterse elle ekler.
6. **`scaffold.sh audit`'e yeni satır:** `have context-mode` → ✅/❌, eksikse "npm install -g
   context-mode" aksiyon mesajı. SCORE'a dahil (gerçek zorunluluk, `—` değil `❌`).
7. **SKILL.md'nin "Evrensel kişisel araçları repoya GÖMME" ilkesi tamamen silinir** — artık böyle
   bir ayrım yok; context-mode özel olarak zorunlu bir istisna değil, kural kalkıyor.

## Akış değişikliği (SKILL.md)

Faz 2/3/4 arası bir yere context-mode kurulumu eklenir — Faz 2'nin "hedef araç sorusu"ndan HEMEN
SONRA (hangi araçların seçildiği artık bilindiği için Cursor/Antigravity dahil mi karar verilmiş
olur), Faz 3'ten önce ya da Faz 3'ün bir parçası olarak:

1. `npm install -g context-mode` çalıştır, çıktıyı göster.
2. `.claude/settings.json`'ı oku, `extraKnownMarketplaces` (context-mode marketplace) +
   `enabledPlugins` (context-mode plugin) ekle — var olan içerikle merge et, ezme.
3. Kullanıcı Cursor seçtiyse: `.cursor/mcp.json`'ı oku (yoksa oluştur), context-mode MCP server
   girdisini ekle — var olan sunucuları koru.
4. Antigravity için: `~/.gemini/config/mcp_config.json`'ı oku (yoksa oluştur), context-mode MCP
   server girdisini ekle — kullanıcıya HANGİ dosyayı düzenlediğini açıkça söyle.
5. Faz 6'nın kullanıcı-aksiyon tablosuna, Codex/Gemini CLI (Antigravity dışı)/Kimi Code için
   paste-hazır MCP config snippet'i ekle (opsiyonel, kullanıcı kararına bırakılır).

## Kapsam dışı (bilinçli)

- Codex/Gemini CLI (Antigravity dışı)/Kimi Code'un otomatik/zorunlu kurulumu — sadece snippet.
- `scaffold.sh`'a JSON-merge kodu eklemek — bu iş LLM katmanında kalır.
- context-mode'un kendi hook/routing sisteminin (PreToolUse/PostToolUse vb.) detaylı yapılandırması
  — sadece MCP server kaydı (temel erişim) kapsamda; context-mode kendi `doctor`/`upgrade`
  komutlarıyla ince ayarını kendi yapar, vibe-setup bunu tetiklemez.
