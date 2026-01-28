#!/bin/bash
# Rollback Bitcoin binaries to previous version

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

debug_list_dir() {
    local dir="$1"
    echo "Debug: $dir contents: $(ls -a "$dir" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
}

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
    if [ ! -f "$BACKUP_BIN" ]; then
        echo "Error: backup binary not found at $BACKUP_BIN"
        debug_list_dir "$(dirname "$BACKUP_BIN")"
        exit 1
    fi
    if [ ! -f "$CHECKSUM_FILE" ]; then
        echo "Error: $CHECKSUM_FILE not found."
        debug_list_dir "$(dirname "$CHECKSUM_FILE")"
        exit 1
    fi
    if command -v shasum >/dev/null 2>&1; then
        HASH="$(shasum -a 256 "$BACKUP_BIN" | awk '{print $1}')"
    elif command -v sha256sum >/dev/null 2>&1; then
        HASH="$(sha256sum "$BACKUP_BIN" | awk '{print $1}')"
    else
        echo "Error: Neither shasum nor sha256sum found."
        exit 1
    fi
    if ! awk -v h="$HASH" \
        -v p="macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" \
        '$1 == h && index($0, p) { found=1 } END { exit found ? 0 : 1 }' \
        "$CHECKSUM_FILE"; then
        echo "Error: backup binary checksum not recognized."
        exit 1
    fi

    rm -rf "$ROOTDIR/macos/bin/Bitcoin-Qt.app"
    mv "$BACKUP_DIR/Bitcoin-Qt.app" "$ROOTDIR/macos/bin/Bitcoin-Qt.app"
    rmdir "$BACKUP_DIR" 2>/dev/null || true
else
    echo "Unsupported OS"
    exit 1
fi

echo "Rollback complete. Run"
echo "macos/scripts/utilities/validate-setup.sh to verify (macOS only)."

if [ -x "$SCRIPT_DIR/verify-binaries.sh" ]; then
    bash "$SCRIPT_DIR/verify-binaries.sh"
else
    echo "Warning: verify-binaries.sh not found or not executable;"
    echo "skipping verification."
fi
