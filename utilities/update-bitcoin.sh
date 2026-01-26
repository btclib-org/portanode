#!/bin/bash
# Update Bitcoin Core binaries
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$ROOTDIR/win/bin-backup/bitcoin"
cd "$ROOTDIR"

echo "Updating Bitcoin Core..."

# Get latest version from API (pinned for reliability)
VERSION="30.2"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="apple-darwin"
    EXT="tar.gz"
    ARCH="$(uname -m)"
    if [ "$ARCH" = "arm64" ]; then
        FILE="bitcoin-${VERSION}-arm64-${OS}.${EXT}"
    else
        FILE="bitcoin-${VERSION}-x86_64-${OS}.${EXT}"
    fi
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="win64"
    EXT="zip"
    FILE="bitcoin-${VERSION}-${OS}.${EXT}"
else
    echo "Unsupported OS"
    exit 1
fi

URL="https://bitcoincore.org/bin/bitcoin-core-${VERSION}/${FILE}"
CHECKSUM_URL="https://bitcoincore.org/bin/bitcoin-core-${VERSION}/SHA256SUMS"

echo "Downloading $URL..."
curl -O "$URL"
curl -O "$CHECKSUM_URL"

# Verify
if command -v shasum >/dev/null 2>&1; then
    grep "$FILE" SHA256SUMS > SHA256SUMS.filtered
    shasum -a 256 -c SHA256SUMS.filtered || { echo "Checksum failed"; exit 1; }
elif command -v sha256sum >/dev/null 2>&1; then
    grep "$FILE" SHA256SUMS > SHA256SUMS.filtered
    sha256sum -c SHA256SUMS.filtered || { echo "Checksum failed"; exit 1; }
else
    echo "Error: Neither shasum nor sha256sum found."
    exit 1
fi

# Extract
if [ "$EXT" = "tar.gz" ]; then
    tar -xzf "$FILE"
    SRC_DIR="bitcoin-${VERSION}"
else
    unzip "$FILE"
    SRC_DIR="bitcoin-${VERSION}"
fi

# Replace binaries
update_checksum() {
    local file="$1"
    local checksum_file="$ROOTDIR/checksums.sha256"
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
    awk -v file="$file" 'BEGIN{updated=0} $2==file{next} {print} END{}' "$checksum_file" > "${checksum_file}.tmp"
    echo "$hash  $file" >> "${checksum_file}.tmp"
    mv "${checksum_file}.tmp" "$checksum_file"
}

if [[ "$OSTYPE" == "darwin"* ]]; then
    BACKUP_DIR="$ROOTDIR/macos/bin-backup/bitcoin"
    mkdir -p "$BACKUP_DIR"
    if [ ! -d "$ROOTDIR/macos/bin/Bitcoin-Qt.app" ]; then
        echo "Error: macos/bin/Bitcoin-Qt.app not found. Install the app bundle first."
        exit 1
    fi
    cp -R "$ROOTDIR/macos/bin/Bitcoin-Qt.app" "$BACKUP_DIR/Bitcoin-Qt.app"
    cp "${SRC_DIR}/bin/bitcoin-qt" "$ROOTDIR/macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"
    update_checksum "macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"
elif [[ "$OSTYPE" == "msys" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp "$ROOTDIR/win/bin/bitcoin"*.exe "$BACKUP_DIR/" 2>/dev/null || true
    cp "${SRC_DIR}/bin/"*.exe "$ROOTDIR/win/bin/"
    for exe in win/bin/bitcoin-qt.exe win/bin/bitcoind.exe win/bin/bitcoin-cli.exe win/bin/bitcoin-wallet.exe win/bin/bitcoin-tx.exe win/bin/bitcoin-util.exe win/bin/bitcoin.exe; do
        if [ -f "$exe" ]; then
            update_checksum "$exe"
        fi
    done
fi

# Cleanup
rm -rf "$SRC_DIR" "$FILE" SHA256SUMS SHA256SUMS.filtered

echo "Bitcoin Core updated to $VERSION"

if [ -x "$SCRIPT_DIR/verify-binaries.sh" ]; then
    "$SCRIPT_DIR/verify-binaries.sh"
else
    echo "Warning: verify-binaries.sh not found or not executable; skipping verification."
fi
