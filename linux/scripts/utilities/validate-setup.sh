#!/bin/bash
# Validate setup: binaries, checksums, permissions, disk space (Linux)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=linux/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"

echo "Validating setup at $ROOTDIR"

# Check binaries and checksums. The script is invoked with "bash", which
# does not need the executable bit, so the test is "does the file exist",
# not "is it executable" -- a copy or an archive extraction can lose the
# bit without the file itself being gone, and on an exFAT mount the bit is
# the mount's fmask rather than anything stored per file (see
# set-permissions.sh).
if [ -f "$SCRIPT_DIR/verify-binaries.sh" ]; then
    bash "$SCRIPT_DIR/verify-binaries.sh"
else
    echo "WARNING: verify-binaries.sh not found, skipping checksum check"
fi

# Check permissions (basic)
if [ -d "$ROOTDIR/bitcoin-datadir" ] && [ -d "$ROOTDIR/electrum-datadir" ]; then
    echo "OK: Data directories exist"
else
    echo "WARNING: Data directories not found"
fi

# Check disk space. The two figures are README.md's Prerequisites: 700GB
# for an unpruned mainnet full sync, 100GB otherwise (pruned, testnet, or
# regtest) -- changing either belongs there first, this comment second.
# Pruning is read from bitcoin-datadir/bitcoin.conf rather than assumed:
# an active, non-zero "prune=" anywhere in the file (any network section)
# lowers the requirement; its absence, or "prune=0", is unpruned.
PRUNED_MIN_KB=$((100 * 1024 * 1024))
MAINNET_MIN_KB=$((700 * 1024 * 1024))
DISK_FREE_KB=$(df -Pk "$ROOTDIR" | awk 'NR==2 {print $4}')
DISK_FREE_HUMAN=$(df -h "$ROOTDIR" | awk 'NR==2 {print $4}')
echo "Disk free space: $DISK_FREE_HUMAN"

BITCOIN_CONF="$ROOTDIR/bitcoin-datadir/bitcoin.conf"
PRUNED=0
if [ -f "$BITCOIN_CONF" ] && \
   grep -qE '^[[:space:]]*prune[[:space:]]*=[[:space:]]*[1-9]' "$BITCOIN_CONF"
then
    PRUNED=1
fi

if [ "$DISK_FREE_KB" -lt "$PRUNED_MIN_KB" ]; then
    echo "ERROR: Less than 100GB free."
    exit 1
elif [ "$PRUNED" -eq 0 ] && [ "$DISK_FREE_KB" -lt "$MAINNET_MIN_KB" ]; then
    echo "WARNING: Less than 700GB free, and bitcoin-datadir/bitcoin.conf" \
         "has no active prune=. An unpruned mainnet full sync needs 700GB;" \
         "enable pruning, or use testnet/regtest, if this is not one."
fi

echo "Setup validation completed."
