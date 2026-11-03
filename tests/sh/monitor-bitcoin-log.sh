# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# The lines the macOS and Linux log monitors print, with escape_controls in
# shared/lib.sh. Both monitors run on either system: a stand-in stat answers
# the size whichever spelling of stat it is given.

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin"
# shellcheck disable=SC2016 # the stand-in expands it
printf '#!/bin/sh\nfor f; do :; done\nwc -c < "$f" | tr -d " "\n' \
    > "$TMP/bin/stat"
chmod +x "$TMP/bin/stat"

# report <platform> <line>: prints what that platform's monitor reports for
# a debug.log holding the line, which printf writes from its escapes.
report() {
    local root="$TMP/$1"
    rm -rf "$root"
    mkdir -p "$root/$1" "$root/bitcoin-datadir"
    touch "$root/VERSION"
    # shellcheck disable=SC2059 # the line holds the escapes printf reads
    printf "$2\n" > "$root/bitcoin-datadir/debug.log"
    PATH="$TMP/bin:$PATH" PORTANODE_ROOT="$root" "$BASH" \
        "$REPO/$1/scripts/utilities/monitor-bitcoin-log.sh" --no-notify
}

TITLE='Bitcoin log errors detected:'
# Between them the lines hold the first and last character of each range,
# and each target sits between other text. A NUL has a line of its own: grep
# without -a would report the whole log as binary.
for platform in linux macos; do
    check "$platform: C0 prints as \\xHH" same \
        "$TITLE"$'\n''ERROR c0 \x01\x09\x0d\x1b[31m\x1f end' \
        "$(report "$platform" 'ERROR c0 \001\t\r\033[31m\037 end')"
    check "$platform: NUL prints as \\x00" same \
        "$TITLE"$'\n''ERROR nul \x00 end' \
        "$(report "$platform" 'ERROR nul \000 end')"
    check "$platform: DEL prints as \\x7f" same \
        "$TITLE"$'\n''ERROR del \x7f end' \
        "$(report "$platform" 'ERROR del \177 end')"
    check "$platform: C1 prints as \\u00HH" same \
        "$TITLE"$'\n''ERROR c1 \u0080\u009b\u009f end' \
        "$(report "$platform" 'ERROR c1 \302\200\302\233\302\237 end')"
    check "$platform: the characters around the ranges print unchanged" same \
        "$TITLE"$'\n''ERROR plain ~ '$'\302\240 \303\251 \342\202\254'' end' \
        "$(report "$platform" 'ERROR plain ~ \302\240 \303\251 \342\202\254 end')"
    check "$platform: a carriage return ending a line is dropped" same \
        "$TITLE"$'\n''ERROR crlf' \
        "$(report "$platform" 'ERROR crlf\r')"
done

finish
