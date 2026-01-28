#!/bin/bash
ROOTDIR="${PORTANODE_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd -P)}"
echo "ROOTDIR is ${ROOTDIR}"
BIN_DIR="${ROOTDIR}/macos/bin"
ELECTRUM_APP="${BIN_DIR}/Electrum.app"
ELECTRUM_MACOS="${ELECTRUM_APP}/Contents/MacOS"
ELECTRUM_RUN="${ELECTRUM_MACOS}/run_electrum"
ELECTRUM_BIN="${ELECTRUM_MACOS}/Electrum"

if [ ! -d "$BIN_DIR" ]; then
    echo "Error: Binaries directory not found at $BIN_DIR"
    exit 1
fi

if [ ! -x "$ELECTRUM_RUN" ] && [ ! -x "$ELECTRUM_BIN" ]; then
    echo "Error: binary not found in $ELECTRUM_MACOS"
    exit 1
fi

open -n "$ELECTRUM_APP" --args \
  --dir "${ROOTDIR}/electrum-datadir" \
  --regtest
