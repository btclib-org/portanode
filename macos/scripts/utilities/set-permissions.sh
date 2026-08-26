#!/bin/bash
# Set secure permissions for PortaNode data directories

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=macos/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"

echo "Setting restrictive permissions on data directories..."

if [ ! -d "$ROOTDIR/bitcoin-datadir" ]; then
    echo "Error: bitcoin-datadir not found."
    exit 1
fi
if [ ! -d "$ROOTDIR/electrum-datadir" ]; then
    echo "Error: electrum-datadir not found."
    exit 1
fi

chmod -R u=rwX,go= "$ROOTDIR/bitcoin-datadir"
chmod -R u=rwX,go= "$ROOTDIR/electrum-datadir"
chmod 700 "$ROOTDIR/bitcoin-datadir"
chmod 700 "$ROOTDIR/electrum-datadir"

# macOS synthesises a fixed mode for exFAT and FAT32 rather than storing
# one it was asked to set: every file and directory on such a volume reads
# u=rwx,go= regardless of what chmod requested, so the calls above ran and
# changed nothing on disk. Report which case each directory is actually in
# instead of a blanket "permissions set" that is only true on a filesystem
# that stores permissions at all (measured on an exFAT image, see
# CLAUDE.md's "The bit decides nothing on the volume this is built for").
report_permission_effect() {
    local dir="$1"
    local rel device personality
    rel="${dir#"$ROOTDIR/"}"
    device="$(df -P "$dir" 2>/dev/null | tail -1 | awk '{print $1}')"
    personality="$(diskutil info "$device" 2>/dev/null \
        | awk -F': +' '/File System Personality/ {print $2}')"
    case "$personality" in
        ExFAT|MS-DOS*|FAT32)
            echo "Warning: $rel is on a $personality volume, which does not" \
                 "store POSIX permissions. chmod above changed nothing on" \
                 "disk; the directory is still readable by anyone with" \
                 "access to the volume. Restrict access with encryption or" \
                 "physical control of the device instead."
            ;;
        "")
            echo "Warning: could not determine the filesystem of $rel;" \
                 "assuming the chmod above took effect."
            ;;
        *)
            echo "$rel is on a $personality volume: permissions restricted" \
                 "to the owner."
            ;;
    esac
}

report_permission_effect "$ROOTDIR/bitcoin-datadir"
report_permission_effect "$ROOTDIR/electrum-datadir"
