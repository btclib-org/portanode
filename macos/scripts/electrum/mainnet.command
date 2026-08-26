#!/bin/bash
# readlink -f: $0 is the symlink's own path where a launcher is
# started through one, which would send both the source below and
# the root walk into the wrong directory.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd -P)"
# shellcheck source=macos/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
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
  --dir "${ROOTDIR}/electrum-datadir"
