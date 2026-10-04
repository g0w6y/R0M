#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="R0M"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUNDLE_ID="com.g0w6y.r0m"
INSTALL=1
[[ "${1:-}" == "--no-install" ]] && INSTALL=0

BUILD="$ROOT/build"
APP="$BUILD/$APP_NAME.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[[ "$(uname -m)" == "arm64" ]] || { echo "R0M supports Apple Silicon Macs only." >&2; exit 1; }
command -v swiftc >/dev/null || { echo "swiftc not found — run: xcode-select --install" >&2; exit 1; }

echo "==> Cleaning previous bundle"
rm -rf "$APP"
mkdir -p "$BIN_DIR" "$RES_DIR"

echo "==> Building app icon"
swiftc -O "$ROOT/scripts/makeicon.swift" -o "$TMP/makeicon"
"$TMP/makeicon" "$TMP/$APP_NAME.iconset"
iconutil -c icns "$TMP/$APP_NAME.iconset" -o "$RES_DIR/$APP_NAME.icns"

echo "==> Compiling Swift sources (v$VERSION)"
swiftc -O -parse-as-library \
  -o "$BIN_DIR/$APP_NAME" \
  -framework SwiftUI -framework AppKit -framework Charts -framework IOKit \
  -framework CoreWLAN -framework ServiceManagement \
  "$ROOT"/Sources/R0M/*.swift "$ROOT"/Sources/R0M/Views/*.swift

echo "==> Writing Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIconFile</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSLocationUsageDescription</key><string>R0M uses Location only to read the connected Wi-Fi network name (macOS requirement). It is never stored or transmitted.</string>
  <key>NSAppleEventsUsageDescription</key><string>R0M asks Finder to empty the Trash when you press "Empty Trash" in the Cleaner.</string>
  <key>NSHumanReadableCopyright</key><string>MIT License. Runs entirely on your Mac.</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP" 2>&1 | sed 's/^/    /'

if [[ $INSTALL -eq 1 ]]; then
  echo "==> Installing to /Applications"
  DEST="/Applications/$APP_NAME.app"
  if rm -rf "$DEST" 2>/dev/null && cp -R "$APP" "$DEST" 2>/dev/null; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST" 2>/dev/null || true
    echo "    ✓ installed: $DEST"
  else
    echo "    ! could not write to /Applications (permissions). App is still at: $APP"
  fi
fi

echo "==> Done: $APP"
