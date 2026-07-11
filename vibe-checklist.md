# Vibe Coding Hazırlık — vibe-setup (dolu)

> Bu repo kendi checklist'ine göre denetlendi (dogfood). `[x]` = var, `[ ]` = eksik/karar bekliyor.
> Audit skoru: **12/14** (`bash skills/vibe-setup/scaffold.sh audit .`).

## BAĞLAM
- [x] CLAUDE.md — işaretçi tarzı, docs'a yönlendirir → [CLAUDE.md](CLAUDE.md)
- [x] Root README — kurulum + kullanım → [README.md](README.md)
- [x] AGENTS.md — CLAUDE.md'ye ayna → [AGENTS.md](AGENTS.md)
- [ ] (ops) Cursor uyumu — `init-cursor` çalıştırılmadı (istenmedi)
- [ ] (ops) llms.txt — iç repo, dış LLM tüketicisi yok → bilerek kurulmadı
- [x] Gotchas — koddan çıkmaz tribal bilgi → [CLAUDE.md](CLAUDE.md) "Gotchas"
- [ ] Nested README — küçük repo, gerek yok

## BİLGİ TABANI
- [x] İndeksli docs/ → [docs/README.md](docs/README.md)
- [ ] Mimari overview + mermaid — [docs/architecture/overview.md](docs/architecture/decisions/) `<TODO>` (özet CLAUDE.md'de var, ayrı dosya/diyagram yok)
- [x] ADR template → [docs/architecture/decisions/0000-template.md](docs/architecture/decisions/0000-template.md) (gerçek ADR henüz yok)
- [ ] Domain sözlüğü — `<TODO>`, jargon az → ertelendi
- [x] Kurulum rehberi → [README.md](README.md) "Kurulum"

## YAPI
- [x] Çalıştırma-kökü kuralı — "repo kökünden" → [CLAUDE.md](CLAUDE.md) "Komutlar"
- [x] Katman sınırları — deterministik/LLM ayrımı → [CLAUDE.md](CLAUDE.md) "Mimari", [SKILL.md](skills/vibe-setup/SKILL.md)
- [x] "Yeni stack nasıl eklenir" ritüeli → [README.md](README.md) "Yeni stack eklemek" + [CLAUDE.md](CLAUDE.md) gotcha
- [x] Kod test edilebilir → [tests/profile_test.sh](tests/profile_test.sh)
- [ ] Statik analiz borcu temiz — shellcheck/shfmt local kurulu değil, repo-temiz teyit edilemedi

## TOKEN OPTİMİZASYONU
- [x] CLAUDE.md işaretçi tarzı → [CLAUDE.md](CLAUDE.md)
- [ ] Büyük/üretilmiş varlık deny — repoda yok → `deny` boş (doğru, N/A)
- [ ] MCP/bağlam aracı sabit — N/A
- [ ] İzin allowlist — **güvenlik sınıflandırıcısı blokladı** (self-modification); snippet kullanıcıya verildi, elle eklenecek → [.claude/settings.json](.claude/settings.json)

## DOĞRULAMA
- [x] Test suite → [tests/run.sh](tests/run.sh) (8/8 geçer)
- [x] Format/test komutu belgeli + hook ile zorlanıyor → [CLAUDE.md](CLAUDE.md), [.githooks/pre-commit](.githooks/pre-commit)
- [x] Tek-test nasıl çalıştırılır → `bash tests/profile_test.sh` ([CLAUDE.md](CLAUDE.md))

## EKLENTİLER / HOOK'LAR
- [x] Git hook (core.hooksPath) herkes için → [.githooks/pre-commit](.githooks/pre-commit), `core.hooksPath=.githooks` aktif
- [x] Doc-sync hook tracked → [.githooks/pre-commit](.githooks/pre-commit) (advisory; `STRICT_DOCS=1` blocking)
- [x] Gürültülü kapılar advisory — shell fmt staged-scope, lint/doc-sync advisory
- [x] Plugin/skill paylaşım kararı — bu repo plugin → [.claude-plugin/marketplace.json](.claude-plugin/marketplace.json)
- [x] settings.json tracked, settings.local.json gitignore → [.gitignore](.gitignore)

## İŞ AKIŞI
- [x] Branch/commit/PR konvansiyonları CLAUDE.md'de → [CLAUDE.md](CLAUDE.md) "Git workflow"
- [x] PR/MR + commit-mesajı şablonları → [.github/pull_request_template.md](.github/pull_request_template.md), [.gitmessage](.gitmessage)
- [x] Commit konu formatı zorlanıyor (`ABC-1234`, `vibe.ticketre` ile) → [.githooks/commit-msg](.githooks/commit-msg)

---

### Açık (insan kararı/aksiyonu)
| Madde | Aksiyon |
|---|---|
| permissions.allow | classifier blokladı → aşağıdaki snippet'i elle `.claude/settings.json`'a ekle |
| docs/architecture/overview.md | `<TODO>` — mimari diyagram istenirse doldur |
| Domain sözlüğü | jargon artarsa ekle |
| shellcheck/shfmt | kurulursa hook fmt/lint otomatik devreye girer |

#### permissions.allow snippet (`.claude/settings.json` — `allow` dizisini bununla değiştir)
Güvenli/sık komutlar prompt'suz; **mutasyon yapan git komutları (`add`/`commit`/`push`) bilerek yok.**

```json
{
  "permissions": {
    "allow": [
      "Bash(bash tests/run.sh)",
      "Bash(shellcheck:*)",
      "Bash(shfmt:*)",
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git show:*)",
      "Bash(git branch:*)"
    ],
    "deny": []
  }
}
```
