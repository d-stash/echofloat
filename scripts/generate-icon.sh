#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/Resources/AppIcon.svg"
OUTPUT_ICNS="${APP_ICON_OUTPUT:-$ROOT/Resources/AppIcon.icns}"
WORK_DIR="$ROOT/.build/iconset"
ICONSET="$WORK_DIR/AppIcon.iconset"

rm -rf "$WORK_DIR"
mkdir -p "$(dirname "$OUTPUT_ICNS")"
mkdir -p "$ICONSET"

for size in 16 32 128 256 512; do
    /usr/bin/sips -s format png -z "$size" "$size" "$SOURCE" \
        --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    /usr/bin/sips -s format png -z "$double" "$double" "$SOURCE" \
        --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

/usr/bin/iconutil -c icns "$ICONSET" -o "$OUTPUT_ICNS"
rm -rf "$WORK_DIR"
echo "Generated $OUTPUT_ICNS"
