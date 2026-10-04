#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
DIST="$ROOT/dist"
DMG="$DIST/R0M-$VERSION.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

"$ROOT/build.sh" --no-install

mkdir -p "$DIST"
rm -f "$DMG"
cp -R "$ROOT/build/R0M.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -quiet -volname "R0M" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
(cd "$DIST" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")

echo "Created $DMG"
cat "$DMG.sha256"
