# shellcheck shell=bash
# resolve_root in shared/lib.sh given a PORTANODE_ROOT, and every .sh and
# .command script that calls it. It asks git for those scripts, so it needs
# a git checkout of this tree. tests/sh/resolve-root.sh tests the walk, and
# tests/win/resolve-root.ps1 tests win/scripts/root.bat and root.ps1.

set -u

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"
# shellcheck source=shared/lib.sh
. "$REPO/shared/lib.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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
    check "$name: status 0" same 0 "$rc"
    check "$name: prints the root" same "$3" "$out"
}

# expect_refused <name> <PORTANODE_ROOT value>: status 1, nothing on
# stdout, a message on stderr that names the variable and the value.
expect_refused() {
    local name="$1" out rc err
    out="$(PORTANODE_ROOT="$2" resolve_root "$TMP/walk/x/y" 2> "$TMP/err")"
    rc=$?
    err="$(cat "$TMP/err")"
    check "$name: status 1" same 1 "$rc"
    check "$name: nothing on stdout" same "" "$out"
    check "$name: stderr names the variable" contains "$err" PORTANODE_ROOT
    check "$name: stderr names the value" contains "$err" "$2"
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
check "unset PORTANODE_ROOT walks to the root above" \
    same "$walk" "$(unset PORTANODE_ROOT; resolve_root "$TMP/walk/x/y")"
check "empty PORTANODE_ROOT walks to the root above" \
    same "$walk" "$(PORTANODE_ROOT='' resolve_root "$TMP/walk/x/y")"
nested="$(cd "$TMP/nested/a/b" && pwd -P)"
check "with no root above, the walk returns start_dir" \
    same "$nested" "$(unset PORTANODE_ROOT; resolve_root "$TMP/nested/a/b")"

# Every script that calls resolve_root stops on a refused PORTANODE_ROOT
# before it prints a ROOTDIR or builds a path on it. Each runs as a user
# runs it, by its path, with stdin closed.
callers=0
refusal="$(PORTANODE_ROOT="$TMP/gone" resolve_root "$TMP" 2>&1)"
while IFS= read -r f; do
    callers=$((callers + 1))
    out="$(PORTANODE_ROOT="$TMP/gone" bash "$REPO/$f" < /dev/null 2>&1)"
    rc=$?
    check "$f: exits 1 with a refused PORTANODE_ROOT" same 1 "$rc"
    # The message alone: a caller that went on after it, because its
    # `|| exit 1` is gone, prints or fails with something more.
    # A script under `set -e` stops without it, so the run above cannot
    # tell, and the line is read as well.
    check "$f: the call to resolve_root is followed by || exit 1" \
        grep -q "^ROOTDIR=\"\$(resolve_root \"\$SCRIPT_DIR\")\" || exit 1\$" "$REPO/$f"
    check "$f: prints the refusal alone" same "$refusal" "$out"
done < <(git -C "$REPO" grep -l "^ROOTDIR=\"\$(resolve_root" -- '*.sh' '*.command')
check "callers of resolve_root are found: the pattern reads them" \
    test "$callers" -gt 0

finish
