#!/bin/bash
# Rollback Electrum binaries to previous version

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BACKUP_DIR="$ROOTDIR/macos/bin/backup/electrum"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup found in $BACKUP_DIR"
    exit 1
fi

echo "Rolling back Electrum binaries..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -d "$BACKUP_DIR/Electrum.app" ]; then
        rm -rf "$ROOTDIR/macos/bin/Electrum.app"
        mv "$BACKUP_DIR/Electrum.app" "$ROOTDIR/macos/bin/Electrum.app"
        rmdir "$BACKUP_DIR" 2>/dev/null || true
    else
        echo "Electrum.app not found in backup"
        exit 1
    fi
else
    echo "Unsupported OS"
    exit 1
fi

echo "Rollback complete. Run macos/scripts/utilities/validate-setup.sh to verify."

if [ -x "$SCRIPT_DIR/verify-binaries.sh" ]; then
    bash "$SCRIPT_DIR/verify-binaries.sh"
else
    echo "Warning: verify-binaries.sh not found or not executable; skipping verification."
fi
