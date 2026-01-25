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
    hash="${line%%[[:space:]]*}"
    file="${line#"$hash"}"
    file="${file#"${file%%[![:space:]]*}"}"
    if [ -z "$hash" ] || [ -z "$file" ] || [ "$file" = "$line" ]; then
        echo "Error: Malformed checksum line: $line"
        exit 1
    fi
    if [ "${#hash}" -ne 64 ]; then
        echo "Error: Invalid SHA-256 hash length: $line"
        exit 1
    fi
    if [ ! -f "$file" ]; then
        echo "Error: Missing file: $file"
        exit 1
    fi
done < "$CHECKSUM_FILE"

echo "Verifying binaries..."
if command -v shasum >/dev/null 2>&1; then
    grep -v '^#' "$CHECKSUM_FILE" | grep -v '^$' | shasum -a 256 -c -
elif command -v sha256sum >/dev/null 2>&1; then
    grep -v '^#' "$CHECKSUM_FILE" | grep -v '^$' | sha256sum -c -
else
    echo "Error: Neither shasum nor sha256sum found. Install coreutils or similar."
    exit 1
fi

echo "Verification complete."
