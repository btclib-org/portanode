#!/bin/bash
# Update Electrum Version
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=macos/scripts/utilities/lib.sh
. "$SCRIPT_DIR/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"

VERSION_OVERRIDE=""
DRY_RUN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --version)
            VERSION_OVERRIDE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            echo "Usage: $(basename "$0") [--version <v>] [--dry-run]" >&2
            exit 1
            ;;
    esac
done

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
    BACKUP_DIR="$ROOTDIR/macos/bin/backup/electrum"
else
    echo "Unsupported OS (macOS only)."
    exit 1
fi

if [ -n "$VERSION_OVERRIDE" ]; then
    VERSION="$VERSION_OVERRIDE"
    echo "Requested Electrum version: ${VERSION}"
else
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
fi

BASE_URL="https://download.electrum.org/${VERSION}"
URL="${BASE_URL}/electrum-${VERSION}.dmg"
OUT_FILE="electrum-${VERSION}.dmg"
SIG_FILE="${OUT_FILE}.asc"

if [ "$DRY_RUN" -eq 1 ]; then
    CURRENT="$(installed_version \
      "$ROOTDIR/macos/bin/Electrum.app/Contents/MacOS/run_electrum" \
      "macos/bin/Electrum.app/Contents/MacOS/run_electrum" \
      "$ROOTDIR/macos/checksums.sha256")"
    echo "--dry-run: nothing will be downloaded, verified or installed."
    echo "Would install Electrum ${VERSION} (currently installed: ${CURRENT})."
    echo "Would fetch: $URL"
    if command -v gpg >/dev/null 2>&1; then
        FPR="$(grep -m1 -E '^[0-9A-Fa-f]{40}$' "$ROOTDIR/keys/electrum.fingerprints" \
          2>/dev/null || true)"
        if [ -n "$FPR" ]; then
            if gpg --list-keys "$FPR" >/dev/null 2>&1; then
                echo "gpg: found, pinned key $FPR is in the local keyring."
            else
                echo "gpg: found, but pinned key $FPR is NOT in the local" \
                     "keyring -- verification would fail closed unless" \
                     "PORTANODE_ALLOW_UNVERIFIED=1 is set."
            fi
        else
            echo "gpg: found, no pinned fingerprint in" \
                 "keys/electrum.fingerprints."
        fi
    else
        echo "gpg: not found -- verification would fail closed unless" \
             "PORTANODE_ALLOW_UNVERIFIED=1 is set."
    fi
    ARCHIVE_LEN="$(curl -fsIL "$URL" \
      | tr -d '\r' | awk -F': ' 'tolower($1)=="content-length"{v=$2} END{print v}')"
    if [ -n "$ARCHIVE_LEN" ]; then
        echo "Archive size: $((ARCHIVE_LEN / 1024 / 1024)) MB" \
             "(downloaded to local temp storage, not the removable disk)."
    fi
    df -h "$ROOTDIR" | awk -v r="$ROOTDIR" 'NR==2 {print "Free space at " r ": " $4}'
    exit 0
fi

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
