#!/bin/bash
# Rollback Last Bitcoin Update

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

. "$SCRIPT_DIR/lib.sh"

echo "Rolling back Bitcoin binaries..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    BACKUP_DIR="$ROOTDIR/macos/bin/backup/bitcoin"
    if [ ! -d "$BACKUP_DIR/Bitcoin-Qt.app" ]; then
        echo "No backup found in $BACKUP_DIR"
        debug_list_dir "$BACKUP_DIR"
        exit 1
    fi

    CHECKSUM_FILE="$ROOTDIR/macos/checksums.sha256"
    BACKUP_BIN="$BACKUP_DIR/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"
    verify_checksum_entry \
      "$BACKUP_BIN" \
      "macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" \
      "$CHECKSUM_FILE" \
      "backup binary"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        if [ "$rc" -eq 1 ]; then
            echo "Error: backup binary checksum not recognized."
        fi
        exit 1
    fi

    rm -rf "$ROOTDIR/macos/bin/Bitcoin-Qt.app"
    mv "$BACKUP_DIR/Bitcoin-Qt.app" "$ROOTDIR/macos/bin/Bitcoin-Qt.app"
    rmdir "$BACKUP_DIR" 2>/dev/null || true
else
    echo "Unsupported OS"
    exit 1
fi

echo "Rollback complete"

if [ -x "$SCRIPT_DIR/verify-binaries.sh" ]; then
    bash "$SCRIPT_DIR/verify-binaries.sh"
else
    echo "Warning: verify-binaries.sh not found or not executable;"
    echo "skipping verification."
fi
