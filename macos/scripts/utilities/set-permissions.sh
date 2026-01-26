#!/bin/bash
# Set secure permissions for PortaNode data directories

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "Setting restrictive permissions on data directories..."

if [ ! -d "$ROOTDIR/bitcoin-datadir" ]; then
    echo "Error: bitcoin-datadir not found."
    exit 1
fi
if [ ! -d "$ROOTDIR/electrum-datadir" ]; then
    echo "Error: electrum-datadir not found."
    exit 1
fi

chmod -R u=rwX,go= "$ROOTDIR/bitcoin-datadir"
chmod -R u=rwX,go= "$ROOTDIR/electrum-datadir"
chmod 700 "$ROOTDIR/bitcoin-datadir"
chmod 700 "$ROOTDIR/electrum-datadir"

echo "Permissions set. Only owner can access."
