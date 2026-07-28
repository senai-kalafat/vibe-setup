#!/usr/bin/env bash
# scripts/version-sync.sh [DIR] — .claude-plugin/plugin.json'daki "version" tek kaynak;
# marketplace.json + .cursor-plugin/plugin.json'a yayar. Manuel calistirilir (release aninda),
# git hook'a baglanmaz. sed -i YOK (BSD/GNU fark) — awk gsub + tmp-dosya + mv (mevcut kod tabani deseni).
set -euo pipefail
DIR="${1:-.}"
cd "$DIR"

PLUGIN_JSON=.claude-plugin/plugin.json
if [ ! -f "$PLUGIN_JSON" ]; then
  echo "kullanim: version-sync.sh [DIR] ($PLUGIN_JSON bulunamadi)" >&2
  exit 1
fi

VERSION="$(grep -m1 -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$PLUGIN_JSON" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
if [ -z "$VERSION" ]; then
  echo "$PLUGIN_JSON icinde \"version\" bulunamadi" >&2
  exit 1
fi

sync_file() {  # $1 = hedef dosya
  local f="$1"
  if [ ! -f "$f" ]; then echo "  SKIP  $f (yok)"; return; fi
  awk -v v="$VERSION" '{ gsub(/"version"[[:space:]]*:[[:space:]]*"[^"]+"/, "\"version\": \"" v "\""); print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  echo "  OK    $f → $VERSION"
}

echo "version-sync — kaynak: $PLUGIN_JSON ($VERSION)"
sync_file .claude-plugin/marketplace.json
sync_file .cursor-plugin/plugin.json
echo "Bitti."
