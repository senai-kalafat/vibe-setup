# vibe-setup: `remove` komutunu SKILL.md'ye kabla — design

Date: 2026-07-24
Status: approved

## Problem

`scaffold.sh remove [DIR] [--apply]` tamamen inşa edilmiş, test edilmiş ve doğrulanmış (bkz
`docs/superpowers/specs/2026-07-24-vibe-remove-design.md` + o planın implementasyonu, main'e merge
edildi). Ama `skills/vibe-setup/SKILL.md` bu komuttan hiç bahsetmiyor — ne frontmatter
`description`'da bir tetikleyici var, ne de akışta bir adım. Kullanıcı "vibe-setup'ı kaldır" dese
bile skill bunu tetikleyecek bir eşleşme bulamaz; komut fiilen ölü kod olarak kalıyor.

Bu, `remove` implementasyon planında bilinçli olarak kapsam dışı bırakılmıştı (final review'da
reviewer flag'ledi, kullanıcı "şimdilik böyle bırak" dedi) — şimdi ayrı bir iş olarak ele alınıyor.

## Kapsam

Sadece `skills/vibe-setup/SKILL.md` — orkestrasyon/prose katmanı. `scaffold.sh`'ta kod değişikliği
yok (motor zaten tam ve doğru).

## Değişiklikler

### 1. Frontmatter `description`

Yeni tetikleyici ifadeler eklenir: "vibe-setup'ı kaldır", "remove vibe-setup", "vibe-remove",
"vibe-setup'ı geri al". Kaldırma **sadece açık kullanıcı isteğiyle** tetiklenir — audit/init
akışının hiçbir noktasında proaktif önerilmez (silme her zaman kullanıcı-başlatımlı).

### 2. Yeni `## Remove akışı (vibe-setup'ı kaldır)` bölümü

`## Upgrade akışı` ile aynı seviyede, ondan hemen sonra, `## İlkeler`den önce yerleşir (init akışına
gömülmez — farklı kullanıcı niyeti, tıpkı upgrade'in ayrı bölüm olması gibi).

Adımlar:

1. **Her zaman önce dry-run:** `bash "$SKILL_DIR/scaffold.sh" remove .` (apply'sız).
   - Çıktıda "Manifest yok" mesajı varsa: kullanıcıya "bu repoda vibe-setup kurulu değil (ya da zaten
     kaldırılmış)" de, akışı burada bitir.
2. **Dry-run çıktısını olduğu gibi göster** — SİLİNECEK / ELLE DÜZENLENMİŞ / ÖNCEDEN VARDI / KAPSAM
   DIŞI blokları zaten insan-okur; yeniden formatlama yok.
   - **Kısayol:** SİLİNECEK **ve** ELLE DÜZENLENMİŞ ikisi de `(yok)` ise, onay adımını atla —
     doğrudan "kaldırılacak bir şey yok" de ve bitir (silinecek hiçbir şey yoksa onay istemek gürültü).
3. **Açık onay iste:** "Listelenen dosyaları sileyim mi?" — kullanıcı hayır derse dur, hiçbir şey
   olmaz (dry-run zaten hiçbir şey silmedi).
4. **Evet ise uygula:** `bash "$SKILL_DIR/scaffold.sh" remove . --apply`.
5. **`vibe-remove-report.md`'yi oku** (repo kökü, `--apply` bunu yazdı). Raporun git-config-unset
   önerisindeki üç komuttan (`core.hooksPath`, `commit.template`, `vibe.ticketre`) **gerçekten set
   edilmiş olanları** belirle (`git config --get <key>` ile kontrol et — rapor üçünü de koşulsuz
   listeler, ama scaffold.sh bunların hangisinin gerçekten set edildiğini bilmez, bunu bilen skill
   katmanıdır). Sadece gerçekten set olanlar için kullanıcıya sor: "Bu ayarları da kaldırayım mı?"
   Evet ise ilgili `git config --unset <key>` komutlarını çalıştır (sadece onaylananları — hepsini
   birden değil).
6. **Kapsam dışı hatırlatmayı aktar:** CLAUDE.md, docs/, tests/, .claude/settings.json içeriği elle
   gözden geçirilmeli — bunlara hiç dokunulmadı, dokunulmayacak.
7. **Kapanış:** rapor dosyasının (`vibe-remove-report.md`) repo kökünde kalıcı kayıt olarak durduğunu
   söyle — silinmez, bu kaldırma işleminin tek receipt'i.

### Edge case'ler

- Manifest yok → adım 1'de bitir (yukarıda).
- SİLİNECEK + ELLE DÜZENLENMİŞ ikisi de boş → adım 2'nin kısayolunda bitir.
- ELLE DÜZENLENMİŞ dolu ama SİLİNECEK boş → normal onay akışı devam eder (yine de --apply çalıştırılır,
  sadece hiçbir şey silinmeyebilir ama git config/rapor adımları hâlâ anlamlı).

## Kapsam dışı (bilinçli)

- `scaffold.sh` kodunda değişiklik yok.
- `remove()`'un path kaynağı (manifest key'leri vs. canlı `managed_paths()`/`extra_paths()`) — ayrı,
  daha önce kullanıcı onayıyla backlog'a bırakılmış bir bulgu, bu işin kapsamında değil.
- Otomatik/proaktif kaldırma önerisi yok — her zaman kullanıcı "kaldır" demeli.
