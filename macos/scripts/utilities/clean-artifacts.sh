#!/bin/bash
# Clean macOS artifacts

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=macos/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"

echo "Cleaning artifacts..."

# macOS artifacts (.DS_Store, ._*) appear where a Finder window has been --
# the launcher and script directories -- and never inside bitcoin-datadir/
# or electrum-datadir/, which macOS does not open in Finder on a running
# node. Those two hold a synced chain's blocks, chainstate and indexes, so
# walking into them turns a cleanup of a handful of sidecar files into
# minutes of I/O over hundreds of thousands of files; -prune keeps the find
# rooted at $ROOTDIR without ever descending into either.
#
# -delete is not used here: it implies -depth (post-order traversal), and
# -prune has no effect once -depth is on, so "-prune -o ... -delete" walks
# and deletes inside the pruned directories anyway -- confirmed against a
# scratch tree with both bitcoin-datadir/ and electrum-datadir/ populated.
# -exec rm -f/-rf {} + keeps the pre-order traversal -prune relies on.
PRUNE_DATADIRS=( \( -path "$ROOTDIR/bitcoin-datadir" -o \
                     -path "$ROOTDIR/electrum-datadir" \) -prune -o )

find "$ROOTDIR" "${PRUNE_DATADIRS[@]}" -name ".DS_Store" -type f \
  -exec rm -f {} +
find "$ROOTDIR" "${PRUNE_DATADIRS[@]}" -name "._*" -type f \
  -exec rm -f {} +
find "$ROOTDIR" "${PRUNE_DATADIRS[@]}" -name ".Spotlight-V100" -type d \
  -exec rm -rf {} + \
  2>/dev/null || true
find "$ROOTDIR" "${PRUNE_DATADIRS[@]}" -name ".Trashes" -type d \
  -exec rm -rf {} + \
  2>/dev/null || true

echo "Cleanup complete."
