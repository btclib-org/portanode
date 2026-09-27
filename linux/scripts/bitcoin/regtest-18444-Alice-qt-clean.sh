#!/bin/bash
# Portable readlink -f: macOS's own readlink has no -f before 12.3
# (apple-oss-distributions/file_cmds tag file_cmds-352.40.6 vs.
# file_cmds-353.100.22), so $0 -- the symlink's own path where a
# launcher is started through one, which would send both the source
# below and the root walk into the wrong directory -- is resolved a
# link at a time instead.
resolve_symlink() {
  local target="$1" dir
  while [ -L "$target" ]; do
    dir="$(cd -P "$(dirname "$target")" && pwd)"
    target="$(readlink "$target")"
    case "$target" in
      /*) ;;
      *) target="$dir/$target" ;;
    esac
  done
  printf '%s\n' "$target"
}
SCRIPT_DIR="$(cd "$(dirname "$(resolve_symlink "$0")")" && pwd -P)"
# shellcheck source=linux/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
echo ROOTDIR is "${ROOTDIR}"
BIN_DIR="${ROOTDIR}/linux/bin"
BTC_QT="${BIN_DIR}/bitcoin-qt"

if [ ! -d "$BIN_DIR" ]; then
    echo "Error: Binaries directory not found at ${BIN_DIR#"$ROOTDIR"/}"
    exit 1
fi

if [ ! -e "$BTC_QT" ]; then
    echo "Error: Binary not found at ${BTC_QT#"$ROOTDIR"/}"
    exit 1
fi

if [ ! -x "$BTC_QT" ]; then
    echo "Error: Binary not executable at ${BTC_QT#"$ROOTDIR"/}"
    exit 1
fi

# Refuse to wipe regtest data while a regtest node is using this datadir: on
# Unix "rm -rf" deletes files held open by the running process and corrupts it.
process_running_with "-datadir=${ROOTDIR}/bitcoin-datadir -regtest"
case $? in
    0)
        echo "Error: a regtest Bitcoin process is using bitcoin-datadir."
        echo "Stop it before a clean start."
        exit 1
        ;;
    1) ;;
    *)
        echo "Error: could not tell whether a regtest Bitcoin process is"
        echo "using bitcoin-datadir. Nothing has been deleted."
        exit 1
        ;;
esac

echo "WARNING: This will delete regtest data."
echo "Press Enter to continue or Ctrl+C to cancel."
read -r

if ! rm -rf "${ROOTDIR}/bitcoin-datadir/regtest"; then
    echo "Error: could not delete bitcoin-datadir/regtest."
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
