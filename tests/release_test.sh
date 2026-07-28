#!/usr/bin/env bash
# scripts/release.sh testi — bump hesabi (major/minor/patch), plugin.json yazma, version-sync.sh
# cagrisi ile propagation, commit/tag ATMAMA. Bagimsiz (dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE="$ROOT/scripts/release.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

ok()  { echo "  ok: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

fresh() {  # $1 = alt-dizin adi, $2 = baslangic versiyonu
  local d="$tmp/$1"
  mkdir -p "$d/.claude-plugin" "$d/.cursor-plugin"
  cat > "$d/.claude-plugin/plugin.json" <<EOF
{
  "name": "vibe-setup",
  "version": "$2",
  "description": "test"
}
EOF
  cat > "$d/.claude-plugin/marketplace.json" <<EOF
{
  "name": "vibe-setup",
  "metadata": {
    "description": "vibe-setup — Claude Code plugins",
    "version": "$2"
  },
  "plugins": [
    {
      "name": "vibe-setup",
      "version": "$2"
    }
  ]
}
EOF
  cat > "$d/.cursor-plugin/plugin.json" <<EOF
{
  "name": "vibe-setup",
  "version": "$2",
  "description": "test"
}
EOF
  echo "$d"
}

# 1. patch bump
d="$(fresh patch-case 1.2.3)"
bash "$RELEASE" patch "$d" >/dev/null 2>&1
grep -q '"version": "1.2.4"' "$d/.claude-plugin/plugin.json" && ok "patch: plugin.json 1.2.3 -> 1.2.4" || bad "patch bump yanlis"
grep -q '"version": "1.2.4"' "$d/.cursor-plugin/plugin.json" && ok "patch: cursor-plugin.json yayildi" || bad "patch: cursor-plugin.json yayilmadi"

# 2. minor bump (patch sifirlanmali)
d="$(fresh minor-case 1.2.3)"
bash "$RELEASE" minor "$d" >/dev/null 2>&1
grep -q '"version": "1.3.0"' "$d/.claude-plugin/plugin.json" && ok "minor: 1.2.3 -> 1.3.0 (patch sifirlandi)" || bad "minor bump yanlis"

# 3. major bump (minor+patch sifirlanmali)
d="$(fresh major-case 1.2.3)"
bash "$RELEASE" major "$d" >/dev/null 2>&1
grep -q '"version": "2.0.0"' "$d/.claude-plugin/plugin.json" && ok "major: 1.2.3 -> 2.0.0 (minor+patch sifirlandi)" || bad "major bump yanlis"

# 4. marketplace.json'un IKI occurrence'i da guncellenmis
d="$(fresh marketplace-case 0.5.0)"
bash "$RELEASE" patch "$d" >/dev/null 2>&1
[ "$(grep -c '"version": "0.5.1"' "$d/.claude-plugin/marketplace.json")" = "2" ] && ok "marketplace.json her iki alan da guncellendi" || bad "marketplace.json guncellemesi eksik"

# 5. gecersiz bump tipi -> nonzero exit, hicbir sey degismez
d="$(fresh invalid-case 1.0.0)"
out="$(bash "$RELEASE" nonsense "$d" 2>&1)"; code=$?
[ "$code" -ne 0 ] && ok "gecersiz bump tipi nonzero exit" || bad "gecersiz bump tipi exit 0 (hata vermeliydi)"
grep -q '"version": "1.0.0"' "$d/.claude-plugin/plugin.json" && ok "gecersiz bump'ta plugin.json degismedi" || bad "gecersiz bump'ta plugin.json bozuldu"

# 6. commit/tag ATILMADI (gercek git repo kurup kontrol et)
if command -v git >/dev/null 2>&1; then
  d="$tmp/git-case"; mkdir -p "$d/.claude-plugin" "$d/.cursor-plugin"
  git -C "$d" init -q
  cat > "$d/.claude-plugin/plugin.json" <<'EOF'
{ "name": "vibe-setup", "version": "1.0.0", "description": "test" }
EOF
  cp "$d/.claude-plugin/plugin.json" "$d/.claude-plugin/marketplace.json"
  cp "$d/.claude-plugin/plugin.json" "$d/.cursor-plugin/plugin.json"
  git -C "$d" add -A && git -C "$d" -c user.email=t@t.com -c user.name=t commit -q -m "baseline"
  before_head="$(git -C "$d" rev-parse HEAD)"
  bash "$RELEASE" patch "$d" >/dev/null 2>&1
  after_head="$(git -C "$d" rev-parse HEAD)"
  [ "$before_head" = "$after_head" ] && ok "release.sh commit atmadi (HEAD degismedi)" || bad "release.sh yanlislikla commit atti"
  [ -z "$(git -C "$d" tag --list)" ] && ok "release.sh tag atmadi" || bad "release.sh yanlislikla tag atti"
else
  echo "  skip: git yok — commit/tag-atmama testi atlandi"
fi

# 7. BUMP verilmez + stdin terminal degilse (agent/CI) sessizce patlamak yerine net hata basmali
d="$(fresh notty-case 1.0.0)"
out="$(bash "$RELEASE" "" "$d" </dev/null 2>&1)"; code=$?
[ "$code" -ne 0 ] && ok "non-tty + BUMP yok: nonzero exit" || bad "non-tty + BUMP yok: exit 0 (hata vermeliydi)"
[ -n "$out" ] && ok "non-tty + BUMP yok: hata mesaji basildi (sessiz olum degil)" || bad "non-tty + BUMP yok: cikti bos (sessizce oldu)"
grep -q '"version": "1.0.0"' "$d/.claude-plugin/plugin.json" && ok "non-tty + BUMP yok: plugin.json degismedi" || bad "non-tty + BUMP yok: plugin.json bozuldu"

echo "release_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
