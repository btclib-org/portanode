#!/bin/bash
# Rollback Bitcoin binaries to previous version

BACKUP_DIR="bin-backup-bitcoin"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup found in $BACKUP_DIR"
    exit 1
fi

echo "Rolling back Bitcoin binaries..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    cp "$BACKUP_DIR/Bitcoin-Qt" macos/bin/Bitcoin-Qt.app/Contents/MacOS/ 2>/dev/null || echo "Bitcoin-Qt not found in backup"
elif [[ "$OSTYPE" == "msys" ]]; then
    cp "$BACKUP_DIR/"*.exe win/bin/ 2>/dev/null || echo "Executables not found in backup"
fi

echo "Rollback complete. Run validate-setup.sh to verify."