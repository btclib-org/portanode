#!/bin/bash
# Update Bitcoin Core binaries
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
cd "$ROOTDIR"

# Latest version pinned for reliability
VERSION="30.2"

# Detect OS (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="apple-darwin"
    EXT="tar.gz"
    ARCH="$(uname -m)"
    if [ "$ARCH" = "arm64" ]; then
        FILE="bitcoin-${VERSION}-arm64-${OS}-codesigning.${EXT}"
    else
        FILE="bitcoin-${VERSION}-x86_64-${OS}-codesigning.${EXT}"
    fi
    APP_NAME="Bitcoin-Qt.app"
    APP_DIR="$ROOTDIR/macos/bin"
    APP_BACKUP_DIR="$APP_DIR/backup/bitcoin"
    TMP_DIR="$ROOTDIR/macos/bin/.tmp-downloads/bitcoin"
else
    echo "Unsupported OS (macOS only)."
    exit 1
fi

# Prevent updates while running
BTC_PGREP_PATTERN="bitcoind\\|bitcoin-qt\\|bitcoin qt\\|${APP_NAME}"
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
curl -L -o "$TMP_DIR/$FILE" "$URL"
echo "Downloading $CHECKSUM_URL..."
curl -L -o "$TMP_DIR/SHA256SUMS" "$CHECKSUM_URL"
echo "Downloading $CHECKSUM_SIG_URL..."
curl -L -o "$TMP_DIR/SHA256SUMS.asc" "$CHECKSUM_SIG_URL"

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
