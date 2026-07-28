#!/usr/bin/env bash
# scripts/release.sh [major|minor|patch] [DIR] — yeni surumu hesaplar, .claude-plugin/plugin.json'a
# yazar, scripts/version-sync.sh ile marketplace.json + .cursor-plugin/plugin.json'a yayar.
# Commit/tag ATMAZ — bkz RELEASE.md (ticket-key secimi insan/LLM karari, script'in degil).
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUMP="${1:-}"
DIR="${2:-.}"

if [ -z "$BUMP" ]; then
  read -rp "Bump tipi (major/minor/patch): " BUMP
fi
case "$BUMP" in
  major|minor|patch) ;;
  *) echo "gecersiz bump tipi: '$BUMP' (major|minor|patch olmali)" >&2; exit 1 ;;
esac

cd "$DIR"
PLUGIN_JSON=.claude-plugin/plugin.json
if [ ! -f "$PLUGIN_JSON" ]; then
  echo "kullanim: release.sh [major|minor|patch] [DIR] ($PLUGIN_JSON bulunamadi)" >&2
  exit 1
fi

CURRENT="$(grep -m1 -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$PLUGIN_JSON" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
if [ -z "$CURRENT" ]; then
  echo "$PLUGIN_JSON icinde \"version\" bulunamadi" >&2
  exit 1
fi

IFS='.' read -r major minor patch <<< "$CURRENT"
case "$BUMP" in
  major) major=$((major+1)); minor=0; patch=0 ;;
  minor) minor=$((minor+1)); patch=0 ;;
  patch) patch=$((patch+1)) ;;
esac
NEW="$major.$minor.$patch"

awk -v v="$NEW" '{ gsub(/"version"[[:space:]]*:[[:space:]]*"[^"]+"/, "\"version\": \"" v "\""); print }' "$PLUGIN_JSON" > "$PLUGIN_JSON.tmp" && mv "$PLUGIN_JSON.tmp" "$PLUGIN_JSON"

echo "Surum: $CURRENT -> $NEW ($BUMP)"
bash "$SELF_DIR/version-sync.sh" "$(pwd)"

echo
echo "Dosyalar hazir (commit/tag ATILMADI). Sonraki adimlar icin: RELEASE.md"
