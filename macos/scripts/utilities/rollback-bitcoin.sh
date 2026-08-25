#!/bin/bash
# Rollback Last Bitcoin Update
set -euo pipefail

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

# A rollback replaces the files update-bitcoin.sh installs, so it refuses on the
# same condition: swapping an app bundle under a running process is the same
# operation whichever script does it, and a rollback is run when something has
# just gone wrong, which is when the node is most likely to still be up. The
# pattern is that script's, repeated here rather than shared, so a change to one
# is owed to the other.
BTC_PGREP_PATTERN="bitcoind|bitcoin-qt|bitcoin qt|Bitcoin-Qt.app"
if pgrep -f -i "$BTC_PGREP_PATTERN" > /dev/null; then
    echo "Error: Bitcoin Core is running. Stop it before rolling back."
    exit 1
fi

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
    rc=0
    verify_checksum_entry \
      "$BACKUP_BIN" \
      "macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" \
      "$CHECKSUM_FILE" \
      "backup binary" || rc=$?
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

    # The backup is moved rather than copied, so a rollback consumes it: the
    # slot holds the version installed before the last update, and a copy left
    # behind would hold the version that is now installed. A slot that swapped
    # its contents instead would make a second rollback move forward again,
    # where update-bitcoin.sh brings the newer release back and verifies its
    # PGP signature on the way.
    APP="$ROOTDIR/macos/bin/Bitcoin-Qt.app"
    # Rename the installed app aside rather than deleting it: a restore that
    # then fails has something to put back, where a delete followed by a failed
    # move leaves macos/bin with no Bitcoin-Qt.app at all. Both paths are on the
    # one volume, so each move is a rename. The name carries the pid so that a
    # crash between the two renames leaves something recognizable rather than a
    # target the next run would delete.
    OUTGOING=""
    if [ -e "$APP" ]; then
        OUTGOING="$APP.rollback-$$"
        mv "$APP" "$OUTGOING"
    fi
    if ! mv "$BACKUP_DIR/Bitcoin-Qt.app" "$APP"; then
        echo "Error: restoring macos/bin/Bitcoin-Qt.app from the backup failed."
        if [ -n "$OUTGOING" ]; then
            if mv "$OUTGOING" "$APP"; then
                echo "macos/bin/Bitcoin-Qt.app is the version that was" \
                     "installed, and the backup is untouched."
            else
                echo "The version that was installed is at" \
                     "${OUTGOING#"$ROOTDIR"/} and has to be moved back by hand."
            fi
        fi
        exit 1
    fi
    if [ -n "$OUTGOING" ]; then
        rm -rf "${OUTGOING:?}"
    fi
    rmdir "$BACKUP_DIR" 2>/dev/null || true
else
    echo "Unsupported OS"
    exit 1
fi

echo "Rollback complete"
echo "The backup in macos/bin/backup/bitcoin is consumed: a second rollback" \
     "has nothing to restore."
echo "update-bitcoin.sh is what installs the current release again."
# What a rollback restores is what update-bitcoin.sh backs up, and that is the
# app alone: the command-line tools it installs beside it are stateless and
# re-downloadable, so it overwrites them without a copy. The rollback says so
# rather than letting "Rollback complete" imply they moved too. The Windows half
# restores the command-line tools too, update-bitcoin.bat copying them into the
# backup.
echo "The command-line tools in macos/bin are not rolled back: the backup holds" \
     "the app alone."
