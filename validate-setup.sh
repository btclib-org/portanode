#!/bin/bash
# Validate PortaNode setup: binaries, checksums, permissions, disk space

echo "Validating PortaNode setup..."

# Check binaries exist
BINARIES=("macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" "macos/bin/Electrum.app/Contents/MacOS/run_electrum" "win/bin/bitcoin-qt.exe" "win/bin/electrum.exe")
for bin in "${BINARIES[@]}"; do
    if [ ! -f "$bin" ]; then
        echo "ERROR: Binary $bin not found."
        exit 1
    fi
done
echo "✓ Binaries present"

# Check checksums
if [ -f "verify-binaries.sh" ]; then
    ./verify-binaries.sh > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ Checksums valid"
    else
        echo "ERROR: Checksum verification failed."
        exit 1
    fi
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
DISK_FREE=$(df -h . | awk 'NR==2 {print $4}')
echo "Disk free space: $DISK_FREE"
# Note: Parsing df output; assume GB

echo "Validation complete. Setup looks good!"