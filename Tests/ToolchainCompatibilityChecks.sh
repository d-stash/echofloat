#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=../scripts/swift-toolchain.sh
source "$ROOT/scripts/swift-toolchain.sh"

test "$(swift_version_from_output 'Apple Swift version 6.3.3 (swiftlang-6.3.3)')" = "6.3.3"
test "$(swift_version_from_output 'Swift version 5.9.2 (swift-5.9.2-RELEASE)')" = "5.9.2"

swift_supports_install "5.9"
swift_supports_install "5.10.1"
if swift_supports_install "5.8.1"; then
    echo "Swift 5.8 must not be accepted for installation." >&2
    exit 1
fi

swift_supports_full_tests "6.1"
swift_supports_full_tests "7.0"
if swift_supports_full_tests "6.0.3"; then
    echo "Swift 6.0 must not select the full test manifest." >&2
    exit 1
fi
if swift_supports_full_tests "5.10.1"; then
    echo "Swift 5.10 must not select the full test manifest." >&2
    exit 1
fi

/usr/bin/grep -Fx '// swift-tools-version: 5.9' "$ROOT/Package.swift"
/usr/bin/grep -Fx '// swift-tools-version: 6.1' "$ROOT/Package@swift-6.1.swift"
if /usr/bin/grep -Eq 'swift-testing|testTarget' "$ROOT/Package.swift"; then
    echo "Base Package.swift must contain only the Swift 5.9 app package." >&2
    exit 1
fi
/usr/bin/grep -F 'exact: "6.2.4"' "$ROOT/Package@swift-6.1.swift"
/usr/bin/grep -F '.testTarget(' "$ROOT/Package@swift-6.1.swift"
/usr/bin/grep -F 'swift_supports_full_tests "$SWIFT_VERSION"' "$ROOT/setup.sh"
/usr/bin/grep -F 'Full tests require Swift 6.1 or newer; skipping tests.' "$ROOT/setup.sh"
/usr/bin/grep -F 'swift_supports_install "$SWIFT_VERSION"' "$ROOT/scripts/package-app.sh"

CHECK_ROOT="$ROOT/.build/toolchain-compatibility"
BASE_ROOT="$CHECK_ROOT/base"
rm -rf "$CHECK_ROOT"
mkdir -p "$BASE_ROOT"
trap 'rm -rf "$CHECK_ROOT"' EXIT

/usr/bin/ditto "$ROOT/Package.swift" "$BASE_ROOT/Package.swift"
/usr/bin/ditto "$ROOT/Sources" "$BASE_ROOT/Sources"
swift package dump-package --package-path "$BASE_ROOT" > "$CHECK_ROOT/base-package.json"
/usr/bin/grep -F '"name" : "echofloat"' "$CHECK_ROOT/base-package.json"
if /usr/bin/grep -F '"type" : "test"' "$CHECK_ROOT/base-package.json"; then
    echo "Base manifest unexpectedly contains a test target." >&2
    exit 1
fi
swift build \
    --package-path "$BASE_ROOT" \
    --scratch-path "$ROOT/.build/toolchain-base-build" \
    --product echofloat

swift package dump-package --package-path "$ROOT" > "$CHECK_ROOT/selected-package.json"
/usr/bin/grep -F '"identity" : "swift-testing"' "$CHECK_ROOT/selected-package.json"
/usr/bin/grep -F '"name" : "echofloatTests"' "$CHECK_ROOT/selected-package.json"

echo "Toolchain compatibility checks passed"
