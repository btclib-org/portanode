#!/bin/bash
ROOTDIR="${PORTANODE_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd -P)}"
echo ROOTDIR is "${ROOTDIR}"
BIN_DIR="${ROOTDIR}/macos/bin"
BTC_QT="${BIN_DIR}/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"

if [ ! -d "$BIN_DIR" ]; then
    echo "Error: Binaries directory not found at $BIN_DIR"
    exit 1
fi

if [ ! -e "$BTC_QT" ]; then
    echo "Error: Binary not found at $BTC_QT"
    exit 1
fi

if [ ! -x "$BTC_QT" ]; then
    echo "Error: Binary not executable at $BTC_QT"
    exit 1
fi

DATADIR="${ROOTDIR}/bitcoin-datadir/regtest_bob"

# Refuse to wipe a datadir a node is using: on Unix "rm -rf" deletes files held
# open by the running process, which would corrupt a live node.
if pgrep -f -i -- "-datadir=${DATADIR}" >/dev/null 2>&1; then
    echo "Error: a Bitcoin process is using ${DATADIR}."
    echo "Stop it before a clean start."
    exit 1
fi

echo "WARNING: This will delete regtest data."
echo "Press Enter to continue or Ctrl+C to cancel."
read -r

if ! rm -rf "${DATADIR}"; then
    echo "Error: could not delete ${DATADIR}."
    exit 1
fi
mkdir -p "${DATADIR}"

NETDIR="${DATADIR}/regtest"
BLOCKCHAINDIR="${NETDIR}/blocks"
# Bitcoin Core creates the wallets subfolder along with the network directory
# itself, and wallet code then uses it; wallet code never creates one, so the
# network directory is the wallet directory only where it already exists
# without a wallets subfolder beside it.
# Computed after the wipe above rather than beside the ROOTDIR echo: a network
# directory standing there without a wallets subfolder is the one state that
# answers with the directory itself, and the wipe is what takes that state
# away, so reading it earlier would answer for a directory about to be deleted.
if [ -d "${NETDIR}" ] && [ ! -d "${NETDIR}/wallets" ]; then
    WALLETDIR="${NETDIR}"
else
    WALLETDIR="${NETDIR}/wallets"
fi
echo DATADIR is "${DATADIR}"
echo BLOCKCHAINDIR is "${BLOCKCHAINDIR}"
echo WALLETDIR is "${WALLETDIR}"

BASENAME="$(basename "$0")"
FILENAME="${BASENAME%.*}"
# Bitcoin Core's regtest RPC port defaults to 18443 regardless of -port, so
# Alice, Bob and Carol running concurrently would each try to bind RPC on
# 18443 without an explicit -rpcport. This one is Bob's, distinct from
# Alice's default and from Carol's, following the P2P-minus-one spacing
# Bitcoin Core itself uses between a network's own P2P and RPC ports
# (8333/8332, 18333/18332, 18444/18443).
"$BTC_QT" \
  -uacomment="${FILENAME}" \
  -datadir="${DATADIR}" \
  -regtest \
  -port=18555 \
  -rpcport=18554 \
  -addnode=localhost:18444 \
  -addnode=localhost:18666
