#!/bin/bash
# Validate PortaNode setup: binaries, checksums, permissions, disk space
set -euo pipefail

echo "Validating PortaNode setup..."

# Check binaries exist
BINARIES=(
    "macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"
    "macos/bin/Electrum.app/Contents/MacOS/run_electrum"
    "win/bin/bitcoin-qt.exe"
    "win/bin/bitcoind.exe"
    "win/bin/bitcoin-cli.exe"
    "win/bin/bitcoin-tx.exe"
    "win/bin/bitcoin-wallet.exe"
    "win/bin/electrum.exe"
)
for bin in "${BINARIES[@]}"; do
    if [ ! -f "$bin" ]; then
        echo "ERROR: Binary $bin not found."
        exit 1
    fi
done
echo "✓ Binaries present"

# Check checksums
if [ -f "verify-binaries.sh" ]; then
    ./verify-binaries.sh
    echo "✓ Checksums valid"
else
    echo "WARNING: verify-binaries.sh not found, skipping checksum check"
fi

# Check permissions (basic)
if [ -d "bitcoin-datadir" ] && [ -d "electrum-datadir" ]; then
    # On macOS, check if directories are accessible
    echo "✓ Data directories exist"
else
    echo "WARNING: Data directories not found"
fi

# Check disk space (require at least 100GB free)
DISK_FREE_KB=$(df -Pk . | awk 'NR==2 {print $4}')
DISK_FREE_HUMAN=$(df -h . | awk 'NR==2 {print $4}')
REQUIRED_KB=$((100 * 1024 * 1024))
echo "Disk free space: $DISK_FREE_HUMAN"
if [ "$DISK_FREE_KB" -lt "$REQUIRED_KB" ]; then
    echo "ERROR: Less than 100GB free."
    exit 1
fi

echo "Validation complete. Setup looks good!"
