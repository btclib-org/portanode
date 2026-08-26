#!/bin/bash
# readlink -f: $0 is the symlink's own path where a launcher is
# started through one, which would send both the source below and
# the root walk into the wrong directory.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd -P)"
# shellcheck source=linux/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
echo ROOTDIR is "${ROOTDIR}"
DATADIR="${ROOTDIR}/bitcoin-datadir/regtest_carol"
NETDIR="${DATADIR}/regtest"
BLOCKCHAINDIR="${NETDIR}/blocks"
# Bitcoin Core creates the wallets subfolder along with the network directory
# itself, and wallet code then uses it; wallet code never creates one, so the
# network directory is the wallet directory only where it already exists
# without a wallets subfolder beside it.
if [ -d "${NETDIR}" ] && [ ! -d "${NETDIR}/wallets" ]; then
    WALLETDIR="${NETDIR}"
else
    WALLETDIR="${NETDIR}/wallets"
fi
echo DATADIR is "${DATADIR}"
echo BLOCKCHAINDIR is "${BLOCKCHAINDIR}"
echo WALLETDIR is "${WALLETDIR}"
BIN_DIR="${ROOTDIR}/linux/bin"
BTC_D="${BIN_DIR}/bitcoind"
BTC_CLI="${BIN_DIR}/bitcoin-cli"

if [ ! -d "$BIN_DIR" ]; then
    echo "Error: Binaries directory not found at $BIN_DIR"
    exit 1
fi

if [ ! -e "$BTC_D" ]; then
    echo "Error: Binary not found at $BTC_D"
    exit 1
fi

if [ ! -x "$BTC_D" ]; then
    echo "Error: Binary not executable at $BTC_D"
    exit 1
fi

mkdir -p "${ROOTDIR}/bitcoin-datadir/regtest_carol"

BASENAME="$(basename "$0")"
FILENAME="${BASENAME%.*}"
# Bitcoin Core's regtest RPC port defaults to 18443 regardless of -port, so
# Alice, Bob and Carol running concurrently would each try to bind RPC on
# 18443 without an explicit -rpcport. This one is Carol's, distinct from
# Alice's default and from Bob's, following the P2P-minus-one spacing
# Bitcoin Core itself uses between a network's own P2P and RPC ports
# (8333/8332, 18333/18332, 18444/18443).
RPCPORT=18665
"$BTC_D" \
  -daemon \
  -uacomment="${FILENAME}" \
  -datadir="${DATADIR}" \
  -regtest \
  -port=18666 \
  -rpcport="${RPCPORT}" \
  -rpcallowip=127.0.0.1 \
  -addnode=localhost:18444 \
  -addnode=localhost:18555

# Linux bitcoind supports -daemon the same way macOS's does, so the daemon
# forks and returns here too, and this window becomes the CLI session
# itself, with btc a function rather than an alias: an alias is flat text
# re-split on every space when expanded, so a ROOTDIR containing one
# breaks it, where a function's "$@" does not.
export BTC_CLI DATADIR RPCPORT
RCFILE="$(mktemp -t portanode-carol-cli-rc.XXXXXX)"
# BTC_CLI, DATADIR and RPCPORT are meant to expand inside the shell this
# rcfile starts, not here: they are read from the exported environment
# above.
# shellcheck disable=SC2016
echo 'btc() { "$BTC_CLI" -regtest -datadir="$DATADIR" -rpcport="$RPCPORT" "$@"; }' > "$RCFILE"
echo "btc is a function for bitcoin-cli on this datadir for this session."
exec bash --rcfile "$RCFILE" -i
