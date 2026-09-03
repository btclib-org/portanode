#!/bin/bash
# Update Bitcoin Core binaries (Linux)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=linux/scripts/utilities/lib.sh
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

# Detect OS/arch (Linux only). Bitcoin Core's Linux archives are published
# for exactly two architectures (bitcoin-<version>-<arch>-linux-gnu.tar.gz),
# so an unrecognized `uname -m` is refused rather than guessed at the way
# update-bitcoin.sh (macOS) treats any non-arm64 uname as x86_64 -- macOS
# only ever reports one of two values there, where Linux runs on more.
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux-gnu"
    EXT="tar.gz"
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)
            ARCH_TAG="x86_64"
            ;;
        aarch64)
            ARCH_TAG="aarch64"
            ;;
        *)
            echo "Unsupported architecture: $ARCH" \
                 "(bitcoincore.org ships x86_64 and aarch64 for Linux)."
            exit 1
            ;;
    esac
    BIN_DIR="$ROOTDIR/linux/bin"
    BIN_BACKUP_DIR="$BIN_DIR/backup/bitcoin"
else
    echo "Unsupported OS (Linux only)."
    exit 1
fi

# Release archive name for a given version. Matches update-bitcoin.sh
# (macOS)'s own function of this name; ARCH_TAG, OS and EXT are what
# differ between the two, not the naming scheme.
release_file() { echo "bitcoin-$1-${ARCH_TAG}-${OS}.${EXT}"; }

# The Linux tarball ships the daemon, the CLI tools and the Qt GUI
# together under bitcoin-<version>/bin/ -- unlike macOS, which ships the
# GUI as a separately notarized app bundle and fetches a second archive
# for the command-line tools. One archive, one download, one extraction.
BIN_NAMES="bitcoind bitcoin-cli bitcoin-qt bitcoin-tx bitcoin-util bitcoin-wallet bitcoin"

if [ -n "$VERSION_OVERRIDE" ]; then
    VERSION="$VERSION_OVERRIDE"
    FILE="$(release_file "$VERSION")"
    echo "Requested Bitcoin Core version: ${VERSION}"
else
    # Pick the newest release on bitcoincore.org that actually ships a
    # Linux archive for this architecture, the same probing update-bitcoin.sh
    # (macOS) does for its own platform: the index can list version
    # directories that are empty or that lack this architecture's build, so
    # probe newest-first and skip any candidate whose archive is missing.
    # Legacy 0.x releases are excluded so the numeric sort picks a modern
    # version.
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
        echo "Skipping ${candidate} (no ${ARCH_TAG}-${OS} archive published)."
    done
    if [ -z "$VERSION" ]; then
        echo "Failed to find a Bitcoin Core release with a" \
             "${ARCH_TAG}-${OS} archive on bitcoincore.org."
        exit 1
    fi
    FILE="$(release_file "$VERSION")"
    echo "Latest Bitcoin Core with a ${ARCH_TAG}-${OS} build: ${VERSION}"
fi

# Prevent updates while running. pgrep on the runner images this targets is
# GNU procps, whose -f/-i mean the same as the BSD pgrep update-bitcoin.sh
# (macOS) uses; there is no app bundle name to add to the pattern here.
BTC_PGREP_PATTERN="bitcoind|bitcoin-qt|bitcoin qt"
if pgrep -f -i "$BTC_PGREP_PATTERN" > /dev/null; then
    echo "Error: Bitcoin Core is running. Stop it before updating."
    exit 1
fi

echo "Updating Bitcoin Core..."

URL="https://bitcoincore.org/bin/bitcoin-core-${VERSION}/${FILE}"
CHECKSUM_URL="https://bitcoincore.org/bin/bitcoin-core-${VERSION}/SHA256SUMS"
# shellcheck disable=SC2140 # a line continuation building one URL, not the
# "A"B"C" concatenation shellcheck reads it as -- see update-bitcoin.sh
# (macOS), which disables the same false positive for the same reason.
CHECKSUM_SIG_URL="https://bitcoincore.org/bin/bitcoin-core-${VERSION}/"\
"SHA256SUMS.asc"

if [ "$DRY_RUN" -eq 1 ]; then
    CURRENT="$(installed_version \
      "$BIN_DIR/bitcoin-qt" \
      "linux/bin/bitcoin-qt" \
      "$ROOTDIR/linux/checksums.sha256")"
    echo "--dry-run: nothing will be downloaded, verified or installed."
    echo "Would install Bitcoin Core ${VERSION} (currently installed: ${CURRENT})."
    echo "Would fetch: $URL"
    echo "Would verify against: $CHECKSUM_URL (signed by $CHECKSUM_SIG_URL)"
    if command -v gpg >/dev/null 2>&1; then
        PUBKEYS="$(gpg --list-keys --with-colons 2>/dev/null | grep -c '^pub')"
        echo "gpg: found, ${PUBKEYS} public key(s) in the local keyring."
        if [ "$PUBKEYS" -eq 0 ]; then
            echo "Warning: with none imported, verification would fail closed" \
                 "unless PORTANODE_ALLOW_UNVERIFIED=1 is set."
        fi
    else
        echo "gpg: not found -- verification would fail closed unless" \
             "PORTANODE_ALLOW_UNVERIFIED=1 is set."
    fi
    # --max-time 30, the bound latest-bitcoin-version.ps1 and
    # latest-electrum-version.ps1 pass as -TimeoutSec 30: a host that
    # accepts the connection and then answers at its leisure holds
    # --dry-run open for as long as it chooses, where --dry-run is the
    # side-effect-free preview. One flag covers it, --max-time bounding
    # the whole request rather than the connect alone.
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
        echo "Archive size: unknown (the HEAD request returned no" \
             "Content-Length within 30 seconds)."
    fi
    df -h "$ROOTDIR" | awk -v r="$ROOTDIR" 'NR==2 {print "Free space at " r ": " $4}'
    exit 0
fi

# Download/verify/extract on the local temp dir, never on the removable
# volume the ROOTDIR may sit on: writing under exFAT can silently corrupt
# files during extraction (this is exFAT's own fskit driver on macOS; the
# in-tree Linux exfat driver has no such report, but nothing here relies
# on the difference). Only the final, verified binaries are copied onto
# ROOTDIR (see install_verified). Created here, after the --dry-run exit
# above, so a dry run never leaves an empty directory behind.
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/portanode-bitcoin.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading $URL..."
curl -fL -o "$TMP_DIR/$FILE" "$URL"
echo "Downloading $CHECKSUM_URL..."
curl -fL -o "$TMP_DIR/SHA256SUMS" "$CHECKSUM_URL"
echo "Downloading $CHECKSUM_SIG_URL..."
curl -fL -o "$TMP_DIR/SHA256SUMS.asc" "$CHECKSUM_SIG_URL"

# Verify (fails closed; set PORTANODE_ALLOW_UNVERIFIED=1 to bypass). Same
# fingerprints file as the other two platforms: SHA256SUMS is signed by
# many independent builders and keys/bitcoin-core.fingerprints pins none
# by design, so this is no new trust decision.
UPDATE_CHECKSUMS=0
if ! pgp_verify_or_fail \
  "$TMP_DIR/SHA256SUMS.asc" \
  "$TMP_DIR/SHA256SUMS" \
  "SHA256SUMS" \
  UPDATE_CHECKSUMS \
  "$ROOTDIR/keys/bitcoin-core.fingerprints"; then
    exit 1
fi
if ! verify_sha256sums "$TMP_DIR" SHA256SUMS "$FILE"; then
    echo "Checksum failed"
    exit 1
fi

# Extract. bitcoincore.org ships Linux only as tar.gz, so there is no
# archive-format branch here the way update-bitcoin.sh (macOS) has one
# for its zip-vs-tar.gz choice between the app bundle and the CLI tools.
tar -xzf "$TMP_DIR/$FILE" -C "$TMP_DIR"
TMP_BIN_DIR="$TMP_DIR/bitcoin-${VERSION}/bin"
for b in $BIN_NAMES; do
    if [ ! -x "$TMP_BIN_DIR/$b" ]; then
        echo "Error: $b not found in extracted archive."
        debug_list_dir "$TMP_BIN_DIR"
        exit 1
    fi
done

if [ $UPDATE_CHECKSUMS -eq 1 ]; then
    for b in $BIN_NAMES; do
        update_checksum "$TMP_BIN_DIR/$b" "linux/bin/$b" "$VERSION" \
          "$ROOTDIR/linux/checksums.sha256"
    done
else
    echo "Warning: PGP signature(s) not verified; skipping checksum update."
fi

# Replace binaries. Everything below copies from the local temp dir onto
# ROOTDIR via install_verified, which re-reads and retries until the
# on-disk copy matches the source byte-for-byte -- the same defense
# update-bitcoin.sh (macOS) applies, for the same reason: ROOTDIR may sit
# on a removable, potentially exFAT volume.
mkdir -p "$BIN_DIR"
mkdir -p "$BIN_BACKUP_DIR"
for b in $BIN_NAMES; do
    if [ -f "$BIN_DIR/$b" ]; then
        cp -p "$BIN_DIR/$b" "$BIN_BACKUP_DIR/$b"
    fi
done

for b in $BIN_NAMES; do
    if ! install_verified "$TMP_BIN_DIR/$b" "$BIN_DIR/$b"; then
        exit 1
    fi
    chmod +x "$BIN_DIR/$b"
done

# Cleanup
rm -rf "$TMP_DIR"
trap - EXIT

# Final integrity gate: re-read the installed binaries and confirm they
# match the (PGP-verified) hashes just recorded. Catches corruption that
# happens after the verified copy. Only when checksums were updated (i.e.
# PGP verified); with PORTANODE_ALLOW_UNVERIFIED set, install_verified
# already checked the copy.
if [ "$UPDATE_CHECKSUMS" -eq 1 ]; then
    echo "Verifying installed binaries against checksums.sha256..."
    vfail=0
    for b in $BIN_NAMES; do
        verify_checksum_entry "$BIN_DIR/$b" "linux/bin/$b" \
          "$ROOTDIR/linux/checksums.sha256" "$b" || vfail=1
    done
    if [ "$vfail" -ne 0 ]; then
        echo "Error: post-install verification failed (filesystem corruption?)."
        exit 1
    fi
    echo "All Bitcoin binaries verified."
fi

echo "Bitcoin Core updated to $VERSION"
