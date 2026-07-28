#!/usr/bin/env bash
# scaffold.sh legacy AGENT.md -> AGENTS.md migrasyon testi. Bagimsiz (dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD="$ROOT/skills/vibe-setup/scaffold.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

# 1. AGENT.md (tekil) var, AGENTS.md yok -> audit bunu tespit etsin (init'ten ONCE bile)
work="$tmp/repo"; mkdir -p "$work"
printf '# Benim eski agent notlarim\nBu icerik onemli, kaybolmamali.\n' > "$work/AGENT.md"
audit_out="$(bash "$SCAFFOLD" audit "$work" 2>&1)"
printf '%s' "$audit_out" | grep -qi 'legacy AGENT.md' && ok "audit: legacy AGENT.md tespiti (init'ten once)" || bad "audit: legacy tespiti yok"

# 2. init calistir -> migrate etmeli: AGENTS.md icerik tasinir, AGENT.md symlink olur
init_out="$(bash "$SCAFFOLD" init "$work" 2>&1)"
printf '%s' "$init_out" | grep -q 'MIGRATE' && ok "init: MIGRATE mesaji basildi" || bad "init: MIGRATE mesaji yok"
[ -f "$work/AGENTS.md" ] && ok "AGENTS.md olustu" || bad "AGENTS.md yok"
grep -q 'Benim eski agent notlarim' "$work/AGENTS.md" && ok "eski icerik korundu (tasindi, sablonla EZILMEDI)" || bad "icerik kayboldu/ezildi"
[ -L "$work/AGENT.md" ] && ok "AGENT.md simdi symlink" || bad "AGENT.md symlink degil"
[ "$(readlink "$work/AGENT.md")" = "AGENTS.md" ] && ok "symlink AGENTS.md'yi gosteriyor" || bad "symlink hedefi yanlis"

# 3. manifest: AGENTS.md created:false olarak kayitli (vibe-setup'in urettigi icerik DEGIL)
grep -q '"AGENTS.md": { "v": [0-9]*, "sha": "[0-9]*", "created": false' "$work/.vibe-setup.json" 2>/dev/null \
  && ok "manifest: AGENTS.md created:false" || bad "manifest: AGENTS.md created:false degil (VERI KAYBI RISKI)"

# 4. KRITIK guvenlik testi: remove --apply migrasyonla gelen AGENTS.md'yi ASLA silmemeli
bash "$SCAFFOLD" remove "$work" --apply >/dev/null 2>&1
[ -f "$work/AGENTS.md" ] && ok "remove --apply: migrasyonla gelen AGENTS.md SILINMEDI" || bad "remove --apply: AGENTS.md SILINDI — VERI KAYBI, created:false ihlali"
grep -q 'Benim eski agent notlarim' "$work/AGENTS.md" 2>/dev/null && ok "remove sonrasi icerik hala duruyor" || bad "remove sonrasi icerik kayip"

# 5. sanity: legacy AGENT.md YOKSA normal davranis degismemis (AGENTS.md sablonla dusuyor, created:true)
normal="$tmp/normal-repo"; mkdir -p "$normal"
bash "$SCAFFOLD" init "$normal" >/dev/null 2>&1
grep -q '"AGENTS.md": { "v": [0-9]*, "sha": "[0-9]*", "created": true' "$normal/.vibe-setup.json" 2>/dev/null \
  && ok "sanity: legacy yokken AGENTS.md hala created:true" || bad "sanity: normal init davranisi bozuldu"

echo "agent_migration_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
