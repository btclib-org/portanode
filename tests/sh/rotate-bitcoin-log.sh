# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# shellcheck disable=SC2329 # check calls these functions by name
# What the macOS and Linux rotate-bitcoin-log move, keep and remove, and
# where each stops. Each runs from the checkout against a folder of its own
# named by PORTANODE_ROOT; a failing mv or cp is a stand-in placed before the
# PATH it runs with.

case "$0" in */*) ;; *) [ -f "$0" ] || {
    echo "$0: run this script by its path, not by a name found through PATH" >&2
    exit 1
} ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'chmod -R u+w "$TMP" 2> /dev/null; rm -rf "$TMP"' EXIT

ROOT="$TMP/root"
LOG="$ROOT/bitcoin-datadir/debug.log"
for tool in mv cp; do
    mkdir -p "$TMP/$tool-fails"
    printf '#!/bin/sh\nexit 1\n' > "$TMP/$tool-fails/$tool"
    chmod +x "$TMP/$tool-fails/$tool"
done

# fresh [n]...: a folder whose debug.log holds "now", with debug.log.<n>
# holding "<n>" for each n given, and a recorded offset.
fresh() {
    local n
    rm -rf "$ROOT"
    mkdir -p "$ROOT/linux" "$ROOT/macos" "$ROOT/bitcoin-datadir"
    touch "$ROOT/VERSION"
    echo now > "$LOG"
    for n; do
        echo "$n" > "$LOG.$n"
    done
    echo 4 > "$ROOT/.last_log_offset"
}

# rotate <platform> [dir]: runs that platform's rotate-bitcoin-log, with
# <dir> before the PATH where given, stdout and stderr together, then
# "exit <status>".
rotate() {
    local status=0
    env PATH="${2:+$2:}$PATH" PORTANODE_ROOT="$ROOT" \
        "$BASH" "$REPO/$1/scripts/utilities/rotate-bitcoin-log.sh" 2>&1 \
        || status=$?
    echo "exit $status"
}

# holds: each debug.log.<n>'s content, "-" where it is missing, then
# debug.log's, then whether the offset is kept.
holds() {
    local n out=""
    for n in 1 2 3 4 5 6; do
        out="$out$(cat "$LOG.$n" 2> /dev/null || echo -) "
    done
    out="${out}[$(cat "$LOG")]"
    [ -e "$ROOT/.last_log_offset" ] && out="$out offset"
    printf '%s\n' "$out"
}

for platform in linux macos; do
    fresh
    rm "$LOG"
    check "$platform: without debug.log it says so and succeeds" same \
        'Log file not found: bitcoin-datadir/debug.log'$'\n''exit 0' \
        "$(rotate "$platform")"

    first() {
        fresh
        same 'Log rotated: bitcoin-datadir/debug.log'$'\n''exit 0' \
            "$(rotate "$platform")" \
            && same 'now - - - - - []' "$(holds)"
    }
    check "$platform: a first rotation copies debug.log to .1, empties it and drops the offset" \
        first

    # .5 is the last kept: the .5 before it is overwritten by .4, and nothing
    # becomes .6.
    full() {
        fresh 1 2 3 4 5
        same 'Log rotated: bitcoin-datadir/debug.log'$'\n''exit 0' \
            "$(rotate "$platform")" \
            && same 'now 1 2 3 4 - []' "$(holds)"
    }
    check "$platform: with five kept, each moves up one and the oldest goes" full

    gap() {
        fresh 2
        rotate "$platform" > /dev/null && same 'now - 2 - - - []' "$(holds)"
    }
    check "$platform: a gap in the numbers stays a gap" gap

    mv_fails() {
        fresh 1
        same 'Error: renaming bitcoin-datadir/debug.log.1 failed; debug.log was not rotated.'$'\n''exit 1' \
            "$(rotate "$platform" "$TMP/mv-fails")" \
            && same '1 - - - - - [now] offset' "$(holds)"
    }
    check "$platform: a rename that fails stops before debug.log is touched" \
        mv_fails

    cp_fails() {
        fresh
        same 'Error: copying bitcoin-datadir/debug.log to debug.log.1 failed; debug.log was not rotated.'$'\n''exit 1' \
            "$(rotate "$platform" "$TMP/cp-fails")" \
            && same '- - - - - - [now] offset' "$(holds)"
    }
    check "$platform: a copy that fails leaves debug.log as it was" cp_fails

    # Root writes through a read-only mode, so the case needs another user.
    if [ "$(id -u)" -ne 0 ]; then
        read_only() {
            fresh
            chmod 444 "$LOG"
            local out
            out="$(rotate "$platform")"
            contains "$out" 'Error: emptying bitcoin-datadir/debug.log failed; its content is also in debug.log.1.' \
                && contains "$out" 'exit 1' \
                && same 'now - - - - - [now] offset' "$(holds)"
        }
        check "$platform: a debug.log that cannot be emptied says its content is also in .1" \
            read_only
    else
        echo "ok - SKIP: $platform: a debug.log that cannot be emptied (root writes through its mode)"
    fi
done

finish
