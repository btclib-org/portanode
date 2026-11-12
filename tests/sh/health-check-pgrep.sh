# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# shellcheck disable=SC2329 # check calls these functions by name
# What the macOS and Linux health-checks say where pgrep is missing or fails,
# run in a copy of the tree with a PATH of its own. pgrep, ps and bitcoin-cli
# are stand-ins, so that no process of this machine decides a case, except in
# the cases under bitcoind-usb at the end.

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

ROOT="$TMP/root"
DATADIR="$ROOT/bitcoin-datadir"
mkdir -p "$ROOT/shared" "$DATADIR"
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

NO_PGREP="$TMP/no-pgrep"
mkdir -p "$NO_PGREP"
for tool in awk cat df dirname grep; do
    ln -s "$(command -v "$tool")" "$NO_PGREP/$tool"
done
stand_in "$NO_PGREP" ps 'exit 0'

# with_tools <name> [<tool> <body>]...: prints a PATH directory holding the
# tools above and these stand-ins.
with_tools() {
    local dir="$TMP/$1"
    shift
    mkdir -p "$dir"
    cp -PR "$NO_PGREP"/. "$dir/"
    while [ "$#" -gt 0 ]; do
        stand_in "$dir" "$1" "$2"
        shift 2
    done
    printf '%s\n' "$dir"
}

CLI="$(with_tools cli bitcoin-cli "echo '{}'")"
PS_BITCOIN="$(with_tools ps-bitcoin ps 'echo bitcoind')"
PS_ELECTRUM="$(with_tools ps-electrum \
    ps 'echo /Applications/Electrum.app/Contents/MacOS/run_electrum')"
# This pgrep finds a process for the pattern ".", as one that understands
# its options does (pgrep_outside_own_line, in shared/lib.sh).
# shellcheck disable=SC2016 # the stand-in expands it
PGREP_NONE="$(with_tools pgrep-none pgrep 'for a; do :; done
[ "$a" = . ] && echo 1 && exit 0
exit 1')"
PGREP_MATCH="$(with_tools pgrep-match pgrep 'echo 4242')"

# health_check <platform> <path>: runs the health-check.
health_check() {
    env -i PATH="$2" "$BASH" "$ROOT/$1/scripts/utilities/health-check.sh"
}

# prints <platform> <path> <line>...: the health-check prints each line whole.
prints() {
    local out line
    out="$(health_check "$1" "$2" 2>/dev/null)"
    shift 2
    for line in "$@"; do
        printf '%s\n' "$out" | grep -qxF "$line" && continue
        printf '  wanted:   %s\n  in:       %s\n' "$line" "$out"
        return 1
    done
}

# says_nothing <platform> <path>: stderr is empty.
says_nothing() {
    same "" "$(health_check "$1" "$2" 2>&1 >/dev/null)"
}

for platform in linux macos; do
    check "$platform: without pgrep neither process reads as not running" \
        prints "$platform" "$NO_PGREP" \
        "Bitcoin running: unknown (pgrep not found)" \
        "Bitcoin sync: unknown" \
        "Electrum running: unknown (pgrep not found)"
    check "$platform: without pgrep stderr is empty" \
        says_nothing "$platform" "$NO_PGREP"
    check "$platform: without pgrep bitcoin-cli still answers for Bitcoin Core" \
        prints "$platform" "$CLI" \
        "Bitcoin running: yes (bitcoin-cli: $CLI/bitcoin-cli)" \
        "Electrum running: unknown (pgrep not found)"

    # The other passes keep their answers where pgrep is missing.
    : > "$DATADIR/.cookie"
    check "$platform: without pgrep a .cookie still reads as maybe" \
        prints "$platform" "$NO_PGREP" "Bitcoin running: maybe"
    rm -f "$DATADIR/.cookie"
    echo 4242 > "$DATADIR/bitcoind.pid"
    check "$platform: without pgrep a live pid still reads as running" \
        prints "$platform" "$PS_BITCOIN" "Bitcoin running: yes (pid)"
    rm -f "$DATADIR/bitcoind.pid"

    # A pgrep that answers keeps both of its answers.
    check "$platform: a pgrep finding nothing reads as not running" \
        prints "$platform" "$PGREP_NONE" \
        "Bitcoin running: no" \
        "Bitcoin sync: n/a" \
        "Electrum running: no"
    check "$platform: a pgrep finding both reads as running" \
        prints "$platform" "$PGREP_MATCH" \
        "Bitcoin running: yes (pgrep)" \
        "Electrum running: yes (pgrep)"
done

check "macos: without pgrep the ps pass still finds Electrum" \
    prints macos "$PS_ELECTRUM" "Electrum running: yes (ps)"

# A pgrep that fails, one that refuses -i as busybox pgrep does
# (tests/sh/running-guard.sh), or a ps that cannot say whose a process is,
# leaves both answers unknown. Status 3 is what macOS pgrep's manual gives
# for an internal error.
PGREP_FAILS="$(with_tools pgrep-fails pgrep 'exit 2')"
PGREP_FAILS3="$(with_tools pgrep-fails-3 pgrep 'exit 3')"
BUSYBOX="$(with_tools pgrep-busybox pgrep 'echo "pgrep: invalid option -- '"'i'"'" >&2
exit 1')"
PS_FAILS="$(with_tools ps-fails pgrep 'echo 4242' ps 'exit 1')"
for platform in linux macos; do
    while read -r tools what; do
        check "$platform: $what reads as unknown" \
            prints "$platform" "$tools" \
            "Bitcoin running: unknown (pgrep or ps failed)" \
            "Bitcoin sync: unknown" \
            "Electrum running: unknown (pgrep or ps failed)"
    done <<EOF
$PGREP_FAILS a pgrep that fails
$PGREP_FAILS3 a pgrep that fails with status 3
$BUSYBOX a pgrep that refuses -i
$PS_FAILS a match where ps fails
EOF
done

# On macOS, where pgrep finds no Electrum, the ps pass over process names
# decides, so a ps that fails there, or none on PATH, leaves Electrum
# unknown.
# shellcheck disable=SC2016 # the stand-in expands it
PS_FAILS_ONLY="$(with_tools ps-fails-only pgrep 'for a; do :; done
[ "$a" = . ] && echo 1 && exit 0
exit 1' ps 'exit 1')"
check "macos: a ps that fails after pgrep finds no Electrum reads as unknown" \
    prints macos "$PS_FAILS_ONLY" \
    "Electrum running: unknown (pgrep or ps failed)"
# shellcheck disable=SC2016 # the stand-in expands it
NO_PS="$(with_tools no-ps pgrep 'for a; do :; done
[ "$a" = . ] && echo 1 && exit 0
exit 1')"
rm "$NO_PS/ps"
check "macos: without ps, after pgrep finds no Electrum, it reads as unknown" \
    prints macos "$NO_PS" "Electrum running: unknown (ps not found)"

# The Electrum launchers start the bundle with arguments, whichever name
# the bundle ships its executable under. This pgrep matches its pattern
# against that command line, as pgrep -f -i does.
for exe in Electrum run_electrum; do
    printf '%s\n' \
        "/Volumes/PortaNode/macos/bin/Electrum.app/Contents/MacOS/$exe -D /x" \
        > "$TMP/table-$exe"
    tools="$(with_tools "listing-$exe" pgrep "for a; do :; done
grep -Eiq -e \"\$a\" '$TMP/table-$exe' || exit 1
echo 4242")"
    check "macos: $exe started with arguments reads as running" \
        prints macos "$tools" "Electrum running: yes (pgrep)"
done

# A folder whose path holds the node pattern (ISS 836): the health-check's
# own command line matches it, which GNU procps pgrep reports. These cases
# run the health-check of this machine's platform with the real pgrep and
# ps, on a copy of the root under bitcoind-usb. They hold hold_node_lock's
# lock, which keeps them apart from the other test files whose processes
# match the pattern, and a case is skipped where a process outside them
# matches before or after.
BTC_PATTERN="bitcoind|bitcoin-qt|bitcoin qt"
# outside_match: 0 where a process this run did not start matches.
outside_match() {
    pgrep -f -i "$BTC_PATTERN" > /dev/null
}
case "$(uname)" in
    Darwin) platform=macos ;;
    Linux) platform=linux ;;
    *) platform="" ;;
esac
if [ -z "$platform" ]; then
    echo "ok - skipped: the cases under bitcoind-usb (neither macOS nor Linux)"
elif ! command -v pgrep > /dev/null; then
    echo "ok - skipped: the cases under bitcoind-usb (pgrep not found)"
elif hold_node_lock; lock_rc=$?; [ "$lock_rc" -ne 0 ]; then
    case "$lock_rc" in
        1) why="another run held $NODE_LOCK for five minutes" ;;
        2) why="$NODE_LOCK cannot be opened" ;;
        *) why="perl not found" ;;
    esac
    echo "ok - skipped: the cases under bitcoind-usb ($why)"
else
    REAL="$TMP/real"
    mkdir -p "$REAL"
    cp -PR "$NO_PGREP"/. "$REAL/"
    ln -sf "$(command -v pgrep)" "$REAL/pgrep"
    ln -sf "$(command -v ps)" "$REAL/ps"
    cp -R "$ROOT" "$TMP/bitcoind-usb"
    ROOT="$TMP/bitcoind-usb"
    what="$platform: under bitcoind-usb no node reads as not running"
    if outside_match; then
        echo "ok - skipped: $what (a process matching $BTC_PATTERN runs here)"
    else
        out="$(health_check "$platform" "$REAL" 2>/dev/null)"
        if outside_match; then
            echo "ok - skipped: $what (a process matching $BTC_PATTERN runs here)"
        else
            check "$what" contains "$out" "Bitcoin running: no"
        fi
    fi
    # The stand-in ends within 60 seconds, so that a killed run leaves
    # none running for long. It closes descriptor 9, so that the sleep
    # it leaves when it is killed does not hold the lock. The "; :"
    # keeps bash from replacing itself with sleep, which would drop the
    # name.
    "$BASH" -c 'sleep 60; :' bitcoind 9<&- &
    node=$!
    out=""
    if node_listed "$node" "$BTC_PATTERN"; then
        out="$(health_check "$platform" "$REAL" 2>/dev/null)"
    fi
    kill "$node"
    wait "$node" 2> /dev/null
    check "$platform: under bitcoind-usb a running node is found" \
        contains "$out" "Bitcoin running: yes (pgrep)"
fi

finish
