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

# Ad-hoc codesign so TCC (mic / input monitoring / accessibility) remembers the binary identity.
codesign --force --deep --sign - "$APP"

echo "✔ built: $APP"
echo
echo "Run once from Finder (or: open $APP) — macOS will ask for Microphone, Input Monitoring, Accessibility."
echo "If a prompt doesn't appear: System Settings → Privacy & Security → grant manually."
