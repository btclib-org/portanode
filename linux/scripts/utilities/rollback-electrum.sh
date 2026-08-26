#!/bin/bash
# Rollback Last Electrum Update (Linux)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=linux/scripts/utilities/lib.sh
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

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "Unsupported OS (Linux only)."
    exit 1
fi

BIN_DIR="$ROOTDIR/linux/bin"
BACKUP_DIR="$BIN_DIR/backup/electrum"
CHECKSUM_FILE="$ROOTDIR/linux/checksums.sha256"

# A rollback replaces the file update-electrum.sh installs, so it refuses on
# the same condition: swapping the AppImage under a running process is the
# same operation whichever script does it, and a rollback is run when
# something has just gone wrong, which is when Electrum is most likely to
# still be up. The pattern is update-electrum.sh's own, repeated here rather
# than shared, matching how the macOS and Windows halves of this same pair
# are written. run_electrum is anchored to where a program name can appear,
# for the same reason update-electrum.sh's own copy is.
ELECTRUM_PGREP_PATTERN="electrum\.AppImage|python.*electrum|(^|/)run_electrum( |\$)"
if pgrep -f -i "$ELECTRUM_PGREP_PATTERN" > /dev/null; then
    echo "Error: Electrum is running. Stop it before rolling back."
    exit 1
fi

echo "Rolling back Electrum binaries..."

if [ ! -d "$BACKUP_DIR" ] || [ ! -f "$BACKUP_DIR/electrum.AppImage" ]; then
    echo "No backup found in linux/bin/backup/electrum"
    debug_list_dir "$BACKUP_DIR"
    exit 1
fi
if [ ! -f "$CHECKSUM_FILE" ]; then
    echo "Error: linux/checksums.sha256 not found."
    exit 1
fi

rc=0
verify_checksum_entry "$BACKUP_DIR/electrum.AppImage" "linux/bin/electrum.AppImage" \
  "$CHECKSUM_FILE" "backup binary (electrum.AppImage)" || rc=$?
if [ "$rc" -ne 0 ]; then
    if [ "$rc" -eq 1 ]; then
        echo "Error: backup binary checksum not recognized for electrum.AppImage."
    fi
    exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
    BACKUP_VERSION="$(installed_version "$BACKUP_DIR/electrum.AppImage" \
      "linux/bin/electrum.AppImage" "$CHECKSUM_FILE")"
    CURRENT_VERSION="$(installed_version "$BIN_DIR/electrum.AppImage" \
      "linux/bin/electrum.AppImage" "$CHECKSUM_FILE")"
    echo "--dry-run: nothing will be changed."
    echo "Backup found in linux/bin/backup/electrum, checksum recognized:" \
         "version ${BACKUP_VERSION}."
    echo "Currently installed: ${CURRENT_VERSION}."
    echo "Would replace linux/bin/electrum.AppImage with the backup."
    exit 0
fi

# The backup is moved rather than copied, so a rollback consumes it -- see
# rollback-bitcoin.sh (Linux)'s own comment on this same choice, which this
# repeats rather than shares.
if mv "$BACKUP_DIR/electrum.AppImage" "$BIN_DIR/electrum.AppImage"; then
    chmod +x "$BIN_DIR/electrum.AppImage"
else
    echo "Error: restoring linux/bin/electrum.AppImage from the backup failed."
    exit 1
fi
rmdir "$BACKUP_DIR" 2>/dev/null || true

echo "Rollback complete"
echo "The backup in linux/bin/backup/electrum is consumed: a second rollback" \
     "has nothing to restore."
echo "update-electrum.sh is what installs the current release again."
