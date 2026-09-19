#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/Applications"
RUN_TESTS=true
LAUNCH=true

die() {
    echo "$1" >&2
    exit 1
}

require_safe_install_dir() {
    local dir="$1"

    [[ -n "$dir" ]] || die "Install directory must not be empty."
}

resolve_install_dir() {
    local dir="$1"
    local resolved

    require_safe_install_dir "$dir"
    mkdir -p "$dir"
    resolved="$(/bin/realpath "$dir")" || die "Unable to resolve install directory: $dir"
    [[ "$resolved" != "/" ]] || die "Refusing to install to /."
    printf '%s\n' "$resolved"
}

safe_remove_tree() {
    local path="$1"
    local scope="$2"

    [[ -n "$path" ]] || die "Refusing to remove an empty path."
    [[ "$path" != "/" ]] || die "Refusing to remove /."
    [[ -n "$scope" ]] || die "Removal scope must not be empty."
    [[ "$path" == "$scope/"* ]] || die "Refusing to remove path outside $scope: $path"

    [[ -e "$path" ]] || return 0
    rm -rf -- "$path"
}

while (($#)); do
    case "$1" in
        --skip-tests)
            RUN_TESTS=false
            shift
            ;;
        --no-launch)
            LAUNCH=false
            shift
            ;;
        --install-dir)
            test $# -ge 2 || die "Missing value for --install-dir"
            INSTALL_DIR="$2"
            shift 2
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
done

INSTALL_DIR="$(resolve_install_dir "$INSTALL_DIR")"

if $RUN_TESTS; then
    (
        cd "$ROOT"
        GIT_CONFIG_COUNT=1 \
        GIT_CONFIG_KEY_0=safe.bareRepository \
        GIT_CONFIG_VALUE_0=all \
            swift test
    )
fi

"$ROOT/scripts/package-app.sh"
mkdir -p "$INSTALL_DIR"

TARGET="$INSTALL_DIR/Echofloat.app"
STAGING="$INSTALL_DIR/.Echofloat.installing.$$"
BACKUP="$INSTALL_DIR/.Echofloat.backup.$$"

cleanup() {
    local status=$?

    if [[ -d "$STAGING" ]]; then
        safe_remove_tree "$STAGING" "$INSTALL_DIR"
    fi

    if [[ -e "$BACKUP" && ! -e "$TARGET" ]]; then
        mv "$BACKUP" "$TARGET"
    fi

    exit "$status"
}
trap cleanup EXIT

/usr/bin/osascript -e 'tell application id "com.echofloat.app" to quit' \
    >/dev/null 2>&1 || true

/usr/bin/ditto "$ROOT/dist/Echofloat.app" "$STAGING"
/usr/bin/codesign --verify --deep --strict "$STAGING"

if [[ -e "$TARGET" ]]; then
    mv "$TARGET" "$BACKUP"
fi

mv "$STAGING" "$TARGET"
safe_remove_tree "$BACKUP" "$INSTALL_DIR"
trap - EXIT

if $LAUNCH; then
    /usr/bin/open "$TARGET"
fi

echo "Echofloat installed at $TARGET"
echo
echo "For YouTube Music:"
echo "1. In Chrome, enable View > Developer > Allow JavaScript from Apple Events."
echo "2. When macOS asks, allow Echofloat to automate Google Chrome."
