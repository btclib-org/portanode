#!/bin/bash
# Rollback Last Electrum Update
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=macos/scripts/utilities/lib.sh
. "$SCRIPT_DIR/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
BACKUP_DIR="$ROOTDIR/macos/bin/backup/electrum"

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

# A rollback replaces the files update-electrum.sh installs, so it refuses on
# the same condition: swapping an app bundle under a running process is the same
# operation whichever script does it, and a rollback is run when something has
# just gone wrong, which is when Electrum is most likely to still be up. The
# pattern is that script's, repeated here rather than shared, so a change to one
# is owed to the other.
ELECTRUM_PGREP_PATTERN="Electrum.app/Contents/MacOS/(Electrum|run_electrum)$"
ELECTRUM_PGREP_PATTERN="${ELECTRUM_PGREP_PATTERN}|/Electrum$|/electrum$"
ELECTRUM_PGREP_PATTERN="${ELECTRUM_PGREP_PATTERN}|python.*electrum"
ELECTRUM_PGREP_PATTERN="${ELECTRUM_PGREP_PATTERN}|run_electrum"
if pgrep -f -i "$ELECTRUM_PGREP_PATTERN" > /dev/null; then
    echo "Error: Electrum is running. Stop it before rolling back."
    exit 1
fi

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
        rc=0
        verify_checksum_entry \
          "$BACKUP_BIN" \
          "macos/bin/Electrum.app/Contents/MacOS/run_electrum" \
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
              "macos/bin/Electrum.app/Contents/MacOS/run_electrum" \
              "$CHECKSUM_FILE")"
            CURRENT_VERSION="$(installed_version \
              "$ROOTDIR/macos/bin/Electrum.app/Contents/MacOS/run_electrum" \
              "macos/bin/Electrum.app/Contents/MacOS/run_electrum" \
              "$CHECKSUM_FILE")"
            echo "--dry-run: nothing will be changed."
            echo "Backup found in $BACKUP_DIR, checksum recognized:" \
                 "version ${BACKUP_VERSION}."
            echo "Currently installed: ${CURRENT_VERSION}."
            echo "Would replace macos/bin/Electrum.app with the backup."
            exit 0
        fi

        # The backup is moved rather than copied, so a rollback consumes it: the
        # slot holds the version installed before the last update, and a copy
        # left behind would hold the version that is now installed. A slot that
        # swapped its contents instead would make a second rollback move forward
        # again, where update-electrum.sh brings the newer release back and
        # verifies its PGP signature on the way.
        APP="$ROOTDIR/macos/bin/Electrum.app"
        # Rename the installed app aside rather than deleting it: a restore that
        # then fails has something to put back, where a delete followed by a
        # failed move leaves macos/bin with no Electrum.app at all. Both paths
        # are on the one volume, so each move is a rename. The name carries the
        # pid so that a crash between the two renames leaves something
        # recognizable rather than a target the next run would delete.
        OUTGOING=""
        if [ -e "$APP" ]; then
            OUTGOING="$APP.rollback-$$"
            mv "$APP" "$OUTGOING"
        fi
        if ! mv "$BACKUP_DIR/Electrum.app" "$APP"; then
            echo "Error: restoring macos/bin/Electrum.app from the backup" \
                 "failed."
            if [ -n "$OUTGOING" ]; then
                if mv "$OUTGOING" "$APP"; then
                    echo "macos/bin/Electrum.app is the version that was" \
                         "installed, and the backup is untouched."
                else
                    echo "The version that was installed is at" \
                         "${OUTGOING#"$ROOTDIR"/} and has to be moved back" \
                         "by hand."
                fi
            fi
            exit 1
        fi
        if [ -n "$OUTGOING" ]; then
            rm -rf "${OUTGOING:?}"
        fi
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
echo "The backup in macos/bin/backup/electrum is consumed: a second rollback" \
     "has nothing to restore."
echo "update-electrum.sh is what installs the current release again."
