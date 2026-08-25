#!/bin/bash
ROOTDIR="${PORTANODE_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd -P)}"
echo ROOTDIR is "${ROOTDIR}"
BIN_DIR="${ROOTDIR}/macos/bin"
BTC_D="${BIN_DIR}/bitcoind"
BTC_CLI="${BIN_DIR}/bitcoin-cli"

if [ ! -d "$BIN_DIR" ]; then
    echo "Error: Binaries directory not found at $BIN_DIR"
    exit 1
fi

if [ ! -e "$BTC_D" ]; then
    echo "Error: Binary not found at $BTC_D"
    exit 1
fi

if [ ! -x "$BTC_D" ]; then
    echo "Error: Binary not executable at $BTC_D"
    exit 1
fi

DATADIR="${ROOTDIR}/bitcoin-datadir/regtest_bob"

# Refuse to wipe a datadir a node is using: on Unix "rm -rf" deletes files held
# open by the running process, which would corrupt a live node.
if pgrep -f -i -- "-datadir=${DATADIR}" >/dev/null 2>&1; then
    echo "Error: a Bitcoin process is using ${DATADIR}."
    echo "Stop it before a clean start."
    exit 1
fi

echo "WARNING: This will delete regtest data."
echo "Press Enter to continue or Ctrl+C to cancel."
read -r

rm -rf "${DATADIR}"
mkdir -p "${DATADIR}"

BASENAME="$(basename "$0")"
FILENAME="${BASENAME%.*}"
# Bitcoin Core's regtest RPC port defaults to 18443 regardless of -port, so
# Alice, Bob and Carol running concurrently would each try to bind RPC on
# 18443 without an explicit -rpcport. This one is Bob's, distinct from
# Alice's default and from Carol's, following the P2P-minus-one spacing
# Bitcoin Core itself uses between a network's own P2P and RPC ports
# (8333/8332, 18333/18332, 18444/18443).
RPCPORT=18554
"$BTC_D" \
  -daemon \
  -uacomment="${FILENAME}" \
  -datadir="${DATADIR}" \
  -regtest \
  -port=18555 \
  -rpcport="${RPCPORT}" \
  -rpcallowip=127.0.0.1 \
  -addnode=localhost:18444 \
  -addnode=localhost:18666

# Unix bitcoind supports -daemon; Windows bitcoind.exe does not, which is
# why the Windows counterpart opens a second console with a doskey alias
# instead. Here the daemon forks and returns, so this window is free to
# become the CLI session itself, with btc a function rather than an
# alias: an alias is flat text re-split on every space when expanded, so
# a ROOTDIR containing one breaks it, where a function's "$@" does not.
export BTC_CLI DATADIR RPCPORT
RCFILE="$(mktemp -t portanode-bob-cli-rc)"
# BTC_CLI, DATADIR and RPCPORT are meant to expand inside the shell this
# rcfile starts, not here: they are read from the exported environment
# above.
# shellcheck disable=SC2016
echo 'btc() { "$BTC_CLI" -regtest -datadir="$DATADIR" -rpcport="$RPCPORT" "$@"; }' > "$RCFILE"
echo "btc is a function for bitcoin-cli on this datadir for this session."
exec bash --rcfile "$RCFILE" -i
