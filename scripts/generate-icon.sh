#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/Resources/AppIcon.svg"
WORK_DIR="$ROOT/.build/iconset"
ICONSET="$WORK_DIR/AppIcon.iconset"

rm -rf "$WORK_DIR"
mkdir -p "$ICONSET"

for size in 16 32 128 256 512; do
    /usr/bin/sips -s format png -z "$size" "$size" "$SOURCE" \
        --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    /usr/bin/sips -s format png -z "$double" "$double" "$SOURCE" \
        --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

/usr/bin/iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
rm -rf "$WORK_DIR"
echo "Generated Resources/AppIcon.icns"
