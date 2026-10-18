#!/bin/bash
# Clean macOS artifacts

# bash looks for a bare name in the current directory, then in PATH. Found
# through PATH, $0 has no directory, so the directory below would be wrong.
case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=macos/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")" || exit 1

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
#
# -path reads its operand as a glob, so the two are named from "." with the
# walk started inside ROOTDIR: named under "$ROOTDIR", a mount path holding
# a bracket pair such as "[x]" or a backslash does not match itself, and
# the walk descends into both.
cd "$ROOTDIR" || exit 1
PRUNE_DATADIRS=( \( -path ./bitcoin-datadir -o -path ./electrum-datadir \) \
                 -prune -o )

find . "${PRUNE_DATADIRS[@]}" -name ".DS_Store" -type f \
  -exec rm -f {} +
find . "${PRUNE_DATADIRS[@]}" -name "._*" -type f \
  -exec rm -f {} +
find . "${PRUNE_DATADIRS[@]}" -name ".Spotlight-V100" -type d \
  -exec rm -rf {} + \
  2>/dev/null || true
find . "${PRUNE_DATADIRS[@]}" -name ".Trashes" -type d \
  -exec rm -rf {} + \
  2>/dev/null || true

echo "Cleanup complete."
