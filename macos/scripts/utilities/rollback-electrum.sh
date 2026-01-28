#!/bin/bash
# Rollback Last Electrum Update

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BACKUP_DIR="$ROOTDIR/macos/bin/backup/electrum"

. "$SCRIPT_DIR/lib.sh"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup found in $BACKUP_DIR"
    debug_list_dir "$BACKUP_DIR"
    exit 1
fi

echo "Rolling back Electrum binaries..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -d "$BACKUP_DIR/Electrum.app" ]; then
        CHECKSUM_FILE="$ROOTDIR/macos/checksums.sha256"
        BACKUP_BIN="$BACKUP_DIR/Electrum.app/Contents/MacOS/run_electrum"
        verify_checksum_entry \
          "$BACKUP_BIN" \
          "macos/bin/Electrum.app/Contents/MacOS/run_electrum" \
          "$CHECKSUM_FILE" \
          "backup binary"
        rc=$?
        if [ "$rc" -ne 0 ]; then
            if [ "$rc" -eq 1 ]; then
                echo "Error: backup binary checksum not recognized."
            fi
            exit 1
        fi

        rm -rf "$ROOTDIR/macos/bin/Electrum.app"
        mv "$BACKUP_DIR/Electrum.app" "$ROOTDIR/macos/bin/Electrum.app"
        rmdir "$BACKUP_DIR" 2>/dev/null || true
    else
        echo "Electrum.app not found in backup"
        debug_list_dir "$BACKUP_DIR"
        exit 1
    fi
else
    echo "Unsupported OS"
    exit 1
fi

echo "Rollback complete"
