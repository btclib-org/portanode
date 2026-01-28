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

if ps -ax -o command= 2>/dev/null | awk '
  BEGIN { IGNORECASE=1 }
  /bitcoin-qt|bitcoind/ {
    cmd = tolower($0)
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
  -datadir="${ROOTDIR}/bitcoin-datadir"
