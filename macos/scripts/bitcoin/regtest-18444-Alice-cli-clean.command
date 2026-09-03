#!/bin/bash
# readlink -f: $0 is the symlink's own path where a launcher is
# started through one, which would send both the source below and
# the root walk into the wrong directory.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd -P)"
# shellcheck source=macos/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
echo ROOTDIR is "${ROOTDIR}"
BIN_DIR="${ROOTDIR}/macos/bin"
BTC_D="${BIN_DIR}/bitcoind"
BTC_CLI="${BIN_DIR}/bitcoin-cli"

if [ ! -d "$BIN_DIR" ]; then
    echo "Error: Binaries directory not found at ${BIN_DIR#"$ROOTDIR"/}"
    exit 1
fi

if [ ! -e "$BTC_D" ]; then
    echo "Error: Binary not found at ${BTC_D#"$ROOTDIR"/}"
    exit 1
fi

if [ ! -x "$BTC_D" ]; then
    echo "Error: Binary not executable at ${BTC_D#"$ROOTDIR"/}"
    exit 1
fi

# Refuse to wipe regtest data while a regtest node is using this datadir: on
# Unix "rm -rf" deletes files held open by the running process and corrupts it.
if pgrep -f -i -- "-datadir=${ROOTDIR}/bitcoin-datadir -regtest" >/dev/null 2>&1
then
    echo "Error: a regtest Bitcoin process is using bitcoin-datadir."
    echo "Stop it before a clean start."
    exit 1
fi

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
"$BTC_D" \
  -daemon \
  -uacomment="${FILENAME}" \
  -datadir="${DATADIR}" \
  -regtest \
  -rpcallowip=127.0.0.1 \
  -addnode=localhost:18555 \
  -addnode=localhost:18666

# Unix bitcoind supports -daemon; Windows bitcoind.exe does not, which is
# why the Windows counterpart opens a second console with a doskey alias
# instead. Here the daemon forks and returns, so this window is free to
# become the CLI session itself, with btc a function rather than an
# alias: an alias is flat text re-split on every space when expanded, so
# a ROOTDIR containing one breaks it, where a function's "$@" does not.
export BTC_CLI DATADIR
RCFILE="$(mktemp -t portanode-alice-cli-rc)"
# BTC_CLI and DATADIR are meant to expand inside the shell this rcfile
# starts, not here: they are read from the exported environment above.
# shellcheck disable=SC2016
echo 'btc() { "$BTC_CLI" -regtest -datadir="$DATADIR" "$@"; }' > "$RCFILE"
echo "btc is a function for bitcoin-cli on this datadir for this session."
exec bash --rcfile "$RCFILE" -i
