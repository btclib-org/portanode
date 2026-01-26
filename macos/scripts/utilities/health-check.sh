#!/bin/bash
# Health check for PortaNode

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "Running health checks..."

# Disk space
DISK_USAGE=$(df -h "$ROOTDIR" | awk 'NR==2 {print $5}')
echo "Disk usage: $DISK_USAGE"

# Bitcoin sync status (if running)
if pgrep -f "bitcoind\|bitcoin-qt" > /dev/null; then
    # Assume RPC enabled
    BLOCKCHAIN_INFO=$(bitcoin-cli -datadir="$ROOTDIR/bitcoin-datadir" getblockchaininfo 2>/dev/null)
    if [ $? -eq 0 ]; then
        SYNC=$(echo "$BLOCKCHAIN_INFO" | jq -r '.verificationprogress')
        echo "Bitcoin sync progress: $(echo "$SYNC * 100" | bc -l)%"
    else
        echo "Bitcoin RPC not accessible"
    fi
else
    echo "Bitcoin not running"
fi

# Electrum (check if process exists)
if pgrep -f "electrum" > /dev/null; then
    echo "Electrum is running"
else
    echo "Electrum not running"
fi

echo "Health check complete"
