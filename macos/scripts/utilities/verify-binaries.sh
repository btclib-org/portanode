#!/usr/bin/env bash
# Verify binaries against macos/checksums.sha256
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
CHECKSUM_FILE="macos/checksums.sha256"

echo "Verifying binaries against $CHECKSUM_FILE"

if [ ! -f "$ROOTDIR/$CHECKSUM_FILE" ]; then
    echo "Error: $CHECKSUM_FILE not found."
    exit 1
fi


trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf "%s" "$s"
}

# Parallel indexed arrays hold one record per checksum entry:
#   rec_path[i] / rec_hash[i] / rec_ver[i]
# (associative arrays would need bash 4+, but macOS ships bash 3.2.)
rec_path=()
rec_hash=()
rec_ver=()
# Ordered list of unique macos/* paths, in first-seen order.
upaths=()

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
        macos/*) ;;
        *) continue ;;
    esac
    rec_path+=("$path")
    rec_hash+=("$hash")
    rec_ver+=("$version")
    seen=0
    for p in ${upaths[@]+"${upaths[@]}"}; do
        if [ "$p" = "$path" ]; then
            seen=1
            break
        fi
    done
    [ "$seen" -eq 0 ] && upaths+=("$path")
done < "$ROOTDIR/$CHECKSUM_FILE"

fail=0
for path in ${upaths[@]+"${upaths[@]}"}; do
    file="$ROOTDIR/$path"
    expected_versions=()
    for i in "${!rec_path[@]}"; do
        [ "${rec_path[$i]}" = "$path" ] && expected_versions+=("${rec_ver[$i]}")
    done
    if [ "${#expected_versions[@]}" -gt 0 ]; then
        expected_versions_str=$(printf "%s, " "${expected_versions[@]}")
        expected_versions_str="${expected_versions_str%, }"
    else
        expected_versions_str=""
    fi
    if [ ! -f "$file" ]; then
        if [ -n "$expected_versions_str" ]; then
            echo "$path: MISSING (expected versions: $expected_versions_str)"
        else
            echo "$path: MISSING"
        fi
        continue
    fi
    if command -v shasum >/dev/null 2>&1; then
        hash="$(shasum -a 256 "$file" | awk '{print $1}')"
    elif command -v sha256sum >/dev/null 2>&1; then
        hash="$(sha256sum "$file" | awk '{print $1}')"
    else
        echo "Error: Neither shasum nor sha256sum found."
        echo "Install coreutils or similar."
        exit 1
    fi
    matches=()
    for i in "${!rec_path[@]}"; do
        if [ "${rec_path[$i]}" = "$path" ] && [ "${rec_hash[$i]}" = "$hash" ]; then
            matches+=("${rec_ver[$i]}")
        fi
    done
    if [ "${#matches[@]}" -gt 0 ]; then
        versions=$(printf "%s, " "${matches[@]}")
        versions="${versions%, }"
        echo "$path: OK (version: $versions)"
    else
        if [ -n "$expected_versions_str" ]; then
            echo "$path: FAILED (expected versions: $expected_versions_str)"
        else
            echo "$path: FAILED"
        fi
        fail=$((fail + 1))
    fi
done

if [ "$fail" -ne 0 ]; then
    echo "Verification failed: $fail file(s)."
    exit 1
fi

echo "Binaries verified."
