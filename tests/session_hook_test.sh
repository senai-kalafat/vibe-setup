#!/usr/bin/env bash
# .claude/hooks/vibe-session-check.sh davranis testi — SESSIZ + ASLA BLOKLAMAZ degismezleri.
# Bagimsiz (dep yok). Gercek caveman/context-mode kurulumuna BAGIMLI DEGIL: ikisi de stub'lanir.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD="$ROOT/skills/vibe-setup/scaffold.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

work="$tmp/repo"; mkdir -p "$work"
bash "$SCAFFOLD" init "$work" >/dev/null 2>&1
HOOK="$work/.claude/hooks/vibe-session-check.sh"

# 0. dosya + izin + stamp
[ -f "$HOOK" ] && ok "hook olustu" || { bad "hook yok"; echo "session_hook_test: $pass passed, $fail failed"; exit 1; }
[ -x "$HOOK" ] && ok "hook +x" || bad "hook +x degil"
grep -q 'vibe-setup:v9' "$HOOK" && ok "stamp v9" || bad "stamp v9 degil"
sh -n "$HOOK" 2>/dev/null && ok "gecerli POSIX sh" || bad "sh syntax hatasi"

# stub ortam: sahte CLAUDE_CONFIG_DIR + PATH'e sahte context-mode
cfg="$tmp/cfg"; mkdir -p "$cfg"
stub="$tmp/bin"; mkdir -p "$stub"
printf '#!/usr/bin/env sh\nexit 0\n' > "$stub/context-mode"; chmod +x "$stub/context-mode"

OUT="$tmp/out"; RC=0
# $1=caveman flag(1/0) $2=context-mode PATH'te mi(1/0). Cikti $OUT'a, exit kodu $RC'ye.
# NOT: $( ) subshell RC'yi disari tasimaz — bu yuzden dosya + global degisken.
run_hook() {
  local p
  # "yok" senaryosunda minimal PATH: makinede context-mode GERCEKTEN kurulu olabilir
  # (bu repoda zorunlu bagimlilik) — stub'i cikarmak yetmez, gercek binary'yi de gizlemek gerek.
  if [ "$2" = "1" ]; then p="$stub:$PATH"; else p="/usr/bin:/bin"; fi
  if [ "$1" = "1" ]; then : > "$cfg/.caveman-active"; else rm -f "$cfg/.caveman-active"; fi
  CLAUDE_CONFIG_DIR="$cfg" PATH="$p" sh "$HOOK" >"$OUT" 2>&1
  RC=$?
}

# 1. her sey saglikli → TAMAMEN SESSIZ, exit 0
run_hook 1 1
[ ! -s "$OUT" ] && ok "saglikli: cikti YOK (sessiz)" || bad "saglikli: gurultu basti: '$(cat "$OUT")'"
[ "$RC" -eq 0 ] && ok "saglikli: exit 0" || bad "saglikli: exit $RC"

# 2. caveman flag yok → uyarir, YINE exit 0
run_hook 0 1; o="$(cat "$OUT")"
printf '%s' "$o" | grep -q 'caveman' && ok "caveman eksik: uyari basar" || bad "caveman eksik: uyari yok"
printf '%s' "$o" | grep -q '/caveman full' && ok "caveman eksik: duzeltme komutu verir" || bad "duzeltme komutu yok"
printf '%s' "$o" | grep -q 'context-mode' && bad "caveman eksikken context-mode de sikayet etti" || ok "sadece eksik olani sikayet eder"
[ "$RC" -eq 0 ] && ok "caveman eksik: YINE exit 0 (bloklamaz)" || bad "caveman eksik: exit $RC — SESSION BLOKLANDI"

# 3. context-mode yok → uyarir, exit 0
run_hook 1 0; o="$(cat "$OUT")"
printf '%s' "$o" | grep -q 'npm install -g context-mode' && ok "context-mode eksik: kurulum komutu verir" || bad "context-mode komutu yok"
[ "$RC" -eq 0 ] && ok "context-mode eksik: exit 0" || bad "context-mode eksik: exit $RC"

# 4. ikisi de yok → ikisini de sayar, exit 0
run_hook 0 0; o="$(cat "$OUT")"
printf '%s' "$o" | grep -q 'caveman' && printf '%s' "$o" | grep -q 'context-mode' \
  && ok "ikisi eksik: ikisini de listeler" || bad "ikisi eksik: eksik listeleme"
[ "$RC" -eq 0 ] && ok "ikisi eksik: exit 0" || bad "ikisi eksik: exit $RC"

# 5. HOME/CLAUDE_CONFIG_DIR hic yoksa bile patlamaz (fail-open)
out="$(env -u CLAUDE_CONFIG_DIR HOME="$tmp/nonexistent" PATH="$stub:$PATH" sh "$HOOK" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "HOME bozukken bile exit 0 (fail-open)" || bad "HOME bozukken exit $rc"

echo "session_hook_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
