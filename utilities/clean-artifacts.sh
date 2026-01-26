#!/bin/bash
# Clean macOS and Windows artifacts

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Cleaning artifacts..."

# macOS
find "$ROOTDIR" -name ".DS_Store" -type f -delete
find "$ROOTDIR" -name "._*" -type f -delete
find "$ROOTDIR" -name ".Spotlight-V100" -type d -exec rm -rf {} + 2>/dev/null || true
find "$ROOTDIR" -name ".Trashes" -type d -exec rm -rf {} + 2>/dev/null || true

# Windows
find "$ROOTDIR" -name "ehthumbs.db" -type f -delete
find "$ROOTDIR" -name "Thumbs.db" -type f -delete
find "$ROOTDIR" -name "*.stackdump" -type f -delete

echo "Cleanup complete."
