#!/bin/bash
# Update Electrum Version
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TMPDIR="$ROOTDIR/macos/bin/.tmp-downloads/electrum"
cd "$ROOTDIR"
trap 'rm -rf "$TMPDIR"' EXIT

. "$SCRIPT_DIR/lib.sh"

echo "Updating Electrum..."

# Prevent updates while running
ELECTRUM_PGREP_PATTERN="Electrum.app/Contents/MacOS/(Electrum|run_electrum)$"
ELECTRUM_PGREP_PATTERN="${ELECTRUM_PGREP_PATTERN}|/Electrum$|/electrum$"
ELECTRUM_PGREP_PATTERN="${ELECTRUM_PGREP_PATTERN}|python.*electrum"
ELECTRUM_PGREP_PATTERN="${ELECTRUM_PGREP_PATTERN}|run_electrum"
if pgrep -f -i "$ELECTRUM_PGREP_PATTERN" > /dev/null; then
    echo "Error: Electrum is running. Stop it before updating."
    exit 1
fi

# Detect OS (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    EXT="dmg"
    BACKUP_DIR="$ROOTDIR/macos/bin/backup/electrum"
else
    echo "Unsupported OS (macOS only)."
    exit 1
fi

HTML="$(curl -s -H "User-Agent: PortaNode" https://electrum.org/)"
VERSION="$(
  echo "$HTML" \
    | grep -o 'Latest release: Electrum-[0-9][0-9.]*' \
    | head -n 1 \
    | sed -E 's/.*Electrum-//'
)"
if [ -z "$VERSION" ]; then
    echo "Failed to determine latest Electrum version from electrum.org."
    exit 1
fi

BASE_URL="https://download.electrum.org/${VERSION}"
URL="${BASE_URL}/electrum-${VERSION}.dmg"
OUT_FILE="electrum-${VERSION}.dmg"
SIG_FILE="${OUT_FILE}.asc"

mkdir -p "$TMPDIR"
echo "Downloading $URL..."
curl -L -o "$TMPDIR/$OUT_FILE" "$URL"
curl -L -o "$TMPDIR/$SIG_FILE" "${URL}.asc"

PGP_OK=0
if ! pgp_verify_or_warn \
  "$TMPDIR/$SIG_FILE" \
  "$TMPDIR/$OUT_FILE" \
  "Electrum" \
  PGP_OK; then
    exit 1
fi

mkdir -p "$ROOTDIR/macos/bin"
mkdir -p "$BACKUP_DIR"
rm -rf "$BACKUP_DIR/Electrum.app"
if [ -d "$ROOTDIR/macos/bin/Electrum.app" ]; then
    cp -R "$ROOTDIR/macos/bin/Electrum.app" "$BACKUP_DIR/Electrum.app"
fi
MOUNT_INFO="$(hdiutil attach -nobrowse "$TMPDIR/$OUT_FILE")"
MOUNT_POINT="$(echo "$MOUNT_INFO" | tail -n 1 | awk '{print $3}')"
if [ -z "$MOUNT_POINT" ]; then
    echo "Failed to mount Electrum DMG."
    exit 1
fi
if [ ! -d "${MOUNT_POINT}/Electrum.app" ]; then
    echo "Electrum.app not found in mounted DMG."
    debug_list_dir "$MOUNT_POINT"
    hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
    exit 1
fi
rm -rf "$ROOTDIR/macos/bin/Electrum.app"
cp -R "${MOUNT_POINT}/Electrum.app" "$ROOTDIR/macos/bin/Electrum.app"
hdiutil detach "$MOUNT_POINT" >/dev/null
if [ "$PGP_OK" -eq 1 ]; then
    update_checksum \
      "macos/bin/Electrum.app/Contents/MacOS/run_electrum" \
      "macos/bin/Electrum.app/Contents/MacOS/run_electrum" \
      "$VERSION"
else
    echo "Warning: PGP signature(s) not verified; skipping checksum update."
fi

# Cleanup
rm -rf "$TMPDIR"
trap - EXIT

echo "Electrum updated to $VERSION"
