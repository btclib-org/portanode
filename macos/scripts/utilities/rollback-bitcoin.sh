#!/bin/bash
# Rollback Last Bitcoin Update

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=macos/scripts/utilities/lib.sh
. "$SCRIPT_DIR/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"

DRY_RUN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            echo "Usage: $(basename "$0") [--dry-run]" >&2
            exit 1
            ;;
    esac
done

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

    if [ "$DRY_RUN" -eq 1 ]; then
        BACKUP_VERSION="$(installed_version "$BACKUP_BIN" \
          "macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" "$CHECKSUM_FILE")"
        CURRENT_VERSION="$(installed_version \
          "$ROOTDIR/macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" \
          "macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" "$CHECKSUM_FILE")"
        echo "--dry-run: nothing will be changed."
        echo "Backup found in $BACKUP_DIR, checksum recognized:" \
             "version ${BACKUP_VERSION}."
        echo "Currently installed: ${CURRENT_VERSION}."
        echo "Would replace macos/bin/Bitcoin-Qt.app with the backup."
        exit 0
    fi

    rm -rf "$ROOTDIR/macos/bin/Bitcoin-Qt.app"
    mv "$BACKUP_DIR/Bitcoin-Qt.app" "$ROOTDIR/macos/bin/Bitcoin-Qt.app"
    rmdir "$BACKUP_DIR" 2>/dev/null || true
else
    echo "Unsupported OS"
    exit 1
fi

echo "Rollback complete"
