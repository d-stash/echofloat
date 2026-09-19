#!/bin/bash
set -euo pipefail

INSTALL_DIR="${HOME}/Applications"
PURGE_DATA=false

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
    dir="${dir%/}"
    [[ -n "$dir" ]] || dir="/"

    if [[ -e "$dir" ]]; then
        resolved="$(/bin/realpath "$dir")" || die "Unable to resolve install directory: $dir"
    else
        local parent_dir
        local parent_resolved
        local leaf_name

        parent_dir="$(dirname "$dir")"
        leaf_name="$(basename "$dir")"
        parent_resolved="$(/bin/realpath "$parent_dir")" || die "Unable to resolve install directory: $dir"
        resolved="$parent_resolved/$leaf_name"
    fi

    [[ "$resolved" != "/" ]] || die "Refusing to uninstall from /."
    printf '%s\n' "$resolved"
}

safe_remove_tree() {
    local path="$1"
    local expected="$2"

    [[ -n "$path" ]] || die "Refusing to remove an empty path."
    [[ "$path" != "/" ]] || die "Refusing to remove /."
    [[ "$path" == "$expected" ]] || die "Refusing to remove unexpected path: $path"

    [[ -e "$path" ]] || return 0
    rm -rf -- "$path"
}

safe_remove_file() {
    local path="$1"
    local expected="$2"

    [[ -n "$path" ]] || die "Refusing to remove an empty path."
    [[ "$path" == "$expected" ]] || die "Refusing to remove unexpected file: $path"

    [[ -e "$path" ]] || return 0
    rm -f -- "$path"
}

while (($#)); do
    case "$1" in
        --purge-data)
            PURGE_DATA=true
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

APP_PATH="$INSTALL_DIR/Echofloat.app"
LEGACY_LAUNCH_AGENT="${HOME}/Library/LaunchAgents/com.echofloat.autostart.plist"
APP_SUPPORT_DIR="${HOME}/Library/Application Support/Echofloat"

/usr/bin/osascript -e 'tell application id "com.echofloat.app" to quit' \
    >/dev/null 2>&1 || true

APP_EXECUTABLE="$APP_PATH/Contents/MacOS/echofloat"
if [[ -x "$APP_EXECUTABLE" ]]; then
    "$APP_EXECUTABLE" --unregister-login-item || \
        die "Failed to unregister Launch at Login; the app was not removed."
fi

safe_remove_tree "$APP_PATH" "$APP_PATH"
safe_remove_file "$LEGACY_LAUNCH_AGENT" "$LEGACY_LAUNCH_AGENT"

if $PURGE_DATA; then
    safe_remove_tree "$APP_SUPPORT_DIR" "$APP_SUPPORT_DIR"
    HOME="$HOME" defaults delete com.echofloat.app >/dev/null 2>&1 || true
fi

echo "Echofloat removed from $APP_PATH"
