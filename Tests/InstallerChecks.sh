#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$ROOT/.build/installer-tests"
HOME_ROOT="$TMP_ROOT/home"
REAL_INSTALL_DIR="$TMP_ROOT/real-apps"
INSTALL_DIR="$TMP_ROOT/link-apps"
ROOT_INSTALL_LINK="$TMP_ROOT/root-apps"
MISSING_PARENT_INSTALL_DIR="$TMP_ROOT/missing-parent/new-apps"
TRAVERSAL_INSTALL_DIR="$TMP_ROOT/traversal-segment/.."
APP="$REAL_INSTALL_DIR/Echofloat.app"
SUPPORT_DIR="$HOME_ROOT/Library/Application Support/Echofloat"
SUPPORT_FILE="$SUPPORT_DIR/LyricsCache/keep.txt"
LAUNCH_AGENT="$HOME_ROOT/Library/LaunchAgents/com.echofloat.autostart.plist"

[[ "$TMP_ROOT" == "$ROOT/.build/"* ]] || {
    echo "Refusing to use unexpected temp root: $TMP_ROOT" >&2
    exit 1
}

rm -rf "$TMP_ROOT"
mkdir -p "$HOME_ROOT" "$REAL_INSTALL_DIR"
ln -s "$REAL_INSTALL_DIR" "$INSTALL_DIR"
ln -s / "$ROOT_INSTALL_LINK"
trap 'rm -rf "$TMP_ROOT"' EXIT

run_with_swiftpm_git_override() {
    GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0=safe.bareRepository \
    GIT_CONFIG_VALUE_0=all \
        "$@"
}

expect_failure() {
    local expected="$1"
    shift
    local output

    if output="$("$@" 2>&1)"; then
        echo "Expected command to fail: $*" >&2
        exit 1
    fi

    case "$output" in
        *"$expected"*) ;;
        *)
            echo "Expected failure output to contain: $expected" >&2
            echo "$output" >&2
            exit 1
            ;;
    esac
}

setup_output="$(
    HOME="$HOME_ROOT" run_with_swiftpm_git_override \
        "$ROOT/setup.sh" --skip-tests --no-launch --install-dir "$INSTALL_DIR"
)"
case "$setup_output" in
    *"Echofloat installed at $REAL_INSTALL_DIR/Echofloat.app"*) ;;
    *)
        echo "Expected canonical install path in setup output" >&2
        echo "$setup_output" >&2
        exit 1
        ;;
esac

test -d "$APP"
test -x "$APP/Contents/MacOS/echofloat"
/usr/bin/codesign --verify --deep --strict "$APP"

mkdir -p "$(dirname "$SUPPORT_FILE")" "$(dirname "$LAUNCH_AGENT")"
echo "keep me" > "$SUPPORT_FILE"
echo "legacy" > "$LAUNCH_AGENT"
HOME="$HOME_ROOT" defaults write com.echofloat.app InstallerCheckValue -string keep-me
echo "old build" > "$APP/Contents/Resources/replaced.txt"

HOME="$HOME_ROOT" run_with_swiftpm_git_override \
    "$ROOT/setup.sh" --skip-tests --no-launch --install-dir "$INSTALL_DIR"
test ! -e "$APP/Contents/Resources/replaced.txt"

uninstall_output="$(
    HOME="$HOME_ROOT" "$ROOT/scripts/uninstall.sh" --install-dir "$INSTALL_DIR"
)"
case "$uninstall_output" in
    *"Echofloat removed from $REAL_INSTALL_DIR/Echofloat.app"*) ;;
    *)
        echo "Expected canonical install path in uninstall output" >&2
        echo "$uninstall_output" >&2
        exit 1
        ;;
esac
test ! -e "$APP"
test -f "$SUPPORT_FILE"
test "$(HOME="$HOME_ROOT" defaults read com.echofloat.app InstallerCheckValue)" = "keep-me"

UNREGISTER_LOG="$TMP_ROOT/unregister.log"
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/MacOS/echofloat" <<'EOF'
#!/bin/bash
printf '%s\n' "$1" > "$UNREGISTER_LOG"
EOF
chmod +x "$APP/Contents/MacOS/echofloat"
HOME="$HOME_ROOT" UNREGISTER_LOG="$UNREGISTER_LOG" \
    "$ROOT/scripts/uninstall.sh" --install-dir "$INSTALL_DIR"
test "$(cat "$UNREGISTER_LOG")" = "--unregister-login-item"
test ! -e "$APP"

mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/MacOS/echofloat" <<'EOF'
#!/bin/bash
echo "simulated unregister failure" >&2
exit 23
EOF
chmod +x "$APP/Contents/MacOS/echofloat"
expect_failure "Failed to unregister Launch at Login" \
    env HOME="$HOME_ROOT" "$ROOT/scripts/uninstall.sh" --install-dir "$INSTALL_DIR"
test -e "$APP"
rm -rf "$APP"

HOME="$HOME_ROOT" run_with_swiftpm_git_override \
    "$ROOT/setup.sh" --skip-tests --no-launch --install-dir "$INSTALL_DIR"
HOME="$HOME_ROOT" "$ROOT/scripts/uninstall.sh" --purge-data --install-dir "$INSTALL_DIR"
test ! -e "$APP"
test ! -e "$SUPPORT_DIR"
test ! -e "$LAUNCH_AGENT"
if HOME="$HOME_ROOT" defaults read com.echofloat.app >/dev/null 2>&1; then
    echo "Expected purge-data to remove com.echofloat.app defaults" >&2
    exit 1
fi

expect_failure "Refusing to install to /." \
    env HOME="$HOME_ROOT" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository \
        GIT_CONFIG_VALUE_0=all "$ROOT/setup.sh" --skip-tests --no-launch \
        --install-dir "$ROOT_INSTALL_LINK"
expect_failure "Refusing to uninstall from /." \
    env HOME="$HOME_ROOT" "$ROOT/scripts/uninstall.sh" --install-dir "$ROOT_INSTALL_LINK"
expect_failure "Refusing to uninstall from /." \
    env HOME="$HOME_ROOT" "$ROOT/scripts/uninstall.sh" --install-dir /
expect_failure "Install directory parent must exist:" \
    env HOME="$HOME_ROOT" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository \
        GIT_CONFIG_VALUE_0=all "$ROOT/setup.sh" --skip-tests --no-launch \
        --install-dir "$MISSING_PARENT_INSTALL_DIR"
test ! -e "$TMP_ROOT/missing-parent"
expect_failure "Install directory basename must not be . or .." \
    env HOME="$HOME_ROOT" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository \
        GIT_CONFIG_VALUE_0=all "$ROOT/setup.sh" --skip-tests --no-launch \
        --install-dir "$TRAVERSAL_INSTALL_DIR"
test ! -e "$TMP_ROOT/traversal-segment"

echo "Installer checks passed"
