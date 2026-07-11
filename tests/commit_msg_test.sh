#!/usr/bin/env bash
# .githooks/commit-msg davranış testi — ticket-key OPSİYONEL (vibe.ticketre). Bağımsız (bats/dep yok).
# Üç mod: ayarsız → hiçbir şey bloklanmaz; standart desen → eski zorlama; özel desen → kullanıcı regex'i.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/.githooks/commit-msg"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

command -v git >/dev/null 2>&1 || { echo "  skip: git yok"; echo "commit_msg_test: 0 passed, 0 failed"; exit 0; }
work="$tmp/repo"; mkdir -p "$work"; git -C "$work" init -q

# run_hook <expected-exit 0|1> <desc> <commit-msg body...>  (hook, config'i cwd repo'sundan okur)
run_hook() {
  local want="$1" desc="$2"; shift 2
  printf '%s\n' "$@" > "$tmp/msg"
  (cd "$work" && bash "$HOOK" "$tmp/msg") >/dev/null 2>&1; local got=$?
  if [ "$got" -eq "$want" ]; then echo "  ok: $desc"; pass=$((pass+1))
  else echo "  FAIL: $desc — beklenen exit $want, gelen $got"; fail=$((fail+1)); fi
}

# A. vibe.ticketre AYARSIZ → hook hiçbir şeyi bloklamaz
run_hook 0 "ayarsız: key'siz mesaj geçer"   "readme guncelle"
run_hook 0 "ayarsız: boş mesaj bile geçer"  "# sadece yorum"

# B. standart desen set → eski zorlama davranışı
git -C "$work" config vibe.ticketre '^[A-Z]{3}-[0-9]{1,4} '
# kabul (exit 0)
run_hook 0 "VAN-3195 + özet"            "VAN-3195 readme guncelle"
run_hook 0 "tek hane (ABC-1)"           "ABC-1 x"
run_hook 0 "Merge muaf"                 "Merge branch 'x' into main"
run_hook 0 "Revert muaf"                'Revert "VAN-1 x"'
run_hook 0 "fixup! muaf"                "fixup! VAN-3195 x"
run_hook 0 "squash! muaf"              "squash! VAN-3195 x"
run_hook 0 "yorum satırı atlanır"       "# comment" "VAN-3195 gercek konu"
# red (exit 1)
run_hook 1 "4 harf (ABCD-1)"            "ABCD-1 x"
run_hook 1 "2 harf (AB-1)"              "AB-1 x"
run_hook 1 "5 hane (VAN-12345)"         "VAN-12345 x"
run_hook 1 "kucuk harf (van-3195)"      "van-3195 x"
run_hook 1 "key yok"                    "readme guncelle"
run_hook 1 "ozet yok (sondaki bosluk)"  "VAN-3195"
run_hook 1 "bos mesaj"                  "# sadece yorum"

# C. özel desen → kullanıcı regex'i geçerli
git -C "$work" config vibe.ticketre '^JIRA-[0-9]+: '
run_hook 0 "özel desen uyan (JIRA-42:)"  "JIRA-42: readme guncelle"
run_hook 1 "özel desen uymayan (VAN-1)"  "VAN-1 readme guncelle"

echo "commit_msg_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
