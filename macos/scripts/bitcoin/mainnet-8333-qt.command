#!/bin/bash
ROOTDIR="${PORTANODE_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd -P)}"
echo ROOTDIR is "${ROOTDIR}"
DATADIR="${ROOTDIR}/bitcoin-datadir"
NETDIR="${DATADIR}"
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

if ps -ax -o command= 2>/dev/null | awk '
  { cmd = tolower($0) }
  cmd ~ /bitcoin-qt|bitcoind/ {
    if (cmd ~ /-testnet/ || cmd ~ /-regtest/ ||
        cmd ~ /-signet/ || cmd ~ /-chain=(testnet|testnet3|regtest|signet)/) {
      next
    }
    found = 1
  }
  END { exit found ? 0 : 1 }
'; then
    echo "Error: A Bitcoin Core mainnet process appears to be running."
    echo "Stop it before starting another mainnet instance (or use a different"
    echo "datadir/ports)."
    exit 1
fi

BASENAME="$(basename "$0")"
FILENAME="${BASENAME%.*}"
"$BTC_QT" \
  -uacomment="${FILENAME}" \
  -datadir="${DATADIR}"
