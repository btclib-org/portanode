#!/bin/bash
# Verify PortaNode binaries against checksums.sha256
set -euo pipefail

CHECKSUM_FILE="checksums.sha256"

if [ ! -f "$CHECKSUM_FILE" ]; then
    echo "Error: $CHECKSUM_FILE not found."
    exit 1
fi

while IFS= read -r line; do
    case "$line" in
        ""|\#*) continue ;;
    esac
    file="${line#*  }"
    if [ -z "$file" ] || [ "$file" = "$line" ]; then
        echo "Error: Malformed checksum line: $line"
        exit 1
    fi
    if [ ! -f "$file" ]; then
        echo "Error: Missing file: $file"
        exit 1
    fi
done < "$CHECKSUM_FILE"

echo "Verifying binaries..."
if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -c "$CHECKSUM_FILE"
elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c "$CHECKSUM_FILE"
else
    echo "Error: Neither shasum nor sha256sum found. Install coreutils or similar."
    exit 1
fi

echo "Verification complete."
