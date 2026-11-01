# shellcheck shell=bash
# shellcheck disable=SC2329 # check calls these functions by name
# The sync line of the macOS and Linux health-checks, run in a copy of the
# tree with a PATH of its own. bitcoin-cli, jq and pgrep are stand-ins, and bc
# is the machine's where it has one.

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

ROOT="$TMP/root"
mkdir -p "$ROOT/shared" "$ROOT/bitcoin-datadir"
touch "$ROOT/VERSION"
cp "$REPO/shared/lib.sh" "$ROOT/shared/"
for platform in linux macos; do
    mkdir -p "$ROOT/$platform/scripts/utilities"
    cp "$REPO/$platform/scripts/lib.sh" "$ROOT/$platform/scripts/"
    cp "$REPO/$platform/scripts/utilities/health-check.sh" \
        "$ROOT/$platform/scripts/utilities/"
done

# stand_in <dir> <name> <body>: writes an executable sh script.
stand_in() {
    printf '#!/bin/sh\n%s\n' "$3" > "$1/$2"
    chmod +x "$1/$2"
}

NO_BC="$TMP/no-bc"
mkdir -p "$NO_BC"
for tool in awk cat df dirname grep ps; do
    ln -s "$(command -v "$tool")" "$NO_BC/$tool"
done
stand_in "$NO_BC" bitcoin-cli "echo '{}'"
# shellcheck disable=SC2016 # the stand-in expands it
stand_in "$NO_BC" jq 'printf "%s\n" "$PORTANODE_TEST_SYNC"'
stand_in "$NO_BC" pgrep 'exit 1'

# with_bc <name> [body]: prints a PATH directory holding every tool above and
# a bc with that body, or the machine's bc where no body is given. Without
# one, an awk multiplies as bc does.
with_bc() {
    local dir="$TMP/$1"
    mkdir -p "$dir"
    cp -PR "$NO_BC"/. "$dir/"
    if [ -n "${2:-}" ]; then
        stand_in "$dir" bc "$2"
    elif command -v bc >/dev/null 2>&1; then
        ln -s "$(command -v bc)" "$dir/bc"
    else
        stand_in "$dir" bc "LC_ALL=C exec awk '{ printf \"%.4f\\n\", \$1 * \$3 }'"
    fi
    printf '%s\n' "$dir"
}

BC="$(with_bc bc)"
BC_FAILS="$(with_bc bc-fails 'exit 1')"
BC_SILENT="$(with_bc bc-silent 'exit 0')"
BC_ERROR="$(with_bc bc-error 'echo "(standard_in) 1: syntax error"')"
BC_PARTIAL="$(with_bc bc-partial 'echo 50; exit 1')"

# comma_locale: prints a locale whose decimal separator is a comma; 1 where
# the machine has none.
comma_locale() {
    local loc
    for loc in it_IT.UTF-8 de_DE.UTF-8; do
        if [ "$(LC_ALL=$loc "$BASH" -c 'printf "%.1f" 1' 2>/dev/null)" = "1,0" ]; then
            printf '%s\n' "$loc"
            return 0
        fi
    done
    return 1
}

# health_check <platform> <path> <progress> <locale>: runs the health-check.
health_check() {
    env -i PATH="$2" PORTANODE_TEST_SYNC="$3" LC_ALL="$4" LOCPATH="${LOCPATH:-}" \
        "$BASH" "$ROOT/$1/scripts/utilities/health-check.sh"
}

# reads <expected> <platform> <path> <progress> <locale>: the sync line is
# "Bitcoin sync: <expected>".
reads() {
    local want="$1" out
    shift
    out="$(health_check "$@" 2>/dev/null)"
    same "Bitcoin sync: $want" "$(printf '%s\n' "$out" | grep '^Bitcoin sync')"
}

# says_nothing <platform> <path> <progress> <locale>: stderr is empty.
says_nothing() {
    same "" "$(health_check "$@" 2>&1 >/dev/null)"
}

# Where the machine has no such locale, one is built for this file. glibc
# then reads locales from LOCPATH, which is why it is set only here.
if ! COMMA="$(comma_locale)"; then
    export LOCPATH="$TMP/locales"
    mkdir -p "$LOCPATH"
    if command -v localedef >/dev/null 2>&1; then
        localedef -i it_IT -f UTF-8 "$LOCPATH/it_IT.UTF-8" >/dev/null 2>&1
    fi
    COMMA="$(comma_locale)" || COMMA=""
fi

for platform in linux macos; do
    check "$platform: a node at 0.9999 reads 99.99%" \
        reads 99.99% "$platform" "$BC" 0.9999 C
    check "$platform: a node at 1 reads 100.00%" \
        reads 100.00% "$platform" "$BC" 1 C
    # jq prints a small number with an exponent, in a form that depends on
    # its version.
    check "$platform: a node at 9.7E-9 reads 0.00%" \
        reads 0.00% "$platform" "$BC" 9.7E-9 C
    check "$platform: a node at 1.2e-05 reads 0.00%" \
        reads 0.00% "$platform" "$BC" 1.2e-05 C
    for progress in abc nan -nan inf 1e999 0x10 1.5 -0.1; do
        check "$platform: a progress of $progress reads unknown" \
            reads unknown "$platform" "$BC" "$progress" C
    done

    check "$platform: no bc reads unknown" \
        reads unknown "$platform" "$NO_BC" 0.9999 C
    check "$platform: no bc is not an error on stderr" \
        says_nothing "$platform" "$NO_BC" 0.9999 C
    check "$platform: a bc that fails reads unknown" \
        reads unknown "$platform" "$BC_FAILS" 0.9999 C
    check "$platform: a bc that prints nothing reads unknown" \
        reads unknown "$platform" "$BC_SILENT" 0.9999 C
    check "$platform: a bc that prints a number and fails reads unknown" \
        reads unknown "$platform" "$BC_PARTIAL" 0.9999 C
    check "$platform: a bc that prints an error and exits 0 reads unknown" \
        reads unknown "$platform" "$BC_ERROR" 0.9999 C

    if [ -n "$COMMA" ]; then
        check "$platform: under $COMMA a node at 0.9999 reads 99.99%" \
            reads 99.99% "$platform" "$BC" 0.9999 "$COMMA"
        check "$platform: under $COMMA no bc reads unknown" \
            reads unknown "$platform" "$NO_BC" 0.9999 "$COMMA"
    else
        echo "ok - SKIP: $platform: the cases that need a comma-decimal locale (this machine has none and cannot build one)"
    fi
done

finish
