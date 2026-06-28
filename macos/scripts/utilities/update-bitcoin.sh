#!/bin/bash
# Update Bitcoin Core binaries
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
cd "$ROOTDIR"

# Detect OS/arch (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="apple-darwin"
    # Use the official notarized release archive (the ".zip" ships the
    # Apple-signed, notarized Bitcoin-Qt.app). The "-codesigning" archive is
    # the project's *unsigned* internal build artifact; on Apple Silicon an
    # unsigned binary is killed by the kernel with SIGKILL ("Killed: 9").
    EXT="zip"
    ARCH="$(uname -m)"
    if [ "$ARCH" = "arm64" ]; then
        ARCH_TAG="arm64"
    else
        ARCH_TAG="x86_64"
    fi
    APP_NAME="Bitcoin-Qt.app"
    APP_DIR="$ROOTDIR/macos/bin"
    APP_BACKUP_DIR="$APP_DIR/backup/bitcoin"
    TMP_DIR="$ROOTDIR/macos/bin/.tmp-downloads/bitcoin"
else
    echo "Unsupported OS (macOS only)."
    exit 1
fi

# Release archive name for a given version.
release_file() { echo "bitcoin-$1-${ARCH_TAG}-${OS}.${EXT}"; }

# Pick the newest release on bitcoincore.org that actually ships a macOS
# archive (mirrors how update-electrum.sh auto-detects the latest Electrum).
# The index can list version directories that are empty (a release not yet
# published) or that lack macOS builds, so we probe newest-first and skip any
# candidate whose archive is missing. Legacy 0.x releases are excluded so the
# numeric sort picks a modern version.
echo "Determining latest Bitcoin Core version..."
INDEX_HTML="$(curl -fsSL -H "User-Agent: PortaNode" https://bitcoincore.org/bin/)"
CANDIDATES="$(
  echo "$INDEX_HTML" \
    | sed -nE 's/.*href="bitcoin-core-([0-9]+\.[0-9]+(\.[0-9]+)?)\/".*/\1/p' \
    | grep -vE '^0\.' \
    | sort -t. -k1,1nr -k2,2nr -k3,3nr
)"
VERSION=""
for candidate in $CANDIDATES; do
    candidate_url="https://bitcoincore.org/bin/bitcoin-core-${candidate}/$(release_file "$candidate")"
    if curl -fsIL -o /dev/null "$candidate_url"; then
        VERSION="$candidate"
        break
    fi
    echo "Skipping ${candidate} (no macOS archive published)."
done
if [ -z "$VERSION" ]; then
    echo "Failed to find a Bitcoin Core release with a macOS archive on" \
         "bitcoincore.org."
    exit 1
fi
FILE="$(release_file "$VERSION")"
echo "Latest Bitcoin Core with a macOS build: ${VERSION}"

# Prevent updates while running. pgrep on macOS/BSD uses extended regular
# expressions, so alternation is "|" (a GNU-BRE "\|" matches a literal pipe and
# never matches a real process, which would let the update run while Bitcoin is).
BTC_PGREP_PATTERN="bitcoind|bitcoin-qt|bitcoin qt|${APP_NAME}"
if pgrep -f -i "$BTC_PGREP_PATTERN" > /dev/null; then
    echo "Error: Bitcoin Core is running. Stop it before updating."
    exit 1
fi

echo "Updating Bitcoin Core..."

# Get requested binaries

URL="https://bitcoincore.org/bin/bitcoin-core-${VERSION}/${FILE}"
CHECKSUM_URL="https://bitcoincore.org/bin/bitcoin-core-${VERSION}/SHA256SUMS"
CHECKSUM_SIG_URL="https://bitcoincore.org/bin/bitcoin-core-${VERSION}/"\
"SHA256SUMS.asc"

trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR"

echo "Downloading $URL..."
curl -fL -o "$TMP_DIR/$FILE" "$URL"
echo "Downloading $CHECKSUM_URL..."
curl -fL -o "$TMP_DIR/SHA256SUMS" "$CHECKSUM_URL"
echo "Downloading $CHECKSUM_SIG_URL..."
curl -fL -o "$TMP_DIR/SHA256SUMS.asc" "$CHECKSUM_SIG_URL"

# Verify
UPDATE_CHECKSUMS=0
if ! pgp_verify_or_warn \
  "$TMP_DIR/SHA256SUMS.asc" \
  "$TMP_DIR/SHA256SUMS" \
  "SHA256SUMS" \
  UPDATE_CHECKSUMS; then
    exit 1
fi
if command -v shasum >/dev/null 2>&1; then
    grep "$FILE" "$TMP_DIR/SHA256SUMS" > "$TMP_DIR/SHA256SUMS.filtered"
    if ! (cd "$TMP_DIR" && shasum -a 256 -c SHA256SUMS.filtered); then
        echo "Checksum failed"
        exit 1
    fi
elif command -v sha256sum >/dev/null 2>&1; then
    grep "$FILE" "$TMP_DIR/SHA256SUMS" > "$TMP_DIR/SHA256SUMS.filtered"
    if ! (cd "$TMP_DIR" && sha256sum -c SHA256SUMS.filtered); then
        echo "Checksum failed"
        exit 1
    fi
else
    echo "Error: Neither shasum nor sha256sum found."
    exit 1
fi

# Extract
if [ "$EXT" = "tar.gz" ]; then
    tar -xzf "$TMP_DIR/$FILE" -C "$TMP_DIR"
    TMP_APP_DIR="$TMP_DIR/bitcoin-${VERSION}"
else
    unzip "$TMP_DIR/$FILE" -d "$TMP_DIR"
    TMP_APP_DIR="$TMP_DIR/bitcoin-${VERSION}"
fi

# Locate extracted app bundle
TMP_APP=""
if [ -d "$TMP_DIR/dist/$APP_NAME" ]; then
    TMP_APP="$TMP_DIR/dist/$APP_NAME"
elif [ -d "$TMP_DIR/$APP_NAME" ]; then
    TMP_APP="$TMP_DIR/$APP_NAME"
elif [ -d "$TMP_APP_DIR/$APP_NAME" ]; then
    TMP_APP="$TMP_APP_DIR/$APP_NAME"
elif [ -d "$TMP_APP_DIR/bin/$APP_NAME" ]; then
    TMP_APP="$TMP_APP_DIR/bin/$APP_NAME"
fi
if [ -z "$TMP_APP" ]; then
    echo "Error: ${APP_NAME} not found in extracted archive."
    debug_list_dir "$TMP_DIR"
    debug_list_dir "$TMP_APP_DIR"
    exit 1
fi

if [ $UPDATE_CHECKSUMS -eq 1 ]; then
    update_checksum \
      "$TMP_APP/Contents/MacOS/Bitcoin-Qt" \
      "macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" \
      "$VERSION"
else
    echo "Warning: PGP signature(s) not verified; skipping checksum update."
fi

# Replace binaries
if [[ "$OSTYPE" == "darwin"* ]]; then
    APP="$APP_DIR/${APP_NAME}"
    mkdir -p "$APP_DIR"
    if [ -d "$APP" ]; then
        mkdir -p "$APP_BACKUP_DIR"
        rm -rf "$APP_BACKUP_DIR/${APP_NAME}"
        cp -R "$APP" "$APP_BACKUP_DIR/${APP_NAME}"
    fi

    rm -rf "$APP"
    cp -R "$TMP_APP" "$APP"
fi

# Cleanup
rm -rf "$TMP_DIR"
trap - EXIT

echo "Bitcoin Core updated to $VERSION"
