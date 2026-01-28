#!/bin/bash
# Validate setup: binaries, checksums, permissions, disk space
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "Validating setup at $ROOTDIR"

# Check binaries and checksums
if [ -x "$SCRIPT_DIR/verify-binaries.sh" ]; then
    bash "$SCRIPT_DIR/verify-binaries.sh"
else
    echo "WARNING: verify-binaries.sh not found, skipping checksum check"
fi

# Check permissions (basic)
if [ -d "$ROOTDIR/bitcoin-datadir" ] && [ -d "$ROOTDIR/electrum-datadir" ]; then
    # On macOS, check if directories are accessible
    echo "OK: Data directories exist"
else
    echo "WARNING: Data directories not found"
fi

# Check disk space (require at least 100GB free)
DISK_FREE_KB=$(df -Pk "$ROOTDIR" | awk 'NR==2 {print $4}')
DISK_FREE_HUMAN=$(df -h "$ROOTDIR" | awk 'NR==2 {print $4}')
REQUIRED_KB=$((100 * 1024 * 1024))
echo "Disk free space: $DISK_FREE_HUMAN"
if [ "$DISK_FREE_KB" -lt "$REQUIRED_KB" ]; then
    echo "ERROR: Less than 100GB free."
    exit 1
fi

echo "Setup validation completed."
