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

# Refuse to wipe regtest data while a regtest node is using this datadir: on
# Unix "rm -rf" deletes files held open by the running process and corrupts it.
if pgrep -f -i -- "-datadir=${ROOTDIR}/bitcoin-datadir -regtest" >/dev/null 2>&1
then
    echo "Error: a regtest Bitcoin process is using ${ROOTDIR}/bitcoin-datadir."
    echo "Stop it before a clean start."
    exit 1
fi

echo "WARNING: This will delete regtest data."
echo "Press Enter to continue or Ctrl+C to cancel."
read

rm -rf "${ROOTDIR}/bitcoin-datadir/regtest"

BASENAME="$(basename "$0")"
FILENAME="${BASENAME%.*}"
"$BTC_QT" \
  -uacomment="${FILENAME}" \
  -datadir="${ROOTDIR}/bitcoin-datadir" \
  -regtest \
  -addnode=localhost:18555 \
  -addnode=localhost:18666
