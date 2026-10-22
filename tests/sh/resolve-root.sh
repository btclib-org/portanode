# shellcheck shell=bash
# resolve_root, in shared/lib.sh.

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"
# shellcheck source=shared/lib.sh
. "$REPO/shared/lib.sh"

unset PORTANODE_ROOT
TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

check "a directory inside this checkout resolves to its root" \
    same "$REPO" "$(resolve_root "$REPO/linux/scripts/bitcoin")"

for platform in macos win linux; do
    root="$TMP/only-$platform"
    mkdir -p "$root/$platform/scripts"
    touch "$root/VERSION"
    check "VERSION and $platform/ alone mark a root" \
        same "$root" "$(resolve_root "$root/$platform/scripts")"
done

mkdir -p "$TMP/outer/win" "$TMP/outer/inner/linux"
touch "$TMP/outer/VERSION" "$TMP/outer/inner/VERSION"
check "the nearest root wins over one further up" \
    same "$TMP/outer/inner" "$(resolve_root "$TMP/outer/inner/linux")"

mkdir -p "$TMP/no-version/linux/scripts"
check "a walk that finds no root returns the directory it started in" \
    same "$TMP/no-version/linux/scripts" \
    "$(resolve_root "$TMP/no-version/linux/scripts")"

mkdir -p "$TMP/version-dir/VERSION" "$TMP/version-dir/linux"
check "a directory named VERSION does not mark a root" \
    same "$TMP/version-dir/linux" "$(resolve_root "$TMP/version-dir/linux")"

mkdir -p "$TMP/elsewhere/win"
touch "$TMP/elsewhere/VERSION"
check "PORTANODE_ROOT naming a PortaNode folder overrides the walk" \
    same "$TMP/elsewhere" \
    "$(PORTANODE_ROOT="$TMP/elsewhere/." resolve_root "$REPO/linux")"

mkdir -p "$TMP/not-a-root"
err="$(PORTANODE_ROOT="$TMP/not-a-root" resolve_root "$REPO/linux" 2>&1 \
    >/dev/null)"
status=$?
check "PORTANODE_ROOT naming no PortaNode folder answers 1" same 1 "$status"
check "PORTANODE_ROOT naming no PortaNode folder is named in the message" \
    contains "$err" "PORTANODE_ROOT is set to \"$TMP/not-a-root\""

finish
