# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# Assertions for the test files under tests/sh/. tests/README.md says how a
# test file uses them.

TESTS_FAILED=0

# check <description> <command> [argument...]: runs the command in a
# subshell, so that an exit or a changed variable stays there, and reports
# the case as passed where it exits 0.
check() {
    local what="$1"
    shift
    if ("$@"); then
        echo "ok - $what"
    else
        echo "not ok - $what"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# same <expected> <actual>: 0 where the two are equal, otherwise 1 with both
# printed.
same() {
    [ "$1" = "$2" ] && return 0
    printf '  expected: %s\n  actual:   %s\n' "$1" "$2"
    return 1
}

# contains <text> <part>: 0 where <part> occurs in <text>, otherwise 1 with
# both printed.
contains() {
    case "$1" in
        *"$2"*) return 0 ;;
    esac
    printf '  wanted:   %s\n  in:       %s\n' "$2" "$1"
    return 1
}

# finish: exits 0 where every case passed, 1 otherwise.
finish() {
    [ "$TESTS_FAILED" -eq 0 ] || exit 1
    exit 0
}
