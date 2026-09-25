#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT/dist"
SPARKLE_TOOLS_DIR=""
DRY_RUN=false
DOWNLOAD_URL_BASE="https://github.com/d-stash/echofloat/releases/download"

while (($#)); do
    case "$1" in
        --output-dir)
            test $# -ge 2 || { echo "Missing value for --output-dir" >&2; exit 64; }
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --sparkle-tools-dir)
            test $# -ge 2 || { echo "Missing value for --sparkle-tools-dir" >&2; exit 64; }
            SPARKLE_TOOLS_DIR="$2"
            shift 2
            ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown argument: $1" >&2; exit 64 ;;
    esac
done

if ! $DRY_RUN && [[ -z "$SPARKLE_TOOLS_DIR" ]]; then
    echo "--sparkle-tools-dir is required unless --dry-run is set" >&2
    exit 64
fi

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "VERSION must use semantic version format, for example 0.1.0." >&2
    exit 1
}

mkdir -p "$OUTPUT_DIR"
"$ROOT/scripts/package-app.sh" --output-dir "$OUTPUT_DIR"

APP="$OUTPUT_DIR/Echofloat.app"
ZIP="$OUTPUT_DIR/Echofloat-$VERSION.zip"
rm -f "$ZIP"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
LENGTH="$(stat -f%z "$ZIP")"

if $DRY_RUN; then
    SIGNATURE="dry-run-placeholder-signature"
else
    SIGNATURE="$("$SPARKLE_TOOLS_DIR/bin/sign_update" "$ZIP" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
    test -n "$SIGNATURE" || { echo "sign_update did not produce a signature" >&2; exit 1; }
fi

DOWNLOAD_URL="$DOWNLOAD_URL_BASE/v$VERSION/Echofloat-$VERSION.zip"
PUB_DATE="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"

sed \
    -e "s|__VERSION__|$VERSION|g" \
    -e "s|__PUB_DATE__|$PUB_DATE|g" \
    -e "s|__DOWNLOAD_URL__|$DOWNLOAD_URL|g" \
    -e "s|__SIGNATURE__|$SIGNATURE|g" \
    -e "s|__LENGTH__|$LENGTH|g" \
    "$ROOT/scripts/appcast-template.xml" > "$OUTPUT_DIR/appcast.xml"

echo "Published release artifacts to $OUTPUT_DIR"
