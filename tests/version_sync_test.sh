#!/usr/bin/env bash
# scripts/version-sync.sh testi — plugin.json tek kaynak, marketplace.json (2 occurrence) +
# .cursor-plugin/plugin.json'a yayilir. Bagimsiz (dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SYNC="$ROOT/scripts/version-sync.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
work="$tmp/repo"; mkdir -p "$work/.claude-plugin" "$work/.cursor-plugin"

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

cat > "$work/.claude-plugin/plugin.json" <<'EOF'
{
  "name": "vibe-setup",
  "version": "9.9.9",
  "description": "test"
}
EOF
cat > "$work/.claude-plugin/marketplace.json" <<'EOF'
{
  "name": "vibe-setup",
  "metadata": {
    "description": "vibe-setup — Claude Code plugins",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "vibe-setup",
      "version": "0.1.0"
    }
  ]
}
EOF
cat > "$work/.cursor-plugin/plugin.json" <<'EOF'
{
  "name": "vibe-setup",
  "version": "0.1.0",
  "description": "test"
}
EOF

bash "$SYNC" "$work" >/dev/null 2>&1

[ "$(grep -c '"version": "9.9.9"' "$work/.claude-plugin/marketplace.json")" = "2" ] && ok "marketplace.json her iki version alani da guncellendi" || bad "marketplace.json version guncellemesi eksik/yanlis"
grep -q '"version": "9.9.9"' "$work/.cursor-plugin/plugin.json" && ok "cursor-plugin.json guncellendi" || bad "cursor-plugin.json guncellenmedi"
grep -q '"version": "9.9.9"' "$work/.claude-plugin/plugin.json" && ok "kaynak plugin.json degismedi (hala 9.9.9)" || bad "kaynak plugin.json bozuldu"

if command -v jq >/dev/null 2>&1; then
  jq -e . "$work/.claude-plugin/marketplace.json" >/dev/null 2>&1 && ok "marketplace.json gecerli JSON" || bad "marketplace.json bozuk JSON"
  jq -e . "$work/.cursor-plugin/plugin.json" >/dev/null 2>&1 && ok "cursor-plugin.json gecerli JSON" || bad "cursor-plugin.json bozuk JSON"
else
  echo "  skip: jq yok — JSON gecerlilik atlandi"
fi

# eksik .cursor-plugin/plugin.json durumunda cokmemeli (SKIP)
work2="$tmp/repo2"; mkdir -p "$work2/.claude-plugin"
cp "$work/.claude-plugin/plugin.json" "$work2/.claude-plugin/plugin.json"
cp "$work/.claude-plugin/marketplace.json" "$work2/.claude-plugin/marketplace.json"
out2="$(bash "$SYNC" "$work2" 2>&1)"; code2=$?
[ "$code2" -eq 0 ] && ok "cursor-plugin.json yokken bile exit 0" || bad "cursor-plugin.json yokken crash (exit $code2)"
printf '%s' "$out2" | grep -q 'SKIP' && ok "eksik dosya icin SKIP basildi" || bad "SKIP mesaji basilmadi"

# kaynak plugin.json hic yoksa net hata + nonzero exit
work3="$tmp/repo3"; mkdir -p "$work3"
bash "$SYNC" "$work3" >/dev/null 2>&1; code3=$?
[ "$code3" -ne 0 ] && ok "kaynak plugin.json yokken nonzero exit" || bad "kaynak plugin.json yokken exit 0 (hata verilmeliydi)"

echo "version_sync_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
