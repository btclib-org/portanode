#!/bin/bash
# Rollback Electrum binaries to previous version

BACKUP_DIR="bin-backup-electrum"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup found in $BACKUP_DIR"
    exit 1
fi

echo "Rolling back Electrum binaries..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    cp "$BACKUP_DIR/run_electrum" macos/bin/Electrum.app/Contents/MacOS/ 2>/dev/null || echo "run_electrum not found in backup"
elif [[ "$OSTYPE" == "msys" ]]; then
    cp "$BACKUP_DIR/electrum.exe" win/bin/ 2>/dev/null || echo "electrum.exe not found in backup"
fi

echo "Rollback complete. Run validate-setup.sh to verify."