# shellcheck shell=bash
# The launchers at the root, as macOS and Linux run them: each opens the
# menu of the platform it runs on, and leaves it on 0 or an empty line. No
# entry is chosen, so nothing here needs a binary under bin/.

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

unset PORTANODE_ROOT
TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

# run <input> <launcher> [bash argument...]: feeds <input> to the launcher
# and prints its output, then its exit status on a line of its own. The
# menu's prompt ends with no newline, hence the one before the status.
run() {
    local input="$1" status
    shift
    printf '%b' "$input" | "$BASH" "$@" 2>&1
    status=$?
    printf '\nexit %s\n' "$status"
}

for name in Bitcoin Electrum Utilities; do
    out="$(run '0\n' "$REPO/$name-Launcher.sh")"
    check "$name-Launcher.sh opens its menu on this checkout's root" \
        contains "$out" "$name Launcher ($REPO)"
    check "$name-Launcher.sh exits 0 on 0" \
        same "exit 0" "$(tail -n 1 <<<"$out")"

    out="$(run '\n' "$REPO/$name-Launcher.sh")"
    check "$name-Launcher.sh exits 0 on an empty line" \
        same "exit 0" "$(tail -n 1 <<<"$out")"
done

out="$(run '99\n0\n' "$REPO/Bitcoin-Launcher.sh")"
check "an unknown entry is refused and the menu shown again" \
    contains "$out" "Invalid selection."

ln -s "$REPO/Bitcoin-Launcher.sh" "$TMP/launcher"
out="$(run '0\n' "$TMP/launcher")"
check "a launcher started through a symlink finds the folder it links into" \
    contains "$out" "Bitcoin Launcher ($REPO)"

# bash looks for a script given by a bare name in the current directory,
# then in PATH.
out="$(cd "$TMP" && PATH="$REPO:$PATH" run '' Bitcoin-Launcher.sh)"
check "a launcher found through PATH refuses to run" \
    contains "$out" "run this script by its path"
check "a launcher found through PATH exits 1" \
    same "exit 1" "$(tail -n 1 <<<"$out")"

finish
