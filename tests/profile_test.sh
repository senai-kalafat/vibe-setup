#!/usr/bin/env bash
# scaffold.sh detect_profile davranış testi — bağımsız (bats/dep yok).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD="$ROOT/skills/vibe-setup/scaffold.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

stack_of() { bash "$SCAFFOLD" profile "$1" 2>/dev/null | grep '^STACK=' | cut -d= -f2; }
field_of() { bash "$SCAFFOLD" profile "$1" 2>/dev/null | grep "^$2=" | cut -d= -f2-; }

check_stack() { # desc  expected  dir
  local got; got="$(stack_of "$3")"
  if [ "$got" = "$2" ]; then echo "  ok: $1 ($got)"; pass=$((pass+1))
  else echo "  FAIL: $1 — beklenen '$2', gelen '$got'"; fail=$((fail+1)); fi
}

mkdir -p "$tmp/go"   && : > "$tmp/go/go.mod";                check_stack "go.mod → go"          go      "$tmp/go"
mkdir -p "$tmp/node" && echo '{}' > "$tmp/node/package.json"; check_stack "package.json → node"   node    "$tmp/node"
mkdir -p "$tmp/py"   && : > "$tmp/py/pyproject.toml";        check_stack "pyproject → python"    python  "$tmp/py"
mkdir -p "$tmp/sh"   && : > "$tmp/sh/foo.sh";                check_stack "*.sh → shell"          shell   "$tmp/sh"
mkdir -p "$tmp/none";                                         check_stack "boş → unknown"         unknown "$tmp/none"
mkdir -p "$tmp/kt"    && : > "$tmp/kt/build.gradle.kts";      check_stack "build.gradle.kts → kotlin" kotlin "$tmp/kt"
mkdir -p "$tmp/java"  && : > "$tmp/java/build.gradle";        check_stack "build.gradle → java"   java    "$tmp/java"
mkdir -p "$tmp/swift" && : > "$tmp/swift/Package.swift";      check_stack "Package.swift → swift" swift   "$tmp/swift"
mkdir -p "$tmp/ex"    && : > "$tmp/ex/mix.exs";               check_stack "mix.exs → elixir"      elixir  "$tmp/ex"

# karma gradle: kts + groovy birlikte → kts önce eşleşir → kotlin
mkdir -p "$tmp/mixed" && : > "$tmp/mixed/build.gradle.kts" && : > "$tmp/mixed/build.gradle"
check_stack "kts+groovy karma → kotlin" kotlin "$tmp/mixed"

# biome subcase: package.json + biome.json → fmt = biome check
mkdir -p "$tmp/biome" && echo '{}' > "$tmp/biome/package.json" && echo '{}' > "$tmp/biome/biome.json"
if field_of "$tmp/biome" FMT | grep -q 'biome'; then echo "  ok: biome.json → biome check"; pass=$((pass+1))
else echo "  FAIL: biome fmt — gelen '$(field_of "$tmp/biome" FMT)'"; fail=$((fail+1)); fi

# FMT_FILE_OK: go staged-scope (1), rust repo-advisory (0)
mkdir -p "$tmp/rust" && : > "$tmp/rust/Cargo.toml"
[ "$(field_of "$tmp/go" FMT_FILE_OK)" = "1" ]   && { echo "  ok: go FMT_FILE_OK=1"; pass=$((pass+1)); }   || { echo "  FAIL: go FMT_FILE_OK"; fail=$((fail+1)); }
[ "$(field_of "$tmp/rust" FMT_FILE_OK)" = "0" ] && { echo "  ok: rust FMT_FILE_OK=0"; pass=$((pass+1)); } || { echo "  FAIL: rust FMT_FILE_OK"; fail=$((fail+1)); }
[ "$(field_of "$tmp/kt" FMT_FILE_OK)" = "0" ]   && { echo "  ok: kotlin FMT_FILE_OK=0"; pass=$((pass+1)); } || { echo "  FAIL: kotlin FMT_FILE_OK"; fail=$((fail+1)); }
[ "$(field_of "$tmp/swift" FMT_FILE_OK)" = "1" ] && { echo "  ok: swift FMT_FILE_OK=1"; pass=$((pass+1)); } || { echo "  FAIL: swift FMT_FILE_OK"; fail=$((fail+1)); }
[ "$(field_of "$tmp/ex" FMT_FILE_OK)" = "1" ]   && { echo "  ok: elixir FMT_FILE_OK=1"; pass=$((pass+1)); } || { echo "  FAIL: elixir FMT_FILE_OK"; fail=$((fail+1)); }

echo "profile_test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
