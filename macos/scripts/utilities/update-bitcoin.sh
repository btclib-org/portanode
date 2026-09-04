#!/bin/bash
# Update Bitcoin Core binaries
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=macos/scripts/utilities/lib.sh
. "$SCRIPT_DIR/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
cd "$ROOTDIR"

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
else
    echo "Unsupported OS (macOS only)."
    exit 1
fi

# Release archive name for a given version.
release_file() { echo "bitcoin-$1-${ARCH_TAG}-${OS}.${EXT}"; }

if [ -n "$VERSION_OVERRIDE" ]; then
    VERSION="$VERSION_OVERRIDE"
    FILE="$(release_file "$VERSION")"
    echo "Requested Bitcoin Core version: ${VERSION}"
else
    # Pick the newest release on bitcoincore.org that actually ships a macOS
    # archive (mirrors how update-electrum.sh auto-detects the latest
    # Electrum). The index can list version directories that are empty (a
    # release not yet published) or that lack macOS builds, so we probe
    # newest-first and skip any candidate whose archive is missing. Legacy
    # 0.x releases are excluded so the numeric sort picks a modern version.
    echo "Determining latest Bitcoin Core version..."
    # --max-time 300: bitcoincore.org has been measured answering this
    # same index in 135 s on a repeat request (ISS 354), well inside this
    # bound, so a slow publisher still completes; a genuinely stuck
    # connection does not hold the run open indefinitely. Version
    # detection is required rather than optional, so the fetch failing --
    # the bound firing included -- is still fatal. What the "|| {" block
    # below buys is not visibility: -fsSL carries -S, so curl prints its
    # own diagnostic and this failure is not silent the way ISS 348's
    # grep -c was. It buys a message naming the publisher and the bound,
    # and a fixed exit 1 in place of curl's own status. The candidate
    # probe below is where the silence is real: -fsIL carries no -S.
    INDEX_HTML="$(curl -fsSL --max-time 300 -H "User-Agent: PortaNode" \
      https://bitcoincore.org/bin/)" || {
        echo "Failed to fetch the release index from bitcoincore.org" \
             "(curl --max-time 300)."
        exit 1
    }
    CANDIDATES="$(
      echo "$INDEX_HTML" \
        | sed -nE 's/.*href="bitcoin-core-([0-9]+\.[0-9]+(\.[0-9]+)?)\/".*/\1/p' \
        | grep -vE '^0\.' \
        | sort -t. -k1,1nr -k2,2nr -k3,3nr
    )"
    VERSION=""
    for candidate in $CANDIDATES; do
        candidate_url="https://bitcoincore.org/bin/bitcoin-core-${candidate}/$(release_file "$candidate")"
        # --max-time 30: the same archive HEAD ISS 336 already bounds at
        # 30 s further down this script, measured near 0.3 s in the
        # ordinary case (ISS 354). curl's exit code is captured through
        # "|| curl_rc=$?" rather than a bare command, which would end the
        # script under set -e on the very first missing candidate, and
        # rather than reading "$?" after an "if" whose condition it was --
        # bash's own "if" returns 0 when the condition is false and there
        # is no "else", which would have reported every miss as success.
        curl_rc=0
        curl -fsIL --max-time 30 -o /dev/null "$candidate_url" || curl_rc=$?
        if [ "$curl_rc" -eq 0 ]; then
            VERSION="$candidate"
            break
        elif [ "$curl_rc" -eq 28 ]; then
            echo "Skipping ${candidate}: bitcoincore.org did not answer" \
                 "within 30 seconds."
        else
            echo "Skipping ${candidate} (no macOS archive published)."
        fi
    done
    if [ -z "$VERSION" ]; then
        echo "Failed to find a Bitcoin Core release with a macOS archive on" \
             "bitcoincore.org."
        exit 1
    fi
    FILE="$(release_file "$VERSION")"
    echo "Latest Bitcoin Core with a macOS build: ${VERSION}"
fi

# The ".app" zip ships only the GUI; the command-line tools (bitcoind,
# bitcoin-cli, etc.) live in the loose-binary tarball, so fetch that too and
# install them next to the app in macos/bin/ (putting them inside the signed
# .app bundle would invalidate the bundle's code signature).
CLI_ARCHIVE="bitcoin-${VERSION}-${ARCH_TAG}-${OS}.tar.gz"
# bitcoin is the multi-call dispatch binary the loose-binary tarball ships
# alongside the other tools above (confirmed against the published archive
# with tar -tzf); win/scripts/utilities/update-bitcoin.bat already installs
# its Windows counterpart, bitcoin.exe, via its bin\*.exe wildcard copy.
BIN_NAMES="bitcoind bitcoin-cli bitcoin-qt bitcoin-tx bitcoin-util bitcoin-wallet bitcoin"

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
# shellcheck disable=SC2140 # a line continuation building one URL, not
# the "A"B"C" concatenation shellcheck reads it as
CHECKSUM_SIG_URL="https://bitcoincore.org/bin/bitcoin-core-${VERSION}/"\
"SHA256SUMS.asc"

if [ "$DRY_RUN" -eq 1 ]; then
    CURRENT="$(installed_version \
      "$APP_DIR/${APP_NAME}/Contents/MacOS/Bitcoin-Qt" \
      "macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt" \
      "$ROOTDIR/macos/checksums.sha256")"
    echo "--dry-run: nothing will be downloaded, verified or installed."
    echo "Would install Bitcoin Core ${VERSION} (currently installed: ${CURRENT})."
    echo "Would fetch: $URL"
    echo "Would verify against: $CHECKSUM_URL (signed by $CHECKSUM_SIG_URL)"
    if command -v gpg >/dev/null 2>&1; then
        # grep -c exits 1 when it counts zero, which under pipefail makes
        # this assignment's own status 1 -- an empty keyring is exactly
        # the case the warning below exists for, and set -e would end the
        # script here instead of reaching it. The count itself is still
        # correct: grep already printed "0" into the substitution before
        # exiting non-zero, so the fallback only restates it.
        PUBKEYS="$(gpg --list-keys --with-colons 2>/dev/null | grep -c '^pub')" \
          || PUBKEYS=0
        echo "gpg: found, ${PUBKEYS} public key(s) in the local keyring."
        if [ "$PUBKEYS" -eq 0 ]; then
            echo "Warning: with none imported, verification would fail closed" \
                 "unless PORTANODE_ALLOW_UNVERIFIED=1 is set."
        fi
    else
        echo "gpg: not found -- verification would fail closed unless" \
             "PORTANODE_ALLOW_UNVERIFIED=1 is set."
    fi
    # --max-time 30, the bound latest-bitcoin-version.ps1 passes as
    # -TimeoutSec 30 on its own archive HEAD probe: a host that accepts
    # the connection and then answers at its leisure holds --dry-run open
    # for as long as it chooses, where --dry-run is the side-effect-free
    # preview. One flag covers it, --max-time bounding the whole request
    # rather than the connect alone.
    #
    # The status is discarded rather than left to set -e: with pipefail
    # curl's own failure -- the bound firing, or a host refusing the
    # connection -- otherwise ends the run at this assignment, with the
    # free-space line below unreached.
    ARCHIVE_LEN="$(curl -fsIL --max-time 30 "$URL" \
      | tr -d '\r' \
      | awk -F': ' 'tolower($1)=="content-length"{v=$2} END{print v}')" \
      || ARCHIVE_LEN=""
    if [ -n "$ARCHIVE_LEN" ]; then
        echo "Archive size: $((ARCHIVE_LEN / 1024 / 1024)) MB" \
             "(downloaded to local temp storage, not the removable disk)."
    else
        # Printed rather than the block falling silent: with no line at
        # all, an estimate that could not be made reads the same as one
        # nobody attempted. It names the absence rather than a cause: the
        # bound firing, a request that failed and a response carrying no
        # Content-Length all reach here alike.
        #
        # The candidate probe that picks the version does name the bound
        # in its own message, printing only where curl exits 28 -- the
        # status curl returns when the time-out period is reached.
        echo "Archive size: unknown (the HEAD request returned no" \
             "Content-Length)."
    fi
    df -h "$ROOTDIR" | awk -v r="$ROOTDIR" 'NR==2 {print "Free space at " r ": " $4}'
    exit 0
fi

# Download/verify/extract on the local (APFS) temp dir, never on the
# removable exFAT volume: macOS's fskit exFAT driver can silently corrupt
# files written during extraction. Only the final, verified binaries are
# copied onto exFAT (see install_verified). Created here, after the
# --dry-run exit above, so a dry run never leaves an empty directory behind.
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/portanode-bitcoin.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

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
if ! verify_sha256sums "$TMP_DIR" SHA256SUMS "$FILE" "$CLI_ARCHIVE"; then
    echo "Checksum failed"
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
# shellcheck disable=SC2086 # unquoted on purpose: word-splits TAR_MEMBERS
# into the several member names tar is meant to receive
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
        rm -rf "${APP_BACKUP_DIR:?}/${APP_NAME:?}"
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
