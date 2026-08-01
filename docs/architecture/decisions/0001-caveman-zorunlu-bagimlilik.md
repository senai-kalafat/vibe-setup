# 1. caveman zorunlu bağımlılık

- Status: accepted
- Date: 2026-08-02

## Context

vibe-setup kurduğu repolarda agent çıktısının token maliyeti kalıcı bir gider. caveman
(github.com/JuliusBrussee/caveman) çıktıyı ~%75 sıkıştırır, teknik doğruluğu (kod, komut, hata
string'i, terimler) aynen korur. Tek seferlik kurulumla kalıcı kazanç sağlar; context-mode'un
(girdi/context tarafı) tamamlayıcısıdır.

Alternatif: opsiyonel bırakıp kullanıcı-aksiyon tablosunda önermek. Pratikte opsiyonel satırlar
uygulanmıyor — context-mode'da da aynı sebeple zorunluya geçildi.

## Decision

caveman zorunlu bağımlılık. SKILL.md Faz 3 her kurulumda `install.sh --with-init` çalıştırır
(dry-run önce gösterilir, repo dışına yazılan yollar açıkça raporlanır). Varsayılan seviye `full`.
Hook'suz agent'lar için zorlama `AGENTS.md` (managed template, v8) + CLAUDE.md prose'u ile sağlanır.

caveman `managed_paths`'e girmez, `vibe-remove` kapsamına alınmaz — context-mode ile aynı sınıf.

## Consequences

**Artı:** çıktı token maliyeti kalıcı düşer; 34 agent tek komutta kapsanır; rule-file destekleyen
agent'larda gerçekten always-on.

**Eksi:** paylaşılan repoda çıktı stili tüm ekibe dayatılır — bilinçli takas. Kullanıcı kendi
session'ında `/caveman lite` veya "stop caveman" ile geçebilir. Ayrıca üçüncü-parti bir GitHub
projesine bağımlılık doğar; kurulum başarısız olursa Faz 3 durmaz, uyarı basıp devam eder.

**Sürüm etkisi:** `AGENTS.md` template'i değiştiği için `VIBE_VERSION` 7→8. Kurulu repolar
`scaffold.sh upgrade` ile satırı alır (dokunulmamışsa UPDATE, elle düzenlenmişse CONFLICT → LLM merge).
