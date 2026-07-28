#!/usr/bin/env bash
# scripts/vibe-update.sh [DIR] — vibe-setup'in KENDI kurulu kopyasini (git clone / Claude marketplace
# cache / Cursor plugin symlink) en son git TAG'e gunceller (self-update). scaffold.sh upgrade'den
# TAMAMEN AYRI: o hedef repolarin scaffold dosyalarini gunceller (VIBE_VERSION), bu ise ARACIN KENDI
# repo kopyasini (git tag). Branch-HEAD DEGIL tag kullanir: main surekli ara-commit alir
# (spec/plan/task commit'leri), tag ise maintainer'in acikca "bu nokta saglam" dedigi an.
set -euo pipefail
DIR="${1:-.}"
cd "$DIR"

if [ ! -d .git ]; then
  echo "Bu vibe-setup kopyasi bir git repo degil — self-update yapilamaz." >&2
  exit 1
fi

if ! git fetch origin --tags --quiet 2>/dev/null; then
  echo "git fetch basarisiz (ag/remote sorunu?)" >&2
  exit 1
fi

LATEST_TAG="$(git tag --list 'v*' --sort=-version:refname | head -1)"
if [ -z "$LATEST_TAG" ]; then
  echo "Hic tag bulunamadi — self-update icin en az bir 'vX.Y.Z' tag'i gerekli." >&2
  exit 1
fi

LOCAL="$(git rev-parse HEAD)"
TARGET="$(git rev-parse "$LATEST_TAG")"

if [ "$LOCAL" = "$TARGET" ]; then
  echo "Guncel: zaten $LATEST_TAG'desiniz."
  exit 0
fi

if git merge-base --is-ancestor "$TARGET" "$LOCAL"; then
  echo "Kurulu kopya zaten $LATEST_TAG'den daha yeni (henuz taglenmemis local commit'ler icerebilir)."
  exit 0
fi

if ! git merge-base --is-ancestor "$LOCAL" "$TARGET"; then
  echo "Yerel kopya $LATEST_TAG'den SAPMIS (elle degistirilmis olabilir) — otomatik guncelleme GUVENLI DEGIL." >&2
  echo "Elle coz: git status / git diff / gerekirse yedekleyip yeniden klonlayin." >&2
  exit 1
fi

echo "Yeni surum: $LATEST_TAG"
git log --oneline "$LOCAL..$TARGET"
echo
git merge --ff-only "$LATEST_TAG"
echo "Guncellendi: $LATEST_TAG"
