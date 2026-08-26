#!/bin/bash
# readlink -f: $0 is the symlink's own path where a launcher is
# started through one, which would send both the source below and
# the root walk into the wrong directory.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd -P)"
# shellcheck source=linux/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
echo ROOTDIR is "${ROOTDIR}"
BIN_DIR="${ROOTDIR}/linux/bin"
BTC_QT="${BIN_DIR}/bitcoin-qt"

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
read -r

if ! rm -rf "${ROOTDIR}/bitcoin-datadir/regtest"; then
    echo "Error: could not delete ${ROOTDIR}/bitcoin-datadir/regtest."
    exit 1
fi

DATADIR="${ROOTDIR}/bitcoin-datadir"
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
"$BTC_QT" \
  -uacomment="${FILENAME}" \
  -datadir="${DATADIR}" \
  -regtest \
  -addnode=localhost:18555 \
  -addnode=localhost:18666
