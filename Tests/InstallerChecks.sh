#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$ROOT/.build/installer-tests"
HOME_ROOT="$TMP_ROOT/home"
INSTALL_DIR="$TMP_ROOT/Applications"
APP="$INSTALL_DIR/Echofloat.app"
SUPPORT_DIR="$HOME_ROOT/Library/Application Support/Echofloat"
SUPPORT_FILE="$SUPPORT_DIR/LyricsCache/keep.txt"
LAUNCH_AGENT="$HOME_ROOT/Library/LaunchAgents/com.echofloat.autostart.plist"

[[ "$TMP_ROOT" == "$ROOT/.build/"* ]] || {
    echo "Refusing to use unexpected temp root: $TMP_ROOT" >&2
    exit 1
}

rm -rf "$TMP_ROOT"
mkdir -p "$HOME_ROOT" "$INSTALL_DIR"
trap 'rm -rf "$TMP_ROOT"' EXIT

HOME="$HOME_ROOT" "$ROOT/setup.sh" --skip-tests --no-launch --install-dir "$INSTALL_DIR"

test -d "$APP"
test -x "$APP/Contents/MacOS/echofloat"
/usr/bin/codesign --verify --deep --strict "$APP"

mkdir -p "$(dirname "$SUPPORT_FILE")" "$(dirname "$LAUNCH_AGENT")"
echo "keep me" > "$SUPPORT_FILE"
echo "legacy" > "$LAUNCH_AGENT"
HOME="$HOME_ROOT" defaults write com.echofloat.app InstallerCheckValue -string keep-me
echo "old build" > "$APP/Contents/Resources/replaced.txt"

HOME="$HOME_ROOT" "$ROOT/setup.sh" --skip-tests --no-launch --install-dir "$INSTALL_DIR"
test ! -e "$APP/Contents/Resources/replaced.txt"

HOME="$HOME_ROOT" "$ROOT/scripts/uninstall.sh" --install-dir "$INSTALL_DIR"
test ! -e "$APP"
test -f "$SUPPORT_FILE"
test "$(HOME="$HOME_ROOT" defaults read com.echofloat.app InstallerCheckValue)" = "keep-me"

HOME="$HOME_ROOT" "$ROOT/setup.sh" --skip-tests --no-launch --install-dir "$INSTALL_DIR"
HOME="$HOME_ROOT" "$ROOT/scripts/uninstall.sh" --purge-data --install-dir "$INSTALL_DIR"
test ! -e "$APP"
test ! -e "$SUPPORT_DIR"
test ! -e "$LAUNCH_AGENT"
if HOME="$HOME_ROOT" defaults read com.echofloat.app >/dev/null 2>&1; then
    echo "Expected purge-data to remove com.echofloat.app defaults" >&2
    exit 1
fi

if HOME="$HOME_ROOT" "$ROOT/scripts/uninstall.sh" --install-dir / >/dev/null 2>&1; then
    echo "Expected uninstall guard to reject / install dir" >&2
    exit 1
fi

echo "Installer checks passed"
