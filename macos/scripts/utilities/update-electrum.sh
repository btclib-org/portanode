#!/bin/bash
# Update Electrum binaries
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TMPDIR="$ROOTDIR/macos/bin/.tmp-downloads/electrum"
cd "$ROOTDIR"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Updating Electrum..."

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    EXT="dmg"
    BACKUP_DIR="$ROOTDIR/macos/bin/backup/electrum"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="windows"
    EXT="exe"
    BACKUP_DIR="$ROOTDIR/win/bin/backup/electrum"
else
    echo "Unsupported OS"
    exit 1
fi

HTML="$(curl -s -H "User-Agent: PortaNode" https://electrum.org/)"
VERSION="$(echo "$HTML" | grep -o 'Latest release: Electrum-[0-9][0-9.]*' | head -n 1 | sed -E 's/.*Electrum-//')"
if [ -z "$VERSION" ]; then
    echo "Failed to determine latest Electrum version from electrum.org."
    exit 1
fi

BASE_URL="https://download.electrum.org/${VERSION}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    URL="${BASE_URL}/electrum-${VERSION}.dmg"
    OUT_FILE="electrum-${VERSION}.dmg"
    SIG_FILE="${OUT_FILE}.asc"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    URL="${BASE_URL}/electrum-${VERSION}-portable.exe"
    OUT_FILE="electrum-${VERSION}-portable.exe"
    SIG_FILE="${OUT_FILE}.asc"
fi

mkdir -p "$TMPDIR"
echo "Downloading $URL..."
curl -L -o "$TMPDIR/$OUT_FILE" "$URL"
curl -L -o "$TMPDIR/$SIG_FILE" "${URL}.asc"

if command -v gpg >/dev/null 2>&1; then
    echo "Verifying Electrum signature..."
    (cd "$TMPDIR" && gpg --verify "$SIG_FILE" "$OUT_FILE") || { echo "PGP signature verification failed"; exit 1; }
else
    echo "Warning: gpg not found; skipping PGP signature verification."
fi

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
    if [ ! -d "$ROOTDIR/macos/bin/Electrum.app" ]; then
        echo "Error: macos/bin/Electrum.app not found. Install the app bundle first."
        exit 1
    fi
    mkdir -p "$BACKUP_DIR"
    cp -R "$ROOTDIR/macos/bin/Electrum.app" "$BACKUP_DIR/Electrum.app"
    MOUNT_INFO="$(hdiutil attach -nobrowse "$TMPDIR/$OUT_FILE")"
    MOUNT_POINT="$(echo "$MOUNT_INFO" | tail -n 1 | awk '{print $3}')"
    if [ -z "$MOUNT_POINT" ]; then
        echo "Failed to mount Electrum DMG."
        exit 1
    fi
    rm -rf "$ROOTDIR/macos/bin/Electrum.app"
    cp -R "${MOUNT_POINT}/Electrum.app" "$ROOTDIR/macos/bin/Electrum.app"
    hdiutil detach "$MOUNT_POINT" >/dev/null
    update_checksum "macos/bin/Electrum.app/Contents/MacOS/run_electrum" "$VERSION"
elif [[ "$OSTYPE" == "msys" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp "$ROOTDIR/win/bin/electrum.exe" "$BACKUP_DIR/" 2>/dev/null || true
    cp "$TMPDIR/$OUT_FILE" "$ROOTDIR/win/bin/electrum.exe"
    update_checksum "win/bin/electrum.exe" "$VERSION"
fi

# Cleanup
rm -rf "$TMPDIR"
trap - EXIT

echo "Electrum updated to $VERSION"

if [ -x "$SCRIPT_DIR/verify-binaries.sh" ]; then
    bash "$SCRIPT_DIR/verify-binaries.sh"
else
    echo "Warning: verify-binaries.sh not found or not executable; skipping verification."
fi
