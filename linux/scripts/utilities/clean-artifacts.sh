#!/bin/bash
# Clean Linux artifacts

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=linux/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"

echo "Cleaning artifacts..."

# What a Linux desktop leaves here, and nothing else: macOS's .DS_Store and
# ._* sidecars and Windows' Thumbs.db are their own platform's
# clean-artifacts to remove, so a volume carried between machines is
# cleaned by whichever one it is plugged into.
#
# .Trash/<uid> and .Trash-<uid> are the freedesktop.org Trash
# specification's two names for the trash directory of a device other than
# the one holding the user's home, created by the file manager the first
# time something on this volume is deleted
# (https://specifications.freedesktop.org/trash/1.0/). Removing one
# discards what was deleted into it, which is what the macOS half does with
# .Trashes. The specification puts them at the volume's top directory, so
# they are found here only where ROOTDIR is that directory; a folder
# sitting in a subdirectory of its volume keeps its trash outside ROOTDIR,
# and nothing here reaches outside ROOTDIR to delete.
#
# .goutputstream-XXXXXX is the temporary file GLib's g_file_replace writes
# beside the file it is replacing (gio/glocalfileoutputstream.c), renamed
# into place once the write succeeds; one still on disk is what a killed
# save left behind.
#
# bitcoin-datadir/ and electrum-datadir/ are pruned for the reason the
# macOS half gives -- they hold a synced chain's blocks, chainstate and
# indexes, so descending into them turns a cleanup of a handful of files
# into minutes of I/O -- and -delete is avoided there for the reason that
# holds here too: it implies -depth, which turns -prune off.
PRUNE_DATADIRS=( \( -path "$ROOTDIR/bitcoin-datadir" -o \
                     -path "$ROOTDIR/electrum-datadir" \) -prune -o )

find "$ROOTDIR" "${PRUNE_DATADIRS[@]}" -name ".goutputstream-*" -type f \
  -exec rm -f {} +
find "$ROOTDIR" "${PRUNE_DATADIRS[@]}" -name ".Trash" -type d \
  -exec rm -rf {} + \
  2>/dev/null || true
find "$ROOTDIR" "${PRUNE_DATADIRS[@]}" -name ".Trash-*" -type d \
  -exec rm -rf {} + \
  2>/dev/null || true

echo "Cleanup complete."
