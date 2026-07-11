#!/usr/bin/env bash
# Tüm tests/*_test.sh dosyalarını çalıştırır. Dış bağımlılık yok (bats gerekmez).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
fail=0
for t in "$here"/*_test.sh; do
  [ -e "$t" ] || continue
  echo "== $(basename "$t")"
  bash "$t" || fail=1
done
[ "$fail" -eq 0 ] && echo "ALL TESTS PASSED" || echo "TESTS FAILED"
exit "$fail"
