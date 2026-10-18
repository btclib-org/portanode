# shellcheck shell=bash
# Tests for the node-detection helpers of shared/lib.sh. Run from anywhere:
#
#   bash shared/tests/node-detection.sh
#
# It exits 0 where every case passes and 1 otherwise. It starts no node and
# reads no process list: each case replaces _process_args with the lines it
# names. It has no shebang and no executable bit, being run rather than
# launched (CLAUDE.md, on the executable bit).

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=shared/lib.sh
. "$TESTS_DIR/../lib.sh"

FAILED=0
CASES=0
PROCS=""

_process_args() {
    printf '%s' "$PROCS"
}

# expect <status> <description> <function> [argument...]: runs the function
# against $PROCS and compares its exit status with <status>.
expect() {
    local want="$1" what="$2" got
    shift 2
    "$@"
    got=$?
    CASES=$((CASES + 1))
    if [ "$got" -ne "$want" ]; then
        FAILED=$((FAILED + 1))
        echo "FAIL: $what (wanted $want, got $got)"
    fi
}

D="/Volumes/My Drive/portanode/bitcoin-datadir"
BIN="/Volumes/My Drive/portanode/macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"

# Alice -clean guard (ISS 661): a regtest node on this datadir is found
# whatever the order or the form of its arguments.
for args in \
    "-datadir=$D -regtest" \
    "-regtest -datadir=$D" \
    "-regtest=1 -datadir=$D" \
    "-datadir=$D -chain=regtest" \
    "-chain=regtest -datadir=$D" \
    "--regtest --datadir=$D" \
    "--chain=regtest --datadir=$D" \
    "-uacomment=x -regtest -rpcport=1 -datadir=$D -listen=0" \
    "-datadir=$D/ -regtest" \
    "-DATADIR=$D -REGTEST"; do
    PROCS="$BIN $args"$'\n'
    expect 0 "regtest node found: $args" regtest_node_running_on "$D"
done

PROCS="/usr/bin/bitcoind -regtest -datadir=$D"$'\n'
expect 0 "bitcoind found" regtest_node_running_on "$D"
expect 0 "datadir with a trailing slash given" regtest_node_running_on "$D/"

for args in \
    "-datadir=$D" \
    "-datadir=$D -testnet" \
    "-datadir=$D -regtest=0" \
    "-datadir=$D/regtest_bob -regtest" \
    "-datadir=$D-regtest" \
    "-datadir=/Volumes/other/bitcoin-datadir -regtest" \
    "-regtest"; do
    PROCS="$BIN $args"$'\n'
    expect 1 "regtest node not found: $args" regtest_node_running_on "$D"
done

PROCS=$'/bin/ls\n/usr/bin/vim notes\n'
expect 1 "no node running" regtest_node_running_on "$D"

# Mainnet check (ISS 662): the network flags count only as whole arguments.
for args in \
    "-datadir=/Volumes/btc-testnet-old" \
    "-datadir=/Volumes/btc-regtest-old/data" \
    "-datadir=/Volumes/btc-signet-old" \
    "-datadir=/Volumes/btc-testnet4-old -uacomment=x" \
    "-datadir=/Volumes/chain=regtest" \
    "-testnet=0" \
    "-datadir=$D" \
    ""; do
    PROCS="$BIN $args"$'\n'
    expect 0 "mainnet node found: $args" mainnet_node_running
done

PROCS="/usr/local/bin/bitcoind -datadir=/Volumes/btc-testnet-old"$'\n'
expect 0 "mainnet bitcoind found" mainnet_node_running

for args in \
    "-testnet" \
    "-testnet=1" \
    "-testnet4" \
    "-regtest" \
    "-signet" \
    "--signet" \
    "-chain=testnet" \
    "-chain=testnet3" \
    "-chain=testnet4" \
    "-chain=regtest" \
    "-chain=signet" \
    "-datadir=/Volumes/btc-testnet-old -regtest" \
    "-REGTEST"; do
    PROCS="$BIN $args"$'\n'
    expect 1 "mainnet node not found: $args" mainnet_node_running
done

PROCS=$'/bin/ls /Volumes/btc-testnet-old\n'
expect 1 "no node running (mainnet)" mainnet_node_running

# A process list that cannot be read answers 2 and not "no node".
_process_args() {
    return 1
}
expect 2 "unreadable list (regtest guard)" regtest_node_running_on "$D"
expect 2 "unreadable list (mainnet)" mainnet_node_running
expect 2 "unreadable list (process_running_with)" process_running_with x

echo "$((CASES - FAILED)) of $CASES passed"
[ "$FAILED" -eq 0 ]
