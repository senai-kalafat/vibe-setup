#!/usr/bin/env sh
# vibe-setup:v9 (managed; elle düzenlersen upgrade EZMEZ → CONFLICT → LLM merge)
# Repo-tracked SessionStart kontrolü: zorunlu bağımlılıklar (caveman + context-mode) aktif mi?
# SESSİZ — her şey yolundaysa hiçbir şey basmaz. ASLA bloklamaz: her yolda exit 0.
# Ağa çıkmaz, dosya yazmaz, saniyenin altında biter.
missing=""
[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.caveman-active" ] || missing="caveman"
if ! command -v context-mode >/dev/null 2>&1; then
  [ -n "$missing" ] && missing="$missing, context-mode" || missing="context-mode"
fi
[ -z "$missing" ] && exit 0

echo "vibe-setup: zorunlu bağımlılık aktif değil → $missing"
case "$missing" in *caveman*)
  echo "  caveman: bu session'da aktif değil → /caveman full"
  echo "           (hiç kurulu değilse: curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash -s -- --with-init)" ;;
esac
case "$missing" in *context-mode*)
  echo "  context-mode: npm install -g context-mode" ;;
esac
exit 0
