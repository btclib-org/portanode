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
    # Download/verify/extract on the local (APFS) temp dir, never on the
    # removable exFAT volume: macOS's fskit exFAT driver can silently corrupt
    # files written during extraction. Only the final, verified binaries are
    # copied onto exFAT (see install_verified).
    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/portanode-bitcoin.XXXXXX")"
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

# The ".app" zip ships only the GUI; the command-line tools (bitcoind,
# bitcoin-cli, etc.) live in the loose-binary tarball, so fetch that too and
# install them next to the app in macos/bin/ (putting them inside the signed
# .app bundle would invalidate the bundle's code signature).
CLI_ARCHIVE="bitcoin-${VERSION}-${ARCH_TAG}-${OS}.tar.gz"
BIN_NAMES="bitcoind bitcoin-cli bitcoin-qt bitcoin-tx bitcoin-util bitcoin-wallet"

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
echo "Downloading ${CLI_ARCHIVE} (for CLI tools)..."
curl -fL -o "$TMP_DIR/$CLI_ARCHIVE" \
  "https://bitcoincore.org/bin/bitcoin-core-${VERSION}/${CLI_ARCHIVE}"

# Verify (fails closed; set PORTANODE_ALLOW_UNVERIFIED=1 to bypass)
UPDATE_CHECKSUMS=0
if ! pgp_verify_or_fail \
  "$TMP_DIR/SHA256SUMS.asc" \
  "$TMP_DIR/SHA256SUMS" \
  "SHA256SUMS" \
  UPDATE_CHECKSUMS \
  "$ROOTDIR/keys/bitcoin-core.fingerprints"; then
    exit 1
fi
if command -v shasum >/dev/null 2>&1; then
    grep -F -e "$FILE" -e "$CLI_ARCHIVE" "$TMP_DIR/SHA256SUMS" \
      > "$TMP_DIR/SHA256SUMS.filtered"
    if ! (cd "$TMP_DIR" && shasum -a 256 -c SHA256SUMS.filtered); then
        echo "Checksum failed"
        exit 1
    fi
elif command -v sha256sum >/dev/null 2>&1; then
    grep -F -e "$FILE" -e "$CLI_ARCHIVE" "$TMP_DIR/SHA256SUMS" \
      > "$TMP_DIR/SHA256SUMS.filtered"
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

# Extract the command-line tools from the loose-binary tarball.
TMP_BIN_DIR="$TMP_DIR/bitcoin-${VERSION}/bin"
TAR_MEMBERS=""
for b in $BIN_NAMES; do
    TAR_MEMBERS="$TAR_MEMBERS bitcoin-${VERSION}/bin/$b"
done
tar -xzf "$TMP_DIR/$CLI_ARCHIVE" -C "$TMP_DIR" $TAR_MEMBERS
for b in $BIN_NAMES; do
    if [ ! -x "$TMP_BIN_DIR/$b" ]; then
        echo "Error: $b not found in extracted archive."
        debug_list_dir "$TMP_BIN_DIR"
        exit 1
    fi
done

if [ $UPDATE_CHECKSUMS -eq 1 ]; then
    update_checksum \
      "$TMP_APP/Contents/MacOS/Bitcoin-Qt" \
      "macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" \
      "$VERSION"
    for b in $BIN_NAMES; do
        update_checksum "$TMP_BIN_DIR/$b" "macos/bin/$b" "$VERSION"
    done
else
    echo "Warning: PGP signature(s) not verified; skipping checksum update."
fi

# Replace binaries. Everything below copies from the APFS temp dir onto the
# (possibly exFAT) install dir via install_verified, which re-reads and retries
# until the on-disk copy matches the source byte-for-byte.
if [[ "$OSTYPE" == "darwin"* ]]; then
    APP="$APP_DIR/${APP_NAME}"
    mkdir -p "$APP_DIR"
    if [ -d "$APP" ]; then
        mkdir -p "$APP_BACKUP_DIR"
        rm -rf "$APP_BACKUP_DIR/${APP_NAME}"
        cp -R "$APP" "$APP_BACKUP_DIR/${APP_NAME}"
    fi

    if ! install_verified "$TMP_APP" "$APP"; then
        exit 1
    fi

    # The command-line tools are small, stateless and re-downloadable, so just
    # overwrite them (no backup/rollback): the app rollback is what matters.
    for b in $BIN_NAMES; do
        if ! install_verified "$TMP_BIN_DIR/$b" "$APP_DIR/$b"; then
            exit 1
        fi
        chmod +x "$APP_DIR/$b"
    done
fi

# Cleanup
rm -rf "$TMP_DIR"
trap - EXIT

# Final integrity gate: re-read the installed binaries and confirm they match
# the (PGP-verified) hashes just recorded. Catches corruption that happens after
# the verified copy. Only when checksums were updated (i.e. PGP verified); with
# PORTANODE_ALLOW_UNVERIFIED set, install_verified already checked the copy.
if [ "$UPDATE_CHECKSUMS" -eq 1 ]; then
    echo "Verifying installed binaries against checksums.sha256..."
    vfail=0
    verify_checksum_entry \
      "$APP_DIR/${APP_NAME}/Contents/MacOS/Bitcoin-Qt" \
      "macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" \
      "$ROOTDIR/macos/checksums.sha256" "Bitcoin-Qt" || vfail=1
    for b in $BIN_NAMES; do
        verify_checksum_entry "$APP_DIR/$b" "macos/bin/$b" \
          "$ROOTDIR/macos/checksums.sha256" "$b" || vfail=1
    done
    if [ "$vfail" -ne 0 ]; then
        echo "Error: post-install verification failed (filesystem corruption?)."
        exit 1
    fi
    echo "All Bitcoin binaries verified."
fi

echo "Bitcoin Core updated to $VERSION (Bitcoin-Qt.app + CLI tools)"
