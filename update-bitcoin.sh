#!/bin/bash
# Update Bitcoin Core binaries

echo "Updating Bitcoin Core..."

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="osx64"
    EXT="tar.gz"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="win64"
    EXT="zip"
else
    echo "Unsupported OS"
    exit 1
fi

# Get latest version from API or hardcoded
VERSION="26.0"  # Update manually or fetch from https://api.github.com/repos/bitcoin/bitcoin/releases/latest

URL="https://bitcoin.org/bin/bitcoin-core-${VERSION}/bitcoin-${VERSION}-${OS}.${EXT}"
CHECKSUM_URL="${URL}.SHA256SUMS"

echo "Downloading $URL..."
curl -O "$URL"
curl -O "$CHECKSUM_URL"

# Verify
shasum -a 256 -c <(grep "bitcoin-${VERSION}-${OS}.${EXT}" *.SHA256SUMS) || { echo "Checksum failed"; exit 1; }

# Extract
if [ "$EXT" = "tar.gz" ]; then
    tar -xzf "bitcoin-${VERSION}-${OS}.${EXT}"
    SRC_DIR="bitcoin-${VERSION}"
else
    unzip "bitcoin-${VERSION}-${OS}.${EXT}"
    SRC_DIR="bitcoin-${VERSION}"
fi

# Replace binaries
if [[ "$OSTYPE" == "darwin"* ]]; then
    mkdir -p bin-backup-bitcoin
    cp macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt bin-backup-bitcoin/ 2>/dev/null || true
    cp "${SRC_DIR}/bin/bitcoin-qt" macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt
    # Others if needed
elif [[ "$OSTYPE" == "msys" ]]; then
    mkdir -p bin-backup-bitcoin
    cp win/bin/bitcoin*.exe bin-backup-bitcoin/ 2>/dev/null || true
    cp "${SRC_DIR}/bin/"*.exe win/bin/
fi

# Update checksums
echo "Updating checksums.sha256..."
# Regenerate or update manually

# Cleanup
rm -rf "$SRC_DIR" "bitcoin-${VERSION}-${OS}.${EXT}" *.SHA256SUMS

echo "Bitcoin Core updated to $VERSION"