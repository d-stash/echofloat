#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$ROOT/.build/release-script-tests"
rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT"
trap 'rm -rf "$TMP_ROOT"' EXIT

GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0=safe.bareRepository \
GIT_CONFIG_VALUE_0=all \
    "$ROOT/scripts/publish-release.sh" --output-dir "$TMP_ROOT" --dry-run

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
ZIP="$TMP_ROOT/Echofloat-$VERSION.zip"
APPCAST="$TMP_ROOT/appcast.xml"

test -f "$ZIP"
test -f "$APPCAST"
grep -q "Echofloat-$VERSION.zip" "$APPCAST"
grep -q "sparkle:version=\"$VERSION\"" "$APPCAST"
grep -q "sparkle:edSignature=\"dry-run-placeholder-signature\"" "$APPCAST"
xmllint --noout "$APPCAST"

echo "Release script checks passed"
