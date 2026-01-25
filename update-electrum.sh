#!/bin/bash
# Update Electrum binaries

echo "Updating Electrum..."

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    EXT="dmg"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="windows"
    EXT="exe"
else
    echo "Unsupported OS"
    exit 1
fi

# Get latest version
VERSION=$(curl -s https://api.github.com/repos/spesmilo/electrum/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

URL="https://download.electrum.org/${VERSION}/electrum-${VERSION}-${OS}.${EXT}"

echo "Downloading $URL..."
curl -L -o "electrum-${VERSION}-${OS}.${EXT}" "$URL"

# For simplicity, assume no checksum for Electrum, or add if available
# Replace manually or mount dmg

if [[ "$OSTYPE" == "darwin"* ]]; then
    # Mount dmg and copy
    hdiutil attach "electrum-${VERSION}-${OS}.${EXT}"
    cp /Volumes/Electrum/Electrum.app/Contents/MacOS/run_electrum macos/bin/Electrum.app/Contents/MacOS/
    hdiutil detach /Volumes/Electrum
elif [[ "$OSTYPE" == "msys" ]]; then
    # For exe, it's installer, perhaps download portable
    echo "For Windows, download portable version manually"
fi

# Cleanup
rm "electrum-${VERSION}-${OS}.${EXT}"

echo "Electrum updated to $VERSION"