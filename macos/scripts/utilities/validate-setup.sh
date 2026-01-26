#!/bin/bash
# Validate PortaNode setup: binaries, checksums, permissions, disk space
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "Validating PortaNode setup..."

# Check binaries exist
BINARIES=(
    "$ROOTDIR/macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"
    "$ROOTDIR/macos/bin/Electrum.app/Contents/MacOS/run_electrum"
)
for bin in "${BINARIES[@]}"; do
    if [ ! -f "$bin" ]; then
        echo "ERROR: Binary $bin not found."
        exit 1
    fi
done
echo "✓ Binaries present"

# Check checksums
if [ -x "$SCRIPT_DIR/verify-binaries.sh" ]; then
    bash "$SCRIPT_DIR/verify-binaries.sh"
    echo "✓ Checksums valid"
else
    echo "WARNING: verify-binaries.sh not found, skipping checksum check"
fi

versions_for() {
    local relpath="$1"
    local file="$ROOTDIR/$relpath"
    local hash=""
    if [ -f "$file" ]; then
        if command -v shasum >/dev/null 2>&1; then
            hash="$(shasum -a 256 "$file" | awk '{print $1}')"
        elif command -v sha256sum >/dev/null 2>&1; then
            hash="$(sha256sum "$file" | awk '{print $1}')"
        fi
    fi
    [ -z "$hash" ] && return 0
    versions=()
    while IFS= read -r line; do
        case "$line" in
            ""|\#*) continue ;;
        esac
        line_hash="${line%%[[:space:]]*}"
        rest="${line#"$line_hash"}"
        rest="${rest#"${rest%%[![:space:]]*}"}"
        path="$rest"
        ver="unknown"
        if [[ "$rest" == *"version="* ]]; then
            ver="${rest##*version=}"
            path="${rest%version=*}"
            path="${path%"${path##*[![:space:]]}"}"
            ver="${ver#"${ver%%[![:space:]]*}"}"
        fi
        if [ "$path" = "$relpath" ] && [ "$line_hash" = "$hash" ]; then
            versions+=("$ver")
        fi
    done < "$ROOTDIR/macos/checksums.sha256"
    if [ "${#versions[@]}" -gt 0 ]; then
        printf "%s\n" "$(printf "%s, " "${versions[@]}" | sed 's/, $//')"
    fi
}

# Check permissions (basic)
if [ -d "$ROOTDIR/bitcoin-datadir" ] && [ -d "$ROOTDIR/electrum-datadir" ]; then
    # On macOS, check if directories are accessible
    echo "✓ Data directories exist"
else
    echo "WARNING: Data directories not found"
fi

echo "Binary versions:"
for bin in "${BINARIES[@]}"; do
    rel="${bin#$ROOTDIR/}"
    vers="$(versions_for "$rel")"
    if [ -n "$vers" ]; then
        echo "- $rel: $vers"
    else
        echo "- $rel: unknown"
    fi
done

# Check disk space (require at least 100GB free)
DISK_FREE_KB=$(df -Pk "$ROOTDIR" | awk 'NR==2 {print $4}')
DISK_FREE_HUMAN=$(df -h "$ROOTDIR" | awk 'NR==2 {print $4}')
REQUIRED_KB=$((100 * 1024 * 1024))
echo "Disk free space: $DISK_FREE_HUMAN"
if [ "$DISK_FREE_KB" -lt "$REQUIRED_KB" ]; then
    echo "ERROR: Less than 100GB free."
    exit 1
fi

echo "Validation complete. Setup looks good!"
