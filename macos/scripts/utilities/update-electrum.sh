#!/bin/bash
# Update Electrum Version
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
# Download/verify/mount on the local (APFS) temp dir, never on the removable
# exFAT volume; only the final, verified Electrum.app is copied onto exFAT.
TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/portanode-electrum.XXXXXX")"
cd "$ROOTDIR"
trap 'rm -rf "$TMPDIR"' EXIT

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

INDEX_HTML="$(curl -fsSL -H "User-Agent: PortaNode" https://download.electrum.org/)"
VERSION="$(
  echo "$INDEX_HTML" \
    | sed -nE 's/.*href="([0-9]+\.[0-9]+\.[0-9]+)\/".*/\1/p' \
    | sort -t. -k1,1n -k2,2n -k3,3n \
    | tail -n 1
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
curl -fL -o "$TMPDIR/$OUT_FILE" "$URL"
curl -fL -o "$TMPDIR/$SIG_FILE" "${URL}.asc"

PGP_OK=0
if ! pgp_verify_or_fail \
  "$TMPDIR/$SIG_FILE" \
  "$TMPDIR/$OUT_FILE" \
  "Electrum" \
  PGP_OK \
  "$ROOTDIR/keys/electrum.fingerprints"; then
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
install_rc=0
install_verified "${MOUNT_POINT}/Electrum.app" \
  "$ROOTDIR/macos/bin/Electrum.app" || install_rc=1
hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
if [ "$install_rc" -ne 0 ]; then
    exit 1
fi
if [ "$PGP_OK" -eq 1 ]; then
    update_checksum \
      "macos/bin/Electrum.app/Contents/MacOS/run_electrum" \
      "macos/bin/Electrum.app/Contents/MacOS/run_electrum" \
      "$VERSION"
    echo "Verifying installed Electrum against checksums.sha256..."
    if ! verify_checksum_entry \
        "$ROOTDIR/macos/bin/Electrum.app/Contents/MacOS/run_electrum" \
        "macos/bin/Electrum.app/Contents/MacOS/run_electrum" \
        "$ROOTDIR/macos/checksums.sha256" "Electrum"; then
        echo "Error: post-install verification failed (filesystem corruption?)."
        exit 1
    fi
    echo "Electrum verified."
else
    echo "Warning: PGP signature(s) not verified; skipping checksum update."
fi

# Cleanup
rm -rf "$TMPDIR"
trap - EXIT

echo "Electrum updated to $VERSION"
