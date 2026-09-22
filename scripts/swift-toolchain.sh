#!/bin/bash

swift_version_from_output() {
    printf '%s\n' "$1" |
        /usr/bin/sed -nE 's/.*Swift version ([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/p' |
        /usr/bin/head -n 1
}

detect_swift_version() {
    local output
    local version

    command -v swift >/dev/null 2>&1 || return 1
    output="$(swift --version 2>&1)" || return 1
    version="$(swift_version_from_output "$output")"
    [[ -n "$version" ]] || return 1
    printf '%s\n' "$version"
}

swift_version_at_least() {
    local version="$1"
    local required_major="$2"
    local required_minor="$3"
    local major
    local minor

    [[ "$version" =~ ^([0-9]+)\.([0-9]+)(\.[0-9]+)?$ ]] || return 1
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"

    ((major > required_major)) ||
        ((major == required_major && minor >= required_minor))
}

swift_supports_install() {
    swift_version_at_least "$1" 5 9
}

swift_supports_full_tests() {
    swift_version_at_least "$1" 6 1
}
