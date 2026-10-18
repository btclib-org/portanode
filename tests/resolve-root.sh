#!/bin/bash
# Tests of resolve_root in shared/lib.sh and of every script that calls it,
# for the macOS and Linux launchers. Run from anywhere:
#
#     bash tests/resolve-root.sh
#
# It needs bash and a POSIX userland, and writes only under a directory it
# makes with mktemp and removes. Exit 0 where every case passes, 1 where
# one fails. win/scripts/root.bat and root.ps1 are not run by it.

set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
failures=0

fail() {
    printf 'FAIL: %s\n' "$*"
    failures=$((failures + 1))
}

# make_root <dir> [<platform dir>...]: a folder marked as a root, holding
# VERSION and the platform directories named.
make_root() {
    local dir="$1"
    shift
    mkdir -p "$dir"
    echo 0.0.0 > "$dir/VERSION"
    local p
    for p in "$@"; do mkdir -p "$dir/$p"; done
}

# shellcheck source=shared/lib.sh
. "$REPO/shared/lib.sh"

make_root "$TMP/good" macos win
make_root "$TMP/good-linux-only" linux
make_root "$TMP/no-platform"
mkdir -p "$TMP/no-version/macos" "$TMP/plain" "$TMP/nested/a/b"
make_root "$TMP/walk" win
mkdir -p "$TMP/walk/x/y"

# expect_root <name> <PORTANODE_ROOT value> <expected output>
expect_root() {
    local name="$1" out rc
    out="$(PORTANODE_ROOT="$2" resolve_root "$TMP/walk/x/y" 2> "$TMP/err")"
    rc=$?
    if [ "$rc" -ne 0 ] || [ "$out" != "$3" ]; then
        fail "$name: status $rc, printed '$out', wanted '$3'"
    fi
}

# expect_refused <name> <PORTANODE_ROOT value>: status 1, nothing on
# stdout, a message on stderr that names the variable and the value.
expect_refused() {
    local name="$1" out rc
    out="$(PORTANODE_ROOT="$2" resolve_root "$TMP/walk/x/y" 2> "$TMP/err")"
    rc=$?
    [ "$rc" -eq 1 ] || fail "$name: status $rc, wanted 1"
    [ -z "$out" ] || fail "$name: printed '$out' on stdout"
    grep -q 'PORTANODE_ROOT' "$TMP/err" || fail "$name: stderr does not name the variable"
    grep -qF -- "$2" "$TMP/err" || fail "$name: stderr does not name the value"
}

good="$(cd "$TMP/good" && pwd -P)"
good_linux="$(cd "$TMP/good-linux-only" && pwd -P)"
walk="$(cd "$TMP/walk" && pwd -P)"

expect_root "PORTANODE_ROOT holding the marker" "$TMP/good" "$good"
expect_root "PORTANODE_ROOT with linux/ alone" "$TMP/good-linux-only" "$good_linux"
expect_refused "PORTANODE_ROOT naming nothing" "$TMP/gone"
expect_refused "PORTANODE_ROOT without VERSION" "$TMP/no-version"
expect_refused "PORTANODE_ROOT without a platform directory" "$TMP/no-platform"
expect_refused "PORTANODE_ROOT naming a plain folder" "$TMP/plain"
expect_refused "PORTANODE_ROOT naming a file" "$TMP/good/VERSION"

# Unset or empty, the walk runs: a root above start_dir is found, and
# with none above it start_dir comes back.
out="$(unset PORTANODE_ROOT; resolve_root "$TMP/walk/x/y")"
[ "$out" = "$walk" ] || fail "walk: printed '$out', wanted '$walk'"
out="$(PORTANODE_ROOT='' resolve_root "$TMP/walk/x/y")"
[ "$out" = "$walk" ] || fail "empty PORTANODE_ROOT walks: printed '$out', wanted '$walk'"
nested="$(cd "$TMP/nested/a/b" && pwd -P)"
out="$(unset PORTANODE_ROOT; resolve_root "$TMP/nested/a/b")"
[ "$out" = "$nested" ] || fail "no root above: printed '$out', wanted '$nested'"

# Every script that calls resolve_root stops on a refused PORTANODE_ROOT
# before it prints a ROOTDIR or builds a path on it. Each runs as a user
# runs it, by its path, with stdin closed.
callers=0
while IFS= read -r f; do
    callers=$((callers + 1))
    out="$(PORTANODE_ROOT="$TMP/gone" bash "$REPO/$f" < /dev/null 2>&1)"
    rc=$?
    [ "$rc" -eq 1 ] || fail "$f: status $rc with a refused PORTANODE_ROOT, wanted 1"
    case "$out" in
        *'ROOTDIR is'*) fail "$f: went on to print ROOTDIR" ;;
    esac
    case "$out" in
        *PORTANODE_ROOT*) ;;
        *) fail "$f: the output does not name PORTANODE_ROOT" ;;
    esac
done < <(git -C "$REPO" grep -l "^ROOTDIR=\"\$(resolve_root" -- '*.sh' '*.command')
[ "$callers" -gt 0 ] || fail "no caller of resolve_root found: the pattern reads nothing"

if [ "$failures" -ne 0 ]; then
    printf '%s failed\n' "$failures"
    exit 1
fi
echo "all passed ($callers callers run)"
