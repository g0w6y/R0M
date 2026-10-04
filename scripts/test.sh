#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/t" && cp "$ROOT/Tests/CleanerSelfTest.swift" "$TMP/t/main.swift"
swiftc -O -o "$TMP/run" "$TMP/t/main.swift" \
  "$ROOT/Sources/R0M/Cleaner.swift" "$ROOT/Sources/R0M/Admin.swift" "$ROOT/Sources/R0M/Shell.swift" \
  -framework AppKit
"$TMP/run"
