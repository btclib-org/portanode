#!/bin/bash
ROOTDIR="${PORTANODE_ROOT:-$(dirname "$0")/../../..}"
echo ROOTDIR is "${ROOTDIR}"

if [ ! -d "${ROOTDIR}/macos/bin" ]; then
    echo "Error: Binaries directory not found at ${ROOTDIR}/macos/bin"
    exit 1
fi

if [ ! -x "${ROOTDIR}/macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" ]; then
    echo "Error: Binary not executable at ${ROOTDIR}/macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"
    exit 1
fi

echo "WARNING: This will delete regtest data. Press Enter to continue or Ctrl+C to cancel"
read

rm -rf "${ROOTDIR}/bitcoin-datadir/regtest"

BASENAME="$(basename "$0")"
FILENAME="${BASENAME%.*}"
"${ROOTDIR}/macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" -uacomment="${FILENAME}" \
-datadir="${ROOTDIR}/bitcoin-datadir" -regtest -addnode=localhost:18555 -addnode=localhost:18666
