#!/usr/bin/env bash
# Verify PortaNode binaries against checksums.sha256
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CHECKSUM_FILE="$ROOTDIR/checksums.sha256"

if [ ! -f "$CHECKSUM_FILE" ]; then
    echo "Error: $CHECKSUM_FILE not found."
    exit 1
fi

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf "%s" "$s"
}

declare -A entries
declare -A paths

while IFS= read -r line; do
    case "$line" in
        ""|\#*) continue ;;
    esac
    hash="${line%%[[:space:]]*}"
    rest="${line#"$hash"}"
    rest="$(trim "$rest")"
    if [ -z "$hash" ] || [ -z "$rest" ] || [ "$rest" = "$line" ]; then
        echo "Error: Malformed checksum line: $line"
        exit 1
    fi
    if [ "${#hash}" -ne 64 ]; then
        echo "Error: Invalid SHA-256 hash length: $line"
        exit 1
    fi
    version="unknown"
    path="$rest"
    if [[ "$rest" == *"version="* ]]; then
        version="${rest##*version=}"
        path="${rest%version=*}"
        path="$(trim "$path")"
        version="$(trim "$version")"
    fi
    case "$path" in
        macos/*) paths["$path"]=1 ;;
        *) continue ;;
    esac
    key="$path"
    entries["$key"]+="${hash}:${version},"
done < "$CHECKSUM_FILE"

echo "Verifying binaries..."
fail=0
for path in "${!paths[@]}"; do
    file="$ROOTDIR/$path"
    if [ ! -f "$file" ]; then
        echo "$path: MISSING"
        fail=1
        continue
    fi
    if command -v shasum >/dev/null 2>&1; then
        hash="$(shasum -a 256 "$file" | awk '{print $1}')"
    elif command -v sha256sum >/dev/null 2>&1; then
        hash="$(sha256sum "$file" | awk '{print $1}')"
    else
        echo "Error: Neither shasum nor sha256sum found. Install coreutils or similar."
        exit 1
    fi
    matches=()
    IFS=',' read -r -a items <<< "${entries[$path]}"
    for item in "${items[@]}"; do
        [ -z "$item" ] && continue
        item_hash="${item%%:*}"
        item_ver="${item#*:}"
        if [ "$item_hash" = "$hash" ]; then
            matches+=("$item_ver")
        fi
    done
    if [ "${#matches[@]}" -gt 0 ]; then
        versions=$(printf "%s, " "${matches[@]}")
        versions="${versions%, }"
        echo "$path: OK (version: $versions)"
    else
        echo "$path: FAILED"
        fail=1
    fi
done

if [ "$fail" -ne 0 ]; then
    exit 1
fi

echo "Verification complete."
