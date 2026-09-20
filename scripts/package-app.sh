#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=swift-toolchain.sh
source "$ROOT/scripts/swift-toolchain.sh"
OUTPUT_DIR="$ROOT/dist"
SKIP_BUILD=false

while (($#)); do
    case "$1" in
        --skip-build) SKIP_BUILD=true; shift ;;
        --output-dir)
            test $# -ge 2 || { echo "Missing value for --output-dir" >&2; exit 64; }
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *) echo "Unknown argument: $1" >&2; exit 64 ;;
    esac
done

test "$(uname -s)" = "Darwin" || { echo "Echofloat requires macOS." >&2; exit 1; }
for tool in swift plutil codesign ditto sips iconutil; do
    command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done
SWIFT_VERSION="$(detect_swift_version)" || {
    echo "Unable to detect Swift. Install Apple Command Line Tools with Swift 5.9 or newer." >&2
    exit 1
}
swift_supports_install "$SWIFT_VERSION" || {
    echo "Echofloat requires Swift 5.9 or newer; found Swift $SWIFT_VERSION." >&2
    exit 1
}

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "VERSION must use semantic version format, for example 0.1.0." >&2
    exit 1
}

cd "$ROOT"
APP_ICON_OUTPUT="$ROOT/Resources/AppIcon.icns" "$ROOT/scripts/generate-icon.sh"
if ! $SKIP_BUILD; then
    swift build -c release --product echofloat
fi
BIN_DIR="$(swift build -c release --show-bin-path)"
test -x "$BIN_DIR/echofloat" || {
    echo "Release executable not found. Run without --skip-build." >&2
    exit 1
}

WORK_DIR="$ROOT/.build/package-app-work"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT

APP="$WORK_DIR/Echofloat.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
/usr/bin/ditto "$BIN_DIR/echofloat" "$APP/Contents/MacOS/echofloat"
/usr/bin/ditto "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
/usr/bin/ditto "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
chmod 755 "$APP/Contents/MacOS/echofloat"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
/usr/bin/codesign --force --deep --sign - "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"

mkdir -p "$OUTPUT_DIR"
TARGET="$OUTPUT_DIR/Echofloat.app"
rm -rf "$TARGET"
/usr/bin/ditto "$APP" "$TARGET"
echo "Created $TARGET"
