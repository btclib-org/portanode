#!/bin/bash
# Shared helpers for macOS utility scripts.

_UTILS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_UTILS_LIB_DIR/../lib.sh"
unset _UTILS_LIB_DIR

debug_list_dir() {
    local dir="$1"
    echo "Debug: $dir contents: $(ls -a "$dir" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
}

pgp_verify_or_warn() {
    local sig_file="$1"
    local data_file="$2"
    local label="$3"
    local out_var="$4"
    local ok=0

    if command -v gpg >/dev/null 2>&1; then
        if ! gpg --list-keys --with-colons 2>/dev/null | grep -q '^pub'; then
            echo "Warning: no public keys found in local keyring."
        fi
        echo "Verifying ${label} signature..."
        local status_file
        status_file="$(mktemp)"
        if ! gpg --status-fd 1 --verify "$sig_file" "$data_file" 1> "$status_file"; then
            true
        fi
        local has_good=0
        local has_bad=0
        local has_missing=0
        if grep -q '^\[GNUPG:\] GOODSIG' "$status_file"; then
            has_good=1
        fi
        if grep -q '^\[GNUPG:\] BADSIG' "$status_file"; then
            has_bad=1
        fi
        if grep -q '^\[GNUPG:\] NO_PUBKEY' "$status_file"; then
            has_missing=1
        fi
        rm -f "$status_file"
        if [ "$has_bad" -eq 1 ]; then
            echo "PGP signature verification failed"
            return 1
        fi
        if [ "$has_good" -eq 0 ]; then
            if [ "$has_missing" -eq 1 ]; then
                echo "Warning: missing public keys for one or more signatures."
                return 0
            fi
            echo "PGP signature verification failed"
            return 1
        fi
        if [ "$has_missing" -eq 1 ]; then
            echo "Warning: missing public keys for one or more signatures."
        fi
        ok=1
    else
        echo "Warning: gpg not found; skipping PGP signature verification."
    fi

    if [ -n "$out_var" ]; then
        printf -v "$out_var" '%s' "$ok"
    fi
    return 0
}

update_checksum() {
    local file="$1"
    local entry_path="$2"
    local version="$3"
    local checksum_file="${4:-$ROOTDIR/macos/checksums.sha256}"
    local hash=""

    if [ ! -f "$file" ]; then
        echo "Error: checksum source not found at $file"
        debug_list_dir "$(dirname "$file")"
        exit 1
    fi

    if command -v shasum >/dev/null 2>&1; then
        hash="$(shasum -a 256 "$file" | awk '{print $1}')"
    elif command -v sha256sum >/dev/null 2>&1; then
        hash="$(sha256sum "$file" | awk '{print $1}')"
    else
        echo "Warning: shasum/sha256sum not found;"
        echo "checksums not updated."
        return 0
    fi

    if [ ! -f "$checksum_file" ]; then
        echo "Warning: $checksum_file not found;"
        debug_list_dir "$(dirname "$checksum_file")"
        echo "checksums not updated."
        return 0
    fi

    local entry="$hash  $entry_path  version=$version"
    if ! grep -Fxq "$entry" "$checksum_file"; then
        echo "$entry" >> "$checksum_file"
    fi
    awk '!seen[$0]++' "$checksum_file" > "${checksum_file}.tmp"
    mv "${checksum_file}.tmp" "$checksum_file"
}

verify_checksum_entry() {
    local file="$1"
    local entry_path="$2"
    local checksum_file="${3:-$ROOTDIR/macos/checksums.sha256}"
    local label="${4:-backup binary}"
    local hash=""

    if [ ! -f "$file" ]; then
        echo "Error: ${label} not found at $file"
        debug_list_dir "$(dirname "$file")"
        return 2
    fi
    if [ ! -f "$checksum_file" ]; then
        echo "Error: $checksum_file not found."
        debug_list_dir "$(dirname "$checksum_file")"
        return 2
    fi

    if command -v shasum >/dev/null 2>&1; then
        hash="$(shasum -a 256 "$file" | awk '{print $1}')"
    elif command -v sha256sum >/dev/null 2>&1; then
        hash="$(sha256sum "$file" | awk '{print $1}')"
    else
        echo "Error: Neither shasum nor sha256sum found."
        return 2
    fi

    if ! awk -v h="$hash" \
        -v p="$entry_path" \
        '$1 == h && index($0, p) { found=1 } END { exit found ? 0 : 1 }' \
        "$checksum_file"; then
        return 1
    fi
    return 0
}
