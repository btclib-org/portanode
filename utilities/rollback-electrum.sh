#!/bin/bash
# Rollback Electrum binaries to previous version

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$ROOTDIR/bin-backup/electrum"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup found in $BACKUP_DIR"
    exit 1
fi

echo "Rolling back Electrum binaries..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -d "$BACKUP_DIR/Electrum.app" ]; then
        rm -rf "$ROOTDIR/macos/bin/Electrum.app"
        cp -R "$BACKUP_DIR/Electrum.app" "$ROOTDIR/macos/bin/Electrum.app"
    else
        echo "Electrum.app not found in backup"
        exit 1
    fi
elif [[ "$OSTYPE" == "msys" ]]; then
    cp "$BACKUP_DIR/electrum.exe" "$ROOTDIR/win/bin/" 2>/dev/null || echo "electrum.exe not found in backup"
fi

echo "Rollback complete. Run utilities/validate-setup.sh to verify."
