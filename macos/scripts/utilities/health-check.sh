#!/bin/bash
# Health check for PortaNode

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "Health Check"

# Disk free space (GB)
DISK_FREE_KB=$(df -Pk "$ROOTDIR" | awk 'NR==2 {print $4}')
DISK_FREE_GB=$((DISK_FREE_KB / 1024 / 1024))
echo "Disk free: ${DISK_FREE_GB} GB"

# Bitcoin status
if pgrep -f "bitcoind\|bitcoin-qt" > /dev/null; then
    echo "Bitcoin running: yes"
    BLOCKCHAIN_INFO=$(bitcoin-cli -datadir="$ROOTDIR/bitcoin-datadir" getblockchaininfo 2>/dev/null || true)
    if [ -n "$BLOCKCHAIN_INFO" ] && command -v jq >/dev/null 2>&1; then
        SYNC=$(echo "$BLOCKCHAIN_INFO" | jq -r '.verificationprogress')
        if [ "$SYNC" != "null" ] && [ -n "$SYNC" ]; then
            PCT=$(printf "%.2f" "$(echo "$SYNC * 100" | bc -l)")
            echo "Bitcoin sync: ${PCT}%"
        else
            echo "Bitcoin sync: unknown"
        fi
    else
        echo "Bitcoin sync: unknown"
    fi
else
    echo "Bitcoin running: no"
    echo "Bitcoin sync: n/a"
fi

# Electrum status
if pgrep -f "electrum" > /dev/null; then
    echo "Electrum running: yes"
else
    echo "Electrum running: no"
fi
