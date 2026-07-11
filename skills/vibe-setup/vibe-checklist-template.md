# Vibe Coding Hazırlık Kontrol Listesi — Şablon

> AI/agent destekli geliştirme için repo hazırlık baz listesi. Yeni projeye kopyala, `vibe-checklist.md`
> olarak doldur. `[x]` = var, `[ ]` = eksik. Her satıra dosya/kanıt notu ekle.

## BAĞLAM
- [ ] CLAUDE.md — yalın, emir kipli, docs'a **işaret eder** (içerik dökmez)
- [ ] Root README — hızlı başlangıç + linkler
- [ ] AGENTS.md — CLAUDE.md'ye ayna (çapraz araç); gerekirse GEMINI.md
- [ ] (ops) Cursor uyumu — `.cursor/rules/*.mdc` + `.cursorrules` → CLAUDE.md'ye yönlendirir
- [ ] (ops) llms.txt — araç-bağımsız ince repo haritası (llmstxt.org); sadece dış LLM tüketicisi varsa
- [ ] "Gotchas" — koddan çıkarılması zor tuzaklar yazılı
- [ ] Kod seviyesinde nested README (sık dokunulan paketlerde patern örneği)

## BİLGİ TABANI
- [ ] İndeksli docs/ (giriş noktası, ör. docs/README.md)
- [ ] Mimari genel bakış + akış diyagramları (mermaid)
- [ ] ADR'lar (NEDEN) + 0000-template
- [ ] Domain sözlüğü (proje jargonu)
- [ ] Kurulum + operasyon rehberleri

## YAPI
- [ ] Modül/çalıştırma-kökü kuralı açıkça yazılı
- [ ] Katman sınırları belgeli
- [ ] "<şey> nasıl eklenir" ritüelleri yazılı (+ mümkünse slash komut ile otomatik)
- [ ] Kod test edilebilir (context/framework'e bağlı katman da mock'suz/helper ile test edilebiliyor)
- [ ] Statik analiz borcu temiz (vet/lint repo-temiz → kapı blocking yapılabilir)

## TOKEN OPTİMİZASYONU
- [ ] CLAUDE.md işaretçi tarzı (derin docs tembel yüklenir)
- [ ] Büyük/üretilmiş varlıklar "okuma" diye işaretli + `permissions.deny` ile sert engel
- [ ] Projeye-özgü MCP (varsa) repoya sabit (DB/iç-doküman/Jira); evrensel kişisel araç (context-mode vb.) user-global, repoya gömülmez
- [ ] İzin allowlist → daha az onay (mutasyon yapanlar hariç)

## DOĞRULAMA  ← çoğu proje burada çuvallar
- [ ] Test suite var (agent kendi kendini doğrulama döngüsü), en az pure fonksiyonlar
- [ ] Lint/format komutu belgeli **ve** hook ile zorlanıyor (fmt blocking/advisory, lint advisory)
- [ ] Tek-test-nasıl-çalıştırılır belgeli

## EKLENTİLER / HOOK'LAR
- [ ] Git hook (core.hooksPath) AI için DEĞİL **herkes** için zorlar: fmt + lint + doc-sync
- [ ] Doc-sync veya kalite hook'u, repoda **tracked**
- [ ] fmt scope edilemeyen stack'lerde (java/rust/dotnet) advisory; asıl enforcement CI'da
- [ ] doc-sync default advisory; bilerek istenirse `STRICT_DOCS=1` ile blocking
- [ ] Plugin/skill paylaşım kararı verilmiş (projeye sabit ya da bilerek user-only)
- [ ] settings.json tracked, settings.local.json gitignore

## İŞ AKIŞI
- [ ] Branch/commit/PR konvansiyonları CLAUDE.md'de
- [ ] PR/MR + commit-mesajı şablonları
- [ ] Commit konu formatı zorlanıyor (commit-msg hook: `ABC-1234` — 3 harf + '-' + ≤4 hane)

---

### Skorlama (opsiyonel)
Her kategoriyi 0-10 puanla. Düşük puan = öncelik. Kritik satırlar genelde aynı yerde çuvallar:
**test harness** ve **herkesi bağlayan git hook**.

| Kategori | Skor |
|---|---|
| Bağlam | /10 |
| Bilgi tabanı | /10 |
| Yapı | /10 |
| Token optimizasyonu | /10 |
| Doğrulama | /10 |
| Eklenti / hook | /10 |
| İş akışı | /10 |
