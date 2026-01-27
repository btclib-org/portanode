#!/bin/bash
ROOTDIR="$(dirname "$0")/../../.."
echo ROOTDIR is "${ROOTDIR}"
BIN_DIR="${ROOTDIR}/macos/bin"
BTC_QT="${BIN_DIR}/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"

BASENAME="$(basename "$0")"
FILENAME="${BASENAME%.*}"
"$BTC_QT" \
  -uacomment="${FILENAME}" \
  -datadir="${ROOTDIR}/bitcoin-datadir" \
  -testnet
