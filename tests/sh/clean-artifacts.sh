# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# shellcheck disable=SC2329 # check calls these functions by name
# What the macOS and Linux clean-artifacts remove, and what they leave: the
# files and directories its own desktop leaves in the folder go, and so does
# nothing inside the data directories or of the other platform. Each runs
# from the checkout against a folder of its own named by PORTANODE_ROOT.

case "$0" in */*) ;; *) [ -f "$0" ] || {
    echo "$0: run this script by its path, not by a name found through PATH" >&2
    exit 1
} ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

TMP="$(mktemp -d)" || exit 1
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

ROOT="$TMP/root"

# artifacts <platform>: the files, then the directories, its clean-artifacts
# removes, each under the names it is found by.
artifacts() {
    case "$1" in
        linux) echo ".goutputstream-AB12CD|.Trash .Trash-1000" ;;
        macos) echo ".DS_Store ._Bitcoin-Launcher.command|.Spotlight-V100 .Trashes" ;;
        *) return 1 ;;
    esac
}

# fresh <platform>: a folder holding each artifact of every platform at its
# top, in linux/scripts and in both data directories, with a file inside
# each directory, and a file of its own beside them.
fresh() {
    local dir name
    rm -rf "$ROOT"
    mkdir -p "$ROOT/linux/scripts" "$ROOT/macos" "$ROOT/bitcoin-datadir" \
        "$ROOT/electrum-datadir"
    touch "$ROOT/VERSION"
    for dir in . linux/scripts bitcoin-datadir electrum-datadir; do
        for name in .goutputstream-AB12CD .DS_Store ._Bitcoin-Launcher.command; do
            echo x > "$ROOT/$dir/$name"
        done
        for name in .Trash .Trash-1000 .Spotlight-V100 .Trashes; do
            mkdir -p "$ROOT/$dir/$name/inside"
            echo x > "$ROOT/$dir/$name/inside/file"
        done
        echo keep > "$ROOT/$dir/keep.txt"
    done
}

# clean <platform>: runs that platform's clean-artifacts, stdout and stderr
# together, then "exit <status>".
clean() {
    local status=0
    env PORTANODE_ROOT="$ROOT" \
        "$BASH" "$REPO/$1/scripts/utilities/clean-artifacts.sh" 2>&1 \
        || status=$?
    echo "exit $status"
}

for platform in linux macos; do
    IFS='|' read -r files dirs <<< "$(artifacts "$platform")"

    fresh
    check "$platform: it says it cleaned and succeeds" same \
        'Cleaning artifacts...'$'\n''Cleanup complete.'$'\n''exit 0' \
        "$(clean "$platform")"

    for dir in . linux/scripts; do
        for name in $files $dirs; do
            check "$platform: $dir/$name is removed" \
                test ! -e "$ROOT/$dir/$name"
        done
    done
    for dir in bitcoin-datadir electrum-datadir; do
        for name in $files $dirs; do
            check "$platform: $dir/$name is left" test -e "$ROOT/$dir/$name"
        done
    done
    for name in $(artifacts linux | tr '|' ' ') \
        $(artifacts macos | tr '|' ' ') keep.txt; do
        case " $files $dirs " in
            *" $name "*) ;;
            *)
                check "$platform: ./$name, not its own, is left" \
                    test -e "$ROOT/$name"
                ;;
        esac
    done
done

# A data directory whose path holds a glob character is still pruned.
bracketed() {
    ROOT="$TMP/[x]/root"
    fresh
    clean macos > /dev/null
    [ -e "$ROOT/bitcoin-datadir/.DS_Store" ] && [ ! -e "$ROOT/.DS_Store" ]
}
check "macos: under a path holding [x] the data directories are left" bracketed

finish
