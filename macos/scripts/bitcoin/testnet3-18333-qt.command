#!/bin/bash
ROOTDIR="$(dirname "$0")/../../.."
echo ROOTDIR is "${ROOTDIR}"

BASENAME="$(basename "$0")"
FILENAME="${BASENAME%.*}"
"${ROOTDIR}/macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" \
-uacomment="${FILENAME}" -datadir="${ROOTDIR}/bitcoin-datadir" -testnet
