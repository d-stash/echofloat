#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$ROOT/.build/packaging-tests"
rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT"
trap 'rm -rf "$TMP_ROOT"' EXIT

FRESH_ICON="$TMP_ROOT/AppIcon.icns"
APP_ICON_OUTPUT="$FRESH_ICON" "$ROOT/scripts/generate-icon.sh"

"$ROOT/scripts/package-app.sh" --output-dir "$TMP_ROOT"

APP="$TMP_ROOT/Echofloat.app"
PLIST="$APP/Contents/Info.plist"
EXECUTABLE="$APP/Contents/MacOS/echofloat"

test -d "$APP"
test -x "$EXECUTABLE"
test -f "$APP/Contents/Resources/AppIcon.icns"
cmp -s "$FRESH_ICON" "$ROOT/Resources/AppIcon.icns"
cmp -s "$FRESH_ICON" "$APP/Contents/Resources/AppIcon.icns"
/usr/bin/plutil -lint "$PLIST"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")" = "com.echofloat.app"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")" = "echofloat"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST")" = "13.0"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$PLIST")" = "true"
test -n "$(/usr/libexec/PlistBuddy -c 'Print :NSAppleEventsUsageDescription' "$PLIST")"
/usr/bin/codesign --verify --deep --strict "$APP"

echo "Packaging checks passed"
