# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# shellcheck disable=SC2329 # check and shared/lib.sh call these functions by name
# The node-detection helpers of shared/lib.sh, which the Alice -clean
# launchers and the mainnet launchers use to find a running node. It starts
# no node and reads no process list: each case replaces _process_args with
# the lines it names.

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"
# shellcheck source=shared/lib.sh
. "$REPO/shared/lib.sh"

PROCS=""

# the functions of lib.sh call it
_process_args() {
    printf '%s' "$PROCS"
}

# answers <status> <function> [argument...]: 0 where the function, run
# against $PROCS, exits <status>.
answers() {
    local want="$1" got
    shift
    "$@"
    got=$?
    same "$want" "$got"
}

D="/Volumes/My Drive/portanode/bitcoin-datadir"
BIN="/Volumes/My Drive/portanode/macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"

# Alice -clean guard (ISS 661): a regtest node on this datadir is found
# whatever the order or the form of its arguments.
for args in \
    "-datadir=$D -regtest" \
    "-regtest -datadir=$D" \
    "-regtest=1 -datadir=$D" \
    "-regtest=2 -datadir=$D" \
    "-regtest= -datadir=$D" \
    "-regtest=-1 -datadir=$D" \
    "-noregtest=0 -datadir=$D" \
    "-datadir=$D -chain=regtest" \
    "-chain=regtest -datadir=$D" \
    "--regtest --datadir=$D" \
    "--chain=regtest --datadir=$D" \
    "-uacomment=x -regtest -rpcport=1 -datadir=$D -listen=0" \
    "-datadir=$D/ -regtest" \
    "-DATADIR=$D -REGTEST" \
    "-datadir=$D - -regtest"; do
    PROCS="$BIN $args"$'\n'
    check "regtest node found: $args" answers 0 regtest_node_running_on "$D"
done

# ISS 885: the regtest guard reads past a lone "-", where Core stops, so that
# a program path holding " - " cannot hide a regtest node from it.
PROCS="/Volumes/My - Drive/portanode/macos/bin/bitcoind -regtest -datadir=$D"$'\n'
check "regtest node found under /Volumes/My - Drive" answers 0 regtest_node_running_on "$D"

PROCS="/usr/bin/bitcoind -regtest -datadir=$D"$'\n'
check "bitcoind found" answers 0 regtest_node_running_on "$D"
check "datadir with a trailing slash given" answers 0 regtest_node_running_on "$D/"

for args in \
    "-datadir=$D" \
    "-datadir=$D -testnet" \
    "-datadir=$D -regtest=0" \
    "-datadir=$D -regtest=abc" \
    "-datadir=$D -regtest=00" \
    "-datadir=$D -noregtest" \
    "-datadir=$D -noregtest=1" \
    "-datadir=$D -chain=main" \
    "-datadir=$D -chain=regtestx" \
    "-datadir=$D/regtest_bob -regtest" \
    "-datadir=$D-regtest" \
    "-datadir=/Volumes/other/bitcoin-datadir -regtest" \
    "-regtest"; do
    PROCS="$BIN $args"$'\n'
    check "regtest node not found: $args" answers 1 regtest_node_running_on "$D"
done

PROCS=$'/bin/ls\n/usr/bin/vim notes\n'
check "no node running" answers 1 regtest_node_running_on "$D"

# ISS 888: on a datadir that exists, a node's -datadir counts by the
# directory it resolves to. One that is relative or does not resolve
# answers 2.
TMP="$(mktemp -d)" || exit 1
trap 'rm -rf "$TMP"' EXIT
REAL="$TMP/My Drive/portanode/bitcoin-datadir"
mkdir -p "$REAL" "$TMP/My Drive/portanode/x" "$TMP/other" "$TMP/My"
ln -s "$REAL" "$TMP/link"
for args in \
    "-datadir=$TMP/link -regtest" \
    "-regtest -datadir=$TMP/link/" \
    "-DATADIR=$TMP/link -REGTEST" \
    "-Chain=RegTest -datadir=$TMP/link" \
    "-datadir=$TMP/link -noRegTest=0" \
    "--datadir=$TMP/My Drive/portanode/x/../bitcoin-datadir -regtest" \
    "-datadir=/$REAL -regtest" \
    "-datadir=$TMP//My Drive/./portanode/bitcoin-datadir -regtest -listen=0"; do
    PROCS="$BIN $args"$'\n'
    check "regtest node found by its resolved datadir: $args" \
        answers 0 regtest_node_running_on "$REAL"
done
PROCS="$BIN -datadir=$REAL -regtest"$'\n'
check "regtest node found through a link in the datadir given" \
    answers 0 regtest_node_running_on "$TMP/link"
for args in \
    "-datadir=$TMP/other -regtest" \
    "-datadir=$TMP/My Drive/portanode/x -regtest" \
    "-datadir=bitcoin-datadir" \
    "-uacomment=-datadir=bitcoin-datadir -datadir=$TMP/other -regtest" \
    "-regtest -datadir=$TMP/other"; do
    PROCS="$BIN $args"$'\n'
    check "regtest node not found by its resolved datadir: $args" \
        answers 1 regtest_node_running_on "$REAL"
done
for args in \
    "-datadir=bitcoin-datadir -regtest" \
    "-datadir=./bitcoin-datadir -regtest" \
    "-datadir=$TMP/absent -regtest" \
    "-datadir=$TMP/My Drive/absent -regtest"; do
    PROCS="$BIN $args"$'\n'
    check "regtest node whose datadir is not known: $args" \
        answers 2 regtest_node_running_on "$REAL"
done
# "$TMP/My" resolves, but no word starting with "-" follows it.
PROCS="$BIN -datadir=$TMP/My Drive/gone -regtest"$'\n'
check "regtest node whose datadir is not known, with a shorter reading that resolves" \
    answers 2 regtest_node_running_on "$REAL"
# The residual ASSURANCE_CASE.md's *The launcher and its environment* states
# last: "$TMP/other -c" does not exist, so the -datadir reads as
# "$TMP/other", another directory than the guard's.
PROCS="$BIN -datadir=$TMP/other -c -regtest"$'\n'
check "documented residual: a datadir holding \" -\" reads as its part before it" \
    answers 1 regtest_node_running_on "$REAL"
PROCS="$BIN -datadir=bitcoin-datadir -regtest"$'\n'
check "a datadir that does not exist is compared as spelled" \
    answers 1 regtest_node_running_on "$TMP/absent"
check "a datadir under a directory that does not exist is compared as spelled" \
    answers 1 regtest_node_running_on "$TMP/absent/regtest"

# A datadir that may exist and does not resolve: a node with any -datadir
# that does not spell it answers 2, and the spelling still answers 0.
: >"$TMP/file"
ln -s "$TMP/gone" "$TMP/dangling"
for own in "$TMP/file" "$TMP/file/regtest" "$TMP/dangling"; do
    PROCS="$BIN -datadir=$TMP/other -regtest"$'\n'
    check "regtest node on another datadir, the guard's not resolving: $own" \
        answers 2 regtest_node_running_on "$own"
    PROCS="$BIN -datadir=$own -regtest"$'\n'
    check "regtest node on the datadir as spelled, the guard's not resolving: $own" \
        answers 0 regtest_node_running_on "$own"
    for args in "-datadir=$TMP/other" "-regtest"; do
        PROCS="$BIN $args"$'\n'
        check "no regtest node with a -datadir, the guard's not resolving: $own, $args" \
            answers 1 regtest_node_running_on "$own"
    done
done
# A directory that cannot be entered, which root enters all the same.
if [ "$(id -u)" -ne 0 ]; then
    mkdir -p "$TMP/locked/bitcoin-datadir"
    ln -s "$TMP/locked/bitcoin-datadir" "$TMP/to-locked"
    chmod 000 "$TMP/locked"
    PROCS="$BIN -datadir=$TMP/to-locked -regtest"$'\n'
    check "regtest node through a link, the guard's datadir not enterable" \
        answers 2 regtest_node_running_on "$TMP/locked/bitcoin-datadir"
    chmod 755 "$TMP/locked"
else
    echo "ok - skipped: the datadir that cannot be entered (root enters it)"
fi

# Two letters outside ASCII that differ in case: one directory on a volume
# that ignores case, two on one that does not, and the node counts on both.
U=$(printf '\303\211lan')
L=$(printf '\303\251LAN')
mkdir -p "$TMP/$U" "$TMP/$L"
PROCS="$BIN -datadir=$TMP/./$L -regtest"$'\n'
check "regtest node found by its resolved datadir, differing in case outside ASCII" \
    answers 0 regtest_node_running_on "$TMP/$U"

# Without a UTF-8 locale, a datadir that resolves outside ASCII cannot be
# compared as spelled: the same directory answers 0, any other 2.
R=$(printf 'r\303\251el')
mkdir -p "$TMP/$R"
ln -s "$TMP/$R" "$TMP/linkA"
ln -s "$TMP/$R" "$TMP/linkB"
no_utf8() {
    _utf8_locale() { return 1; }
    answers "$@"
}
PROCS="$BIN -datadir=$TMP/linkB -regtest"$'\n'
check "regtest node found through another link, with no UTF-8 locale" \
    no_utf8 0 regtest_node_running_on "$TMP/linkA"
PROCS="$BIN -datadir=$TMP/other -regtest"$'\n'
check "regtest node on another datadir, with no UTF-8 locale" \
    no_utf8 2 regtest_node_running_on "$TMP/linkA"

# macOS pwd -P keeps the NFC or NFD form of a name as it was given, and
# macOS opens the one directory for both.
if [ "$(uname)" = Darwin ]; then
    NFC=$(printf '\303\251t\303\251')
    NFD=$(printf 'e\314\201te\314\201')
    mkdir -p "$TMP/$NFD"
    PROCS="$BIN -datadir=$TMP/$NFC -regtest"$'\n'
    check "regtest node found by its datadir in NFC, the guard's in NFD" \
        answers 0 regtest_node_running_on "$TMP/$NFD"
    PROCS="$BIN -datadir=$TMP/$NFD -regtest"$'\n'
    check "regtest node found by its datadir in NFD, the guard's in NFC" \
        answers 0 regtest_node_running_on "$TMP/$NFC"
else
    echo "ok - skipped: the NFC and NFD cases (they run on macOS only)"
fi

# Mainnet check (ISS 662): the network flags count only as whole arguments.
for args in \
    "-datadir=/Volumes/btc-testnet-old" \
    "-datadir=/Volumes/btc-regtest-old/data" \
    "-datadir=/Volumes/btc-signet-old" \
    "-datadir=/Volumes/btc-testnet4-old -uacomment=x" \
    "-datadir=/Volumes/chain=regtest" \
    "-testnet=0" \
    "-testnet=abc" \
    "-notestnet" \
    "-notestnet=1" \
    "-chain=main" \
    "-chain=testnet" \
    "-chain=testnet3" \
    "-datadir=$D" \
    "-datadir=/d - -regtest" \
    "- -testnet" \
    "- -chain=signet" \
    ""; do
    PROCS="$BIN $args"$'\n'
    check "mainnet node found: $args" answers 0 mainnet_node_running
done

PROCS="/usr/local/bin/bitcoind -datadir=/Volumes/btc-testnet-old"$'\n'
check "mainnet bitcoind found" answers 0 mainnet_node_running

for args in \
    "-testnet" \
    "-testnet=1" \
    "-testnet=2" \
    "-notestnet=0" \
    "-testnet4" \
    "-regtest" \
    "-signet" \
    "--signet" \
    "-chain=test" \
    "-chain=testnet4" \
    "-chain=regtest" \
    "-chain=signet" \
    "-datadir=/Volumes/btc-testnet-old -regtest" \
    "-regtest - -x" \
    "-REGTEST"; do
    PROCS="$BIN $args"$'\n'
    check "mainnet node not found: $args" answers 1 mainnet_node_running
done

PROCS=$'/bin/ls /Volumes/btc-testnet-old\n'
check "no node running (mainnet)" answers 1 mainnet_node_running

PROCS=$'bitcoind -datadir=/Volumes/btc\n'
check "mainnet bare bitcoind found" answers 0 mainnet_node_running
PROCS=$'/usr/local/bin/bitcoind\n'
check "mainnet bitcoind with no argument found" answers 0 mainnet_node_running

# These directory names hold either word and name no node.
for line in \
    "/bin/bash /Volumes/bitcoind-disk/portanode/macos/scripts/bitcoin/mainnet-8333-qt.command" \
    "/bin/bash /Volumes/Bitcoin-Qt/portanode/linux/scripts/bitcoin/mainnet-8333-qt.sh"; do
    PROCS="$line"$'\n'
    check "mainnet node not found: $line" answers 1 mainnet_node_running
done

# A directory name that starts with either word and a space reads as a node:
# a false alarm, on the safe side.
PROCS=$'/bin/bash /Volumes/Bitcoin-Qt Drive/portanode/linux/scripts/bitcoin/mainnet-8333-qt.sh\n'
check "mainnet node found under /Volumes/Bitcoin-Qt Drive" answers 0 mainnet_node_running

# ISS 885: the mainnet check reads no flag after a lone "-", as Core reads
# none. A program path holding " - " then reads as a node with no network
# flag: a false alarm, on the safe side.
PROCS=$'/Volumes/My - Drive/portanode/macos/bin/bitcoind -regtest\n'
check "mainnet node found under /Volumes/My - Drive" answers 0 mainnet_node_running

# A process list that cannot be read answers 2 and not "no node".
_process_args() {
    return 1
}
check "unreadable list (regtest guard)" answers 2 regtest_node_running_on "$D"
check "unreadable list (mainnet)" answers 2 mainnet_node_running
check "unreadable list (process_running_with)" answers 2 process_running_with x

finish
