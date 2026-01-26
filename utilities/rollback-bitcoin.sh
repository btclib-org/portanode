#!/bin/bash
# Rollback Bitcoin binaries to previous version

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$ROOTDIR/bin-backup/bitcoin"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup found in $BACKUP_DIR"
    exit 1
fi

echo "Rolling back Bitcoin binaries..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -d "$BACKUP_DIR/Bitcoin-Qt.app" ]; then
        rm -rf "$ROOTDIR/macos/bin/Bitcoin-Qt.app"
        cp -R "$BACKUP_DIR/Bitcoin-Qt.app" "$ROOTDIR/macos/bin/Bitcoin-Qt.app"
    else
        echo "Bitcoin-Qt.app not found in backup"
        exit 1
    fi
elif [[ "$OSTYPE" == "msys" ]]; then
    cp "$BACKUP_DIR/"*.exe "$ROOTDIR/win/bin/" 2>/dev/null || echo "Executables not found in backup"
fi

echo "Rollback complete. Run utilities/validate-setup.sh to verify."
