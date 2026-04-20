#!/usr/bin/env bash
# Build personal-stt into a proper .app bundle so macOS Info.plist (mic prompt, LSUIElement) is respected.
set -euo pipefail

cd "$(dirname "$0")"

echo "▶ swift build -c release"
swift build -c release

APP="build/personal-stt.app"
BIN="$(swift build -c release --show-bin-path)/PersonalSTT"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/PersonalSTT"
cp Info.plist "$APP/Contents/Info.plist"

echo "▶ rendering icon"
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
swift Tools/MakeIcon.swift "$ICONSET" > /dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# Ad-hoc codesign so TCC (mic / input monitoring / accessibility) remembers the binary identity.
codesign --force --deep --sign - "$APP"

echo "✔ built: $APP"
echo
echo "Install to /Applications (recommended): ./install.sh"
echo "Or run once from Finder: open $APP"
