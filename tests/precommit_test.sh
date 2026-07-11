#!/usr/bin/env bash
# pre-commit hook çalışma-zamanı (smoke) testi — gerçek git repo'da davranış: doc-sync advisory/blocking,
# commit-msg entegrasyonu. fmt/lint araçları gerekmez (kurulu değilse hook o adımı atlar — tasarım bu).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD="$ROOT/skills/vibe-setup/scaffold.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

command -v git >/dev/null 2>&1 || { echo "  skip: git yok"; echo "precommit_test: 0 passed, 0 failed"; exit 0; }

d="$tmp/repo"; mkdir -p "$d"
git -C "$d" init -q
git -C "$d" config user.email test@test
git -C "$d" config user.name test
git -C "$d" config commit.gpgsign false
echo 'echo hi' > "$d/tool.sh"                      # .sh dosyası → init shell profilini seçer (SRC_RE \.sh$)
bash "$SCAFFOLD" init "$d" >/dev/null 2>&1
git -C "$d" config core.hooksPath .githooks
grep -qF '\.sh$' "$d/.githooks/pre-commit" || bad "shell profili secilmedi (SRC_RE gomulmedi)"

# 1. kaynak + doküman birlikte staged → hook geçer, commit olur
git -C "$d" add -A
if git -C "$d" commit -q -m 'TST-1 ilk commit' 2>/dev/null; then ok "kaynak+dokuman commit gecti"; else bad "ilk commit bloklandi"; fi

# 2. STRICT_DOCS=1 + sadece kaynak staged → doc-sync bloklar
echo 'echo v2' >> "$d/tool.sh"; git -C "$d" add tool.sh
if STRICT_DOCS=1 git -C "$d" commit -q -m 'TST-2 kaynak' 2>/dev/null; then bad "STRICT_DOCS=1 bloklamadi"; else ok "STRICT_DOCS=1 doc'suz kaynak bloklandi"; fi
[ "$(git -C "$d" rev-list --count HEAD)" = "1" ] && ok "bloklanan commit olusmadi" || bad "bloklanmasina ragmen commit olustu"

# 3. aynı staged durum, STRICT_DOCS'suz → doc-sync advisory, geçer
if git -C "$d" commit -q -m 'TST-3 kaynak' 2>/dev/null; then ok "STRICT_DOCS'suz advisory gecti"; else bad "advisory modda bloklandi"; fi

# 4. commit-msg entegrasyonu — vibe.ticketre ayarsızken serbest, set edilince bloklar
echo 'echo v3' >> "$d/tool.sh"; git -C "$d" add tool.sh
if git -C "$d" commit -q -m 'formatsiz mesaj serbest' 2>/dev/null; then ok "ayarsız: ticket-key'siz mesaj gecti"; else bad "ayarsız: ticket-key'siz mesaj bloklandi"; fi
git -C "$d" config vibe.ticketre '^[A-Z]{3}-[0-9]{1,4} '
echo 'echo v4' >> "$d/tool.sh"; git -C "$d" add tool.sh
if git -C "$d" commit -q -m 'formatsiz mesaj' 2>/dev/null; then bad "ticketre set: formatsiz mesaj gecti"; else ok "ticketre set: formatsiz mesaj bloklandi"; fi
if git -C "$d" commit -q -m 'TST-4 uyan mesaj' 2>/dev/null; then ok "ticketre set: uyan mesaj gecti"; else bad "ticketre set: uyan mesaj bloklandi"; fi

echo "precommit_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
