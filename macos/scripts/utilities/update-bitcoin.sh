#!/bin/bash
# Update Bitcoin Core binaries
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TMPDIR="$ROOTDIR/macos/bin/.tmp-downloads/bitcoin"
cd "$ROOTDIR"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Updating Bitcoin Core..."

# Prevent updates while running
if pgrep -f -i "bitcoind\\|bitcoin-qt\\|bitcoin qt\\|bitcoin-qt.app" > /dev/null; then
    echo "Error: Bitcoin Core is running. Stop it before updating."
    exit 1
fi

# Get latest version from API (pinned for reliability)
VERSION="30.2"

# Detect OS (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="apple-darwin"
    EXT="tar.gz"
    BACKUP_DIR="$ROOTDIR/macos/bin/backup/bitcoin"
    ARCH="$(uname -m)"
    if [ "$ARCH" = "arm64" ]; then
        FILE="bitcoin-${VERSION}-arm64-${OS}.${EXT}"
    else
        FILE="bitcoin-${VERSION}-x86_64-${OS}.${EXT}"
    fi
else
    echo "Unsupported OS (macOS only)."
    exit 1
fi

URL="https://bitcoincore.org/bin/bitcoin-core-${VERSION}/${FILE}"
CHECKSUM_URL="https://bitcoincore.org/bin/bitcoin-core-${VERSION}/SHA256SUMS"
CHECKSUM_SIG_URL="https://bitcoincore.org/bin/bitcoin-core-${VERSION}/SHA256SUMS.asc"

mkdir -p "$TMPDIR"
echo "Downloading $URL..."
curl -L -o "$TMPDIR/$FILE" "$URL"
curl -L -o "$TMPDIR/SHA256SUMS" "$CHECKSUM_URL"
curl -L -o "$TMPDIR/SHA256SUMS.asc" "$CHECKSUM_SIG_URL"

# Verify
if command -v gpg >/dev/null 2>&1; then
    echo "Verifying SHA256SUMS signature..."
    (cd "$TMPDIR" && gpg --verify SHA256SUMS.asc SHA256SUMS) || { echo "PGP signature verification failed"; exit 1; }
else
    echo "Warning: gpg not found; skipping PGP signature verification."
fi
if command -v shasum >/dev/null 2>&1; then
    grep "$FILE" "$TMPDIR/SHA256SUMS" > "$TMPDIR/SHA256SUMS.filtered"
    (cd "$TMPDIR" && shasum -a 256 -c SHA256SUMS.filtered) || { echo "Checksum failed"; exit 1; }
elif command -v sha256sum >/dev/null 2>&1; then
    grep "$FILE" "$TMPDIR/SHA256SUMS" > "$TMPDIR/SHA256SUMS.filtered"
    (cd "$TMPDIR" && sha256sum -c SHA256SUMS.filtered) || { echo "Checksum failed"; exit 1; }
else
    echo "Error: Neither shasum nor sha256sum found."
    exit 1
fi

# Extract
if [ "$EXT" = "tar.gz" ]; then
    tar -xzf "$TMPDIR/$FILE" -C "$TMPDIR"
    SRC_DIR="$TMPDIR/bitcoin-${VERSION}"
else
    unzip "$TMPDIR/$FILE" -d "$TMPDIR"
    SRC_DIR="$TMPDIR/bitcoin-${VERSION}"
fi

# Replace binaries
update_checksum() {
    local file="$1"
    local version="$2"
    local checksum_file="$ROOTDIR/macos/checksums.sha256"
    local hash=""
    if command -v shasum >/dev/null 2>&1; then
        hash="$(shasum -a 256 "$file" | awk '{print $1}')"
    elif command -v sha256sum >/dev/null 2>&1; then
        hash="$(sha256sum "$file" | awk '{print $1}')"
    else
        echo "Warning: shasum/sha256sum not found; checksums not updated."
        return 0
    fi
    if [ ! -f "$checksum_file" ]; then
        echo "Warning: $checksum_file not found; checksums not updated."
        return 0
    fi
    local entry="$hash  $file  version=$version"
    if ! grep -Fxq "$entry" "$checksum_file"; then
        echo "$entry" >> "$checksum_file"
    fi
    awk '!seen[$0]++' "$checksum_file" > "${checksum_file}.tmp"
    mv "${checksum_file}.tmp" "$checksum_file"
}

if [[ "$OSTYPE" == "darwin"* ]]; then
    BACKUP_DIR="$ROOTDIR/macos/bin/backup/bitcoin"
    mkdir -p "$BACKUP_DIR"
    if [ ! -d "$ROOTDIR/macos/bin/Bitcoin-Qt.app" ]; then
        echo "Error: macos/bin/Bitcoin-Qt.app not found. Install the app bundle first."
        exit 1
    fi
    cp -R "$ROOTDIR/macos/bin/Bitcoin-Qt.app" "$BACKUP_DIR/Bitcoin-Qt.app"
    cp "${SRC_DIR}/bin/bitcoin-qt" "$ROOTDIR/macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"
    update_checksum "macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" "$VERSION"
fi

# Cleanup
rm -rf "$TMPDIR"
trap - EXIT

echo "Bitcoin Core updated to $VERSION"

if [ -x "$SCRIPT_DIR/verify-binaries.sh" ]; then
    bash "$SCRIPT_DIR/verify-binaries.sh"
else
    echo "Warning: verify-binaries.sh not found or not executable; skipping verification."
fi
