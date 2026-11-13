# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# shellcheck disable=SC2329 # check calls these functions by name
# What the macOS and Linux log monitors read from one run to the next, what
# they refuse, and how each notifies. Each runs from the checkout against a
# folder of its own named by PORTANODE_ROOT, with a PATH of links to /bin and
# /usr/bin in which stat, notify-send and osascript are stand-ins, so that
# no case shows a notification. monitor-bitcoin-log.sh has the lines they
# print.

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
LOG="$ROOT/bitcoin-datadir/debug.log"
OFFSET="$ROOT/.last_log_offset"
CALLS="$TMP/calls"
BASE="$TMP/base"
mkdir -p "$BASE"
ln -sf /bin/* /usr/bin/* "$BASE/"
rm -f "$BASE/stat" "$BASE/notify-send" "$BASE/osascript"

# stand_in <dir> <name> <body>: writes an executable sh script.
stand_in() {
    mkdir -p "$1"
    printf '#!/bin/sh\n%s\n' "$3" > "$1/$2"
    chmod +x "$1/$2"
}

# stat answers the size of a file for the size query of the platform under
# test alone, STAT_QUERY: GNU stat refuses BSD's -f%z, and BSD stat GNU's
# -c%s. It fails where STAT_FAILS is set.
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$TMP/stat" stat '[ -z "$STAT_FAILS" ] || exit 1
if [ "$#" -ne 2 ] || [ "$1" != "$STAT_QUERY" ]; then
    echo "stat: not the size query $STAT_QUERY: $*" >&2
    exit 1
fi
wc -c < "$2" | tr -d " "'
# Each notifier records its arguments, one to a line, and exits 2 where it
# is given other than a title and a message, or osascript's -e and a script.
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$TMP/notify" notify-send '[ "$#" -eq 2 ] || exit 2
printf "%s\n" notify-send "$@" >> "$CALLS"'
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$TMP/notify-fails" notify-send '[ "$#" -eq 2 ] || exit 2
printf "%s\n" notify-send "$@" >> "$CALLS"
echo "no daemon" >&2
exit 1'
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$TMP/osascript" osascript '[ "$#" -eq 2 ] && [ "$1" = -e ] || exit 2
printf "%s\n" osascript "$@" >> "$CALLS"'
stand_in "$TMP/tail-fails" tail 'exit 1'

# fresh <line>...: a folder whose debug.log holds those lines.
fresh() {
    rm -rf "$ROOT" "$CALLS"
    mkdir -p "$ROOT/linux" "$ROOT/macos" "$ROOT/bitcoin-datadir"
    touch "$ROOT/VERSION"
    : > "$LOG"
    [ "$#" -eq 0 ] || printf '%s\n' "$@" > "$LOG"
}

# monitor <platform> <path> [argument...]: runs that platform's monitor with
# the stand-in stat answering its size query and the directory <path> before
# the rest, stdout and stderr together, then "exit <status>". NOTIFY_ENV,
# where set, is one NAME=value more for its environment. A
# PORTANODE_NO_NOTIFY the suite inherits is removed from it, so that only
# NOTIFY_ENV sets that variable.
monitor() {
    local platform="$1" dir="$2" status=0
    local query=-c%s
    [ "$platform" = linux ] || query=-f%z
    shift 2
    env -u PORTANODE_NO_NOTIFY ${NOTIFY_ENV:+"$NOTIFY_ENV"} \
        PATH="$dir:$TMP/stat:$BASE" \
        PORTANODE_ROOT="$ROOT" CALLS="$CALLS" STAT_FAILS="${STAT_FAILS:-}" \
        STAT_QUERY="$query" \
        "$BASH" "$REPO/$platform/scripts/utilities/monitor-bitcoin-log.sh" \
        "$@" 2>&1 || status=$?
    echo "exit $status"
}

size() {
    wc -c < "$LOG" | tr -d ' '
}

TITLE='Bitcoin log errors detected:'

for platform in linux macos; do
    fresh
    check "$platform: an argument it does not know is refused" same \
        'Usage: monitor-bitcoin-log.sh [--no-notify]'$'\n''exit 1' \
        "$(monitor "$platform" "$TMP/none" --quiet)"

    fresh
    rm "$LOG"
    check "$platform: without debug.log it says so and succeeds" same \
        'Log file not found: bitcoin-datadir/debug.log'$'\n''exit 0' \
        "$(monitor "$platform" "$TMP/none" --no-notify)"

    first_run() {
        fresh 'start' 'ERROR one' 'Warning two' 'fine' 'FAILED three' \
            'error four' 'warning five' 'failed six'
        same "$TITLE"$'\n''ERROR one'$'\n''Warning two'$'\n''FAILED three'$'\n''error four'$'\n''warning five'$'\n''exit 0' \
            "$(monitor "$platform" "$TMP/none" --no-notify)" \
            && same "$(size)" "$(cat "$OFFSET")"
    }
    check "$platform: a first run prints the first five matches and records the size" \
        first_run

    nothing_new() {
        fresh 'ERROR one'
        monitor "$platform" "$TMP/none" --no-notify > /dev/null
        same 'exit 0' "$(monitor "$platform" "$TMP/none" --no-notify)" \
            && same "$(size)" "$(cat "$OFFSET")"
    }
    check "$platform: a run after it with nothing new prints nothing" \
        nothing_new

    only_new() {
        fresh 'ERROR old'
        monitor "$platform" "$TMP/none" --no-notify > /dev/null
        printf '%s\n' 'quiet' 'ERROR new' >> "$LOG"
        same "$TITLE"$'\n''ERROR new'$'\n''exit 0' \
            "$(monitor "$platform" "$TMP/none" --no-notify)" \
            && same "$(size)" "$(cat "$OFFSET")"
    }
    check "$platform: a run after the log grew prints only what was added" \
        only_new

    no_match() {
        fresh 'all quiet'
        same 'exit 0' "$(monitor "$platform" "$TMP/none")" \
            && same "$(size)" "$(cat "$OFFSET")" \
            && [ ! -e "$CALLS" ]
    }
    check "$platform: a log with no match prints nothing, notifies nothing and records the size" \
        no_match

    shrunk() {
        fresh 'ERROR after rotation'
        echo 100000 > "$OFFSET"
        same "$TITLE"$'\n''ERROR after rotation'$'\n''exit 0' \
            "$(monitor "$platform" "$TMP/none" --no-notify)" \
            && same "$(size)" "$(cat "$OFFSET")"
    }
    check "$platform: an offset past the end of a shorter log reads it from the start" \
        shrunk

    # An empty log is shorter than the offset: the offset goes back to 0 and
    # there is nothing to read.
    emptied() {
        fresh
        echo 50 > "$OFFSET"
        same 'exit 0' "$(monitor "$platform" "$TMP/none" --no-notify)" \
            && same 0 "$(cat "$OFFSET")"
    }
    check "$platform: an emptied log resets the offset to 0" emptied

    for bad in '' 12x -3 ' 7'; do
        not_a_number() {
            fresh 'ERROR kept'
            printf '%s\n' "$bad" > "$OFFSET"
            same "$TITLE"$'\n''ERROR kept'$'\n''exit 0' \
                "$(monitor "$platform" "$TMP/none" --no-notify)"
        }
        check "$platform: an offset of \"$bad\" reads the log from the start" \
            not_a_number
    done

    unreadable() {
        fresh 'ERROR one'
        same 'Error: bitcoin-datadir/debug.log could not be read.'$'\n''exit 1' \
            "$(STAT_FAILS=1 monitor "$platform" "$TMP/none" --no-notify)" \
            && [ ! -e "$OFFSET" ]
    }
    check "$platform: a stat that fails is an error and records nothing" \
        unreadable

    tail_fails() {
        fresh 'ERROR one'
        same 'Error: bitcoin-datadir/debug.log could not be read.'$'\n''exit 1' \
            "$(monitor "$platform" "$TMP/tail-fails" --no-notify)" \
            && [ ! -e "$OFFSET" ]
    }
    check "$platform: a read that fails is an error and records nothing" \
        tail_fails

    # Each notifier the platform's monitor calls: notify-send on Linux, which
    # may also fail, and osascript on macOS.
    notifiers="notify notify-fails"
    [ "$platform" = linux ] || notifiers=osascript
    for notifier in $notifiers; do
        no_notify_env() {
            fresh 'ERROR one'
            same "$TITLE"$'\n''ERROR one'$'\n''exit 0' \
                "$(NOTIFY_ENV=PORTANODE_NO_NOTIFY=1 \
                    monitor "$platform" "$TMP/$notifier")" \
                && [ ! -e "$CALLS" ]
        }
        check "$platform: PORTANODE_NO_NOTIFY=1 keeps $notifier silent" \
            no_notify_env
        no_notify_flag() {
            fresh 'ERROR one'
            same "$TITLE"$'\n''ERROR one'$'\n''exit 0' \
                "$(monitor "$platform" "$TMP/$notifier" --no-notify)" \
                && [ ! -e "$CALLS" ]
        }
        check "$platform: --no-notify keeps $notifier silent" no_notify_flag
    done

    # Another value of PORTANODE_NO_NOTIFY notifies.
    other_value() {
        local notifier=notify
        [ "$platform" = linux ] || notifier=osascript
        fresh 'ERROR one'
        NOTIFY_ENV=PORTANODE_NO_NOTIFY=yes \
            monitor "$platform" "$TMP/$notifier" > /dev/null
        [ -e "$CALLS" ]
    }
    check "$platform: PORTANODE_NO_NOTIFY=yes still notifies" other_value
done

linux_notifies() {
    fresh 'ERROR one'
    same "$TITLE"$'\n''ERROR one'$'\n''exit 0' \
        "$(monitor linux "$TMP/notify")" \
        && same 'notify-send'$'\n''PortaNode Alert'$'\n''Bitcoin errors detected' \
            "$(cat "$CALLS")"
}
check "linux: errors notify through notify-send" linux_notifies

check "linux: without notify-send the printed errors are the report" same \
    "$TITLE"$'\n''ERROR one'$'\n''Note: notify-send not found; the errors above are the report.'$'\n''exit 0' \
    "$(fresh 'ERROR one' && monitor linux "$TMP/none")"

check "linux: a notify-send that fails says the printed errors are the report" same \
    "$TITLE"$'\n''ERROR one'$'\n''Note: notify-send reached no notification daemon; the errors above are the report.'$'\n''exit 0' \
    "$(fresh 'ERROR one' && monitor linux "$TMP/notify-fails")"

macos_notifies() {
    fresh 'ERROR one'
    same "$TITLE"$'\n''ERROR one'$'\n''exit 0' \
        "$(monitor macos "$TMP/osascript")" \
        && same 'osascript'$'\n''-e'$'\n''display notification "Bitcoin errors detected" with title "PortaNode Alert"' \
            "$(cat "$CALLS")"
}
check "macos: errors notify through osascript" macos_notifies

check "macos: without osascript the printed errors are the whole report" same \
    "$TITLE"$'\n''ERROR one'$'\n''exit 0' \
    "$(fresh 'ERROR one' && monitor macos "$TMP/none")"

finish
