#!/usr/bin/env bash
# Build (if needed) + install personal-stt into /Applications.
set -euo pipefail

cd "$(dirname "$0")"

SRC="build/personal-stt.app"
DST="/Applications/personal-stt.app"

if [ ! -d "$SRC" ]; then
    echo "▶ no build found — building first..."
    ./build.sh
fi

if pgrep -x PersonalSTT > /dev/null 2>&1; then
    echo "▶ stopping running personal-stt…"
    killall PersonalSTT 2>/dev/null || true
    sleep 1
fi

if [ -d "$DST" ]; then
    echo "▶ removing previous install at $DST"
    rm -rf "$DST"
fi

echo "▶ installing to $DST"
if [ -w "/Applications" ]; then
    cp -R "$SRC" "$DST"
else
    sudo cp -R "$SRC" "$DST"
fi

echo "✔ installed at $DST"
echo
echo "⚠ First launch will re-prompt for Microphone, Input Monitoring, and"
echo "  Accessibility — macOS treats /Applications/ as a new location vs the"
echo "  build/ dir, so the TCC database asks again. Grant all three."
echo
echo "▶ launching…"
open "$DST"
