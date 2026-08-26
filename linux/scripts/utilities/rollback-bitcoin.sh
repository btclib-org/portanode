#!/bin/bash
# Rollback Last Bitcoin Update (Linux)
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
BACKUP_DIR="$BIN_DIR/backup/bitcoin"
CHECKSUM_FILE="$ROOTDIR/linux/checksums.sha256"
BIN_NAMES="bitcoind bitcoin-cli bitcoin-qt bitcoin-tx bitcoin-util bitcoin-wallet bitcoin"

# A rollback replaces the files update-bitcoin.sh installs, so it refuses on
# the same condition: swapping a binary under a running process is the same
# operation whichever script does it, and a rollback is run when something
# has just gone wrong, which is when the node is most likely to still be up.
# The pattern is update-bitcoin.sh's own, repeated here rather than shared,
# so a change to one is owed to the other -- matching how the macOS and
# Windows halves of this same pair are written.
BTC_PGREP_PATTERN="bitcoind|bitcoin-qt|bitcoin qt"
if pgrep -f -i "$BTC_PGREP_PATTERN" > /dev/null; then
    echo "Error: Bitcoin Core is running. Stop it before rolling back."
    exit 1
fi

echo "Rolling back Bitcoin binaries..."

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup found in linux/bin/backup/bitcoin"
    debug_list_dir "$BACKUP_DIR"
    exit 1
fi
if [ ! -f "$CHECKSUM_FILE" ]; then
    echo "Error: linux/checksums.sha256 not found."
    exit 1
fi

# Fail closed before moving anything: every backup binary that is present
# has to carry a checksum this tree recognizes, or none of them are
# restored. Restoring some and refusing others would leave linux/bin in a
# state neither the old release nor the new one ever was. update-bitcoin.sh
# backs up every name in BIN_NAMES that existed before the update it is
# about to replace, so the backup directory may legitimately hold fewer
# than all of them (a first install has none to back up).
FOUND_ANY=0
for b in $BIN_NAMES; do
    if [ -f "$BACKUP_DIR/$b" ]; then
        FOUND_ANY=1
        rc=0
        verify_checksum_entry "$BACKUP_DIR/$b" "linux/bin/$b" \
          "$CHECKSUM_FILE" "backup binary ($b)" || rc=$?
        if [ "$rc" -ne 0 ]; then
            if [ "$rc" -eq 1 ]; then
                echo "Error: backup binary checksum not recognized for $b."
            fi
            exit 1
        fi
    fi
done
if [ "$FOUND_ANY" -eq 0 ]; then
    echo "Backup files not found in linux/bin/backup/bitcoin"
    exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
    BACKUP_VERSION="unknown"
    if [ -f "$BACKUP_DIR/bitcoin-qt" ]; then
        BACKUP_VERSION="$(installed_version "$BACKUP_DIR/bitcoin-qt" \
          "linux/bin/bitcoin-qt" "$CHECKSUM_FILE")"
    fi
    CURRENT_VERSION="$(installed_version "$BIN_DIR/bitcoin-qt" \
      "linux/bin/bitcoin-qt" "$CHECKSUM_FILE")"
    echo "--dry-run: nothing will be changed."
    echo "Backup found in linux/bin/backup/bitcoin, checksum recognized:" \
         "version ${BACKUP_VERSION}."
    echo "Currently installed: ${CURRENT_VERSION}."
    echo "Would replace linux/bin binaries with the backup."
    exit 0
fi

# The backup is moved rather than copied, so a rollback consumes it: the
# slot holds the version installed before the last update, and a copy left
# behind would hold the version that is now installed. A slot that swapped
# its contents instead would make a second rollback move forward again,
# where update-bitcoin.sh brings the newer release back and verifies its
# PGP signature on the way -- the same semantics the macOS and Windows
# rollbacks beside this one use.
FAILED=0
for b in $BIN_NAMES; do
    if [ -f "$BACKUP_DIR/$b" ]; then
        if mv "$BACKUP_DIR/$b" "$BIN_DIR/$b"; then
            chmod +x "$BIN_DIR/$b"
        else
            echo "Error: restoring linux/bin/$b from the backup failed."
            FAILED=1
            break
        fi
    fi
done
if [ "$FAILED" -ne 0 ]; then
    echo "The rollback stopped before restoring every binary. What it did" \
         "not move is still in linux/bin/backup/bitcoin. Once the cause is" \
         "cleared, move what is left there into linux/bin by hand, or run" \
         "update-bitcoin.sh to install the current release over whatever" \
         "linux/bin now holds."
    exit 1
fi
rmdir "$BACKUP_DIR" 2>/dev/null || true

echo "Rollback complete"
echo "The backup in linux/bin/backup/bitcoin is consumed: a second rollback" \
     "has nothing to restore."
echo "update-bitcoin.sh is what installs the current release again."
