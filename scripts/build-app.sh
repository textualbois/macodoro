#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/PomoBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
BINARY_DIR="$ROOT_DIR/.build/release"
BINARY="$BINARY_DIR/PomoBar"

cd "$ROOT_DIR"
mkdir -p "$BINARY_DIR"
swiftc \
  -parse-as-library \
  -target arm64-apple-macosx14.0 \
  -O \
  -o "$BINARY" \
  Sources/PomoBar/*.swift \
  -framework AppKit \
  -framework SwiftUI \
  -framework Combine \
  -framework IOKit

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$BINARY" "$MACOS_DIR/PomoBar"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>PomoBar</string>
  <key>CFBundleIdentifier</key>
  <string>dev.local.PomoBar</string>
  <key>CFBundleName</key>
  <string>PomoBar</string>
  <key>CFBundleDisplayName</key>
  <string>PomoBar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026</string>
</dict>
</plist>
PLIST

echo "Built $APP_DIR"
