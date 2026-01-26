#!/bin/bash
# Rollback Bitcoin binaries to previous version

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BACKUP_DIR="$ROOTDIR/win/bin-backup/bitcoin"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup found in $BACKUP_DIR"
    exit 1
fi

echo "Rolling back Bitcoin binaries..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    BACKUP_DIR="$ROOTDIR/macos/bin-backup/bitcoin"
    if [ -d "$BACKUP_DIR/Bitcoin-Qt.app" ]; then
        rm -rf "$ROOTDIR/macos/bin/Bitcoin-Qt.app"
        mv "$BACKUP_DIR/Bitcoin-Qt.app" "$ROOTDIR/macos/bin/Bitcoin-Qt.app"
        rmdir "$BACKUP_DIR" 2>/dev/null || true
    else
        echo "Bitcoin-Qt.app not found in backup"
        exit 1
    fi
elif [[ "$OSTYPE" == "msys" ]]; then
    cp "$BACKUP_DIR/"*.exe "$ROOTDIR/win/bin/" 2>/dev/null || echo "Executables not found in backup"
fi

echo "Rollback complete. Run macos/scripts/utilities/validate-setup.sh to verify."

if [ -x "$SCRIPT_DIR/verify-binaries.sh" ]; then
    bash "$SCRIPT_DIR/verify-binaries.sh"
else
    echo "Warning: verify-binaries.sh not found or not executable; skipping verification."
fi
