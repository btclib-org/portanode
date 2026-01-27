#!/bin/bash
ROOTDIR="${PORTANODE_ROOT:-$(dirname "$0")/../../..}"
echo ROOTDIR is "${ROOTDIR}"
BIN_DIR="${ROOTDIR}/macos/bin"
BTC_QT="${BIN_DIR}/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"

if [ ! -d "$BIN_DIR" ]; then
    echo "Error: Binaries directory not found at $BIN_DIR"
    exit 1
fi

if [ ! -x "$BTC_QT" ]; then
    echo "Error: Binary not executable at $BTC_QT"
    exit 1
fi

echo "WARNING: This will delete regtest data. Press Enter to continue or Ctrl+C to cancel"
read

rm -rf "${ROOTDIR}/bitcoin-datadir/regtest_carol"
mkdir "${ROOTDIR}/bitcoin-datadir/regtest_carol"

BASENAME="$(basename "$0")"
FILENAME="${BASENAME%.*}"
"$BTC_QT" \
  -uacomment="${FILENAME}" \
  -datadir="${ROOTDIR}/bitcoin-datadir/regtest_carol" \
  -regtest \
  -port=18666 \
  -addnode=localhost:18444 \
  -addnode=localhost:18555
