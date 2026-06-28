#!/bin/bash
# Shared helpers for macOS utility scripts.

_UTILS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_UTILS_LIB_DIR/../lib.sh"
unset _UTILS_LIB_DIR

debug_list_dir() {
    local dir="$1"
    echo "Debug: $dir contents: $(ls -a "$dir" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
}

# pgp_verify_or_fail SIG_FILE DATA_FILE LABEL OUT_VAR [FPR_FILE]
#
# Verifies DATA_FILE against the detached SIG_FILE. FAILS CLOSED: returns
# non-zero (so the caller aborts the install) unless a good signature is found.
# If FPR_FILE is given and non-empty, additionally requires a VALIDSIG whose
# fingerprint is listed there (key pinning); otherwise any GOODSIG is accepted.
# On success sets OUT_VAR to 1 (the caller uses it to gate checksum recording).
#
# Set PORTANODE_ALLOW_UNVERIFIED=1 to bypass verification entirely (installs
# unauthenticated binaries — NOT recommended, intended only as an escape hatch).
pgp_verify_or_fail() {
    local sig_file="$1"
    local data_file="$2"
    local label="$3"
    local out_var="$4"
    local fpr_file="${5:-}"

    if [ -n "$out_var" ]; then
        printf -v "$out_var" '%s' 0
    fi

    if [ "${PORTANODE_ALLOW_UNVERIFIED:-0}" = "1" ]; then
        echo "Warning: PORTANODE_ALLOW_UNVERIFIED=1 set; skipping PGP" \
             "verification of ${label}. Installing UNAUTHENTICATED binaries."
        return 0
    fi

    if ! command -v gpg >/dev/null 2>&1; then
        echo "Error: gpg not found; cannot verify ${label}."
        echo "Install gpg (e.g. 'brew install gnupg') and import the signing" \
             "key, or set PORTANODE_ALLOW_UNVERIFIED=1 to bypass (NOT" \
             "recommended)."
        return 1
    fi

    echo "Verifying ${label} signature..."
    local status_file
    status_file="$(mktemp)"
    gpg --status-fd 1 --verify "$sig_file" "$data_file" 1> "$status_file" \
        2>/dev/null || true

    if grep -q '^\[GNUPG:\] BADSIG' "$status_file"; then
        echo "Error: BAD PGP signature on ${label}."
        rm -f "$status_file"
        return 1
    fi
    if ! grep -q '^\[GNUPG:\] GOODSIG' "$status_file"; then
        echo "Error: no valid PGP signature on ${label}" \
             "(is the signer's key imported?)."
        echo "Import the signing key, or set PORTANODE_ALLOW_UNVERIFIED=1 to" \
             "bypass (NOT recommended)."
        rm -f "$status_file"
        return 1
    fi

    # Optional fingerprint pinning: require a VALIDSIG from a listed key. The
    # VALIDSIG status line carries both the signing-key and primary-key
    # fingerprints, so match a pinned fingerprint anywhere on those lines.
    if [ -n "$fpr_file" ] && [ -s "$fpr_file" ] && \
       grep -qiE '^[[:space:]]*[0-9A-Fa-f]{40}[[:space:]]*$' "$fpr_file"; then
        local validsig_lines fpr matched=0 line
        validsig_lines="$(grep '^\[GNUPG:\] VALIDSIG' "$status_file")"
        while IFS= read -r line; do
            case "$line" in ''|\#*) continue ;; esac
            fpr="$(echo "$line" | tr -d '[:space:]')"
            [ ${#fpr} -eq 40 ] || continue
            if echo "$validsig_lines" | grep -qi -- "$fpr"; then
                matched=1
                break
            fi
        done < "$fpr_file"
        if [ "$matched" -ne 1 ]; then
            echo "Error: ${label} is signed, but not by a pinned key listed" \
                 "in $(basename "$fpr_file")."
            rm -f "$status_file"
            return 1
        fi
    fi

    rm -f "$status_file"
    if [ -n "$out_var" ]; then
        printf -v "$out_var" '%s' 1
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
