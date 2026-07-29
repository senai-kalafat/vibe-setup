# vibe-setup: doc-sync'i hedef repolarda gerçekten zorlayıcı yap — design

Date: 2026-07-30
Status: approved
Ticket: VIB-13

## Problem

`scaffold.sh`'ın ürettiği `.githooks/pre-commit` hook'unda doc-sync kontrolü (kaynak değişti ama
`docs/`/`README`/`CLAUDE`/`AGENTS` değişmedi) `STRICT_DOCS=1` **environment variable**'ı set
edilmedikçe sadece advisory (uyarı, bloklamaz). Bu, pratikte hiç kullanılmayan bir "zorlayıcı mod" —
kimse shell profiline kalıcı env var koymaz, her commit'te elle export etmek gerekir. Kullanıcı bunun
skill'in kurulduğu **hedef projelerde** gerçekten zorlayıcı olmasını istiyor.

## Mekanizma: env-var yerine git-config

Bu repoda zaten aynı sınıf bir karar için kanıtlanmış bir desen var: ticket-key zorlaması
(`vibe.ticketre` — repo-local git config, `.githooks/commit-msg` `git config --get` ile okur, kalıcı).
`STRICT_DOCS` da aynı deseni izlemeli: **`git config vibe.strictdocs true`** — repo-local, kalıcı,
`.githooks/pre-commit` `git config --get --bool vibe.strictdocs` ile okur. Bu, gerçekten "zorlayıcı"
olan tek yöntem (env-var'ın aksine bir kere set edilince tüm gelecekteki commit'lerde geçerli).

## Kapsam kararları

### 1. SKILL.md Faz 2 — yeni soru (ticket-key sorusunun yanına)

Mevcut ticket-key sorusu deseni: **zorunlu SOR, varsayma**, varsayılan öneri **kapalı**. doc-sync
sorusu da **zorunlu sorulur** ama varsayılan öneri **AÇIK** (kullanıcının bu spesifik talebi bu yönde):
**"doc-sync'i zorlayıcı (blocking) yapayım mı?"** — evet ise Faz 3 sonrasında
`git config vibe.strictdocs true` çalıştırılır. Hayır ise hiçbir şey yapılmaz (config set edilmez,
hook advisory kalır — mevcut varsayılan davranış korunur).

### 2. `render_precommit()` — mekanizma değişikliği

Find (mevcut):
```bash
# 3. doc-sync (advisory default; STRICT_DOCS=1 → blocking) — kaynak değişti, doküman değişmediyse
src=0; printf '%s\n' "$staged" | grep -qE '@SRCRE@' && src=1
doc=0; printf '%s\n' "$staged" | grep -qE '(^docs/.*\.md$|(^|/)(README|CLAUDE|AGENTS)\.md$)' && doc=1
if [ "$src" = 1 ] && [ "$doc" = 0 ]; then
  echo "ℹ doc-sync: kaynak değişti, doküman güncellenmedi. docs/ + README/CLAUDE/AGENTS gözden geçir." >&2
  [ "${STRICT_DOCS:-}" = "1" ] && { echo "  STRICT_DOCS=1 → blocking." >&2; fail=1; }
fi
```

Yeni:
```bash
# 3. doc-sync (advisory default; git config vibe.strictdocs true → blocking) — kaynak değişti,
#    doküman değişmediyse. vibe.ticketre ile AYNI desen: repo-local git config, kalıcı.
src=0; printf '%s\n' "$staged" | grep -qE '@SRCRE@' && src=1
doc=0; printf '%s\n' "$staged" | grep -qE '(^docs/.*\.md$|(^|/)(README|CLAUDE|AGENTS)\.md$)' && doc=1
if [ "$src" = 1 ] && [ "$doc" = 0 ]; then
  echo "ℹ doc-sync: kaynak değişti, doküman güncellenmedi. docs/ + README/CLAUDE/AGENTS gözden geçir." >&2
  strict="$(git config --get --bool vibe.strictdocs 2>/dev/null || echo false)"
  [ "$strict" = "true" ] && { echo "  vibe.strictdocs=true → blocking." >&2; fail=1; }
fi
```

Header comment satırı da güncellenir: `# Stack: @STACK@ | doc-sync'i blocking yap: STRICT_DOCS=1 |
Bypass tümü: --no-verify` → `# Stack: @STACK@ | doc-sync'i blocking yap: git config vibe.strictdocs
true | Bypass tümü: --no-verify`.

Ayrı bir env-var escape-hatch'i eklenmez — mevcut `git commit --no-verify` zaten acil bypass'tır.

### 3. Sürüm etkisi (CLAUDE.md'nin "Sürüm yükseltirken 3 yer" gotcha'sı)

- `VIBE_VERSION` 4 → 5.
- `artifact_changed_in ".githooks/pre-commit"` → `5` (mevcut `2`'den).
- Template'in kendisi (`render_precommit`) yukarıdaki gibi değişir.

### 4. Kapsam: yeni + var olan repolar

`.githooks/pre-commit` "synced" sınıf — `upgrade` dokunulmamış kopyaları otomatik yeni template'e
taşır (mekanizma değişir, `STRICT_DOCS` yerine `vibe.strictdocs` okunur). Ama git-config değeri
otomatik set edilmez. SKILL.md'nin `## Upgrade akışı` bölümüne yeni not: eğer bu upgrade
`.githooks/pre-commit`'i UPDATE ettiyse **ve** `vibe.strictdocs` hiç set değilse (`git config --get
vibe.strictdocs` boş dönerse), kullanıcıya Faz 2'deki **aynı soru** sorulur.

### 5. README güncellemesi

"Git hook davranışı" bölümündeki `STRICT_DOCS=1 → blocking` referansı `git config vibe.strictdocs
true → blocking` olarak güncellenir.

## Kapsam dışı (bilinçli)

- Bu repo'nun (vibe-setup'ın kendisi) kendi `.githooks/pre-commit`'i için `vibe.strictdocs` açıp
  açmamak — ayrı, isteğe bağlı bir ops kararı, bu spec sadece MEKANİZMAYI hedef repolara taşıyor.
- Ayrı bir env-var bypass mekanizması — `--no-verify` zaten yeterli.
- `STRICT_DOCS` env-var desteğinin geriye dönük korunması (iki mekanizma birden) — kapsam dışı, tek
  kanonik mekanizma (git-config) olsun; zaten kimse env-var'ı gerçek kullanımda set etmiyordu.
