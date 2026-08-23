#!/bin/bash
# Clean macOS artifacts

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"

echo "Cleaning artifacts..."

# macOS
find "$ROOTDIR" -name ".DS_Store" -type f -delete
find "$ROOTDIR" -name "._*" -type f -delete
find "$ROOTDIR" -name ".Spotlight-V100" -type d \
  -exec rm -rf {} + \
  2>/dev/null || true
find "$ROOTDIR" -name ".Trashes" -type d \
  -exec rm -rf {} + \
  2>/dev/null || true

echo "Cleanup complete."
