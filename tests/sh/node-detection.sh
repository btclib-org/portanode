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
    "-DATADIR=$D -REGTEST"; do
    PROCS="$BIN $args"$'\n'
    check "regtest node found: $args" answers 0 regtest_node_running_on "$D"
done

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
    "-REGTEST"; do
    PROCS="$BIN $args"$'\n'
    check "mainnet node not found: $args" answers 1 mainnet_node_running
done

PROCS=$'/bin/ls /Volumes/btc-testnet-old\n'
check "no node running (mainnet)" answers 1 mainnet_node_running

# A process list that cannot be read answers 2 and not "no node".
_process_args() {
    return 1
}
check "unreadable list (regtest guard)" answers 2 regtest_node_running_on "$D"
check "unreadable list (mainnet)" answers 2 mainnet_node_running
check "unreadable list (process_running_with)" answers 2 process_running_with x

finish
