#!/bin/bash
# Update Electrum (Linux)
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

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "Unsupported OS (Linux only)."
    exit 1
fi

BIN_DIR="$ROOTDIR/linux/bin"
BACKUP_DIR="$BIN_DIR/backup/electrum"
CHECKSUM_FILE="$ROOTDIR/linux/checksums.sha256"

# electrum.org publishes one Linux artifact, electrum-<version>-x86_64.AppImage
# -- no architecture branch the way update-bitcoin.sh (Linux) has one for
# uname -m, electrum.org shipping x86_64 only.

# THE FUSE2 QUESTION (ISS 118 / ISS 110's umbrella deferred it here):
#
# An AppImage's own runtime has to mount its embedded squashfs image before
# it can run, and the historical AppImageKit runtime does that by dlopen()ing
# libfuse.so.2 -- the package Ubuntu leaves uninstalled by default. That is
# the premise this issue was filed on, and it is why the two shapes below
# were both live options.
#
# It does not hold for the artifact electrum.org actually ships today.
# Measured against electrum-4.8.1-x86_64.AppImage on a GitHub Actions
# ubuntu-latest runner (Ubuntu 24.04, no libfuse2t64 installed, only
# fuse3/libfuse3 present): `./electrum.AppImage --version` ran immediately,
# `ldd` reports "not a dynamic executable", and `strings` shows the binary
# statically links squashfuse ("squashfuse 0.5.2", "fsname=squashfuse")
# rather than the system's libfuse. Starting the bundled daemon and reading
# `mount` while it ran confirmed a real mount:
# ".../electrum.AppImage on /tmp/.mount_electrXXXXXX type fuse.electrum.AppImage",
# using only the kernel's /dev/fuse -- present on any ordinary Linux, not a
# package to install. Installing libfuse2t64 afterward and re-running
# produced the identical exit code and output: it made no difference,
# because nothing in this binary asked for it. So "run the AppImage as
# shipped" carries no runtime dependency to document on the platform this
# updater targets, and the installed artifact is the byte-identical signed
# file whose checksum below was recorded.
#
# The rejected shape -- --appimage-extract, install the resulting directory,
# and run its contents -- was measured too, and costs more than it buys
# here. Two independent, unexecuted extractions of the same AppImage hash
# identically with tree_hash. The first real execution of the extracted
# tree does not: Python writes usr/lib/python3.12/**/__pycache__/*.pyc into
# it as a side effect of merely importing its own standard library, which
# tree_hash (unlike its existing ._* AppleDouble exclusion) has no reason to
# ignore. So a checksum recorded right after a verified extraction would
# already be wrong the first time anything runs the installed Electrum,
# which is not a corner case for an install this tree's own launcher is
# meant to start -- it is the ordinary path. Avoiding that would need
# PYTHONDONTWRITEBYTECODE=1 threaded through every future launcher and
# verify-binaries call, or tree_hash taught to also skip __pycache__,
# either way for the sole benefit of working around a FUSE dependency this
# measurement shows the shipped binary does not have.
#
# If a future Electrum release goes back to a dynamically-linked runtime, or
# a machine genuinely lacks /dev/fuse, this script fails the way any command
# does when its interpreter cannot run it -- install_verified below still
# protects the copy, and the message printed is gpg's or the shell's own,
# not a diagnosis this script invents. That is judged an acceptable trade
# against building and maintaining the extraction path for a dependency
# nothing here has ever observed.

if [ -n "$VERSION_OVERRIDE" ]; then
    VERSION="$VERSION_OVERRIDE"
    echo "Requested Electrum version: ${VERSION}"
else
    # --max-time 300: the same bound update-bitcoin.sh puts on its own
    # index fetch (ISS 354), sized against bitcoincore.org answering in
    # 135 s on a repeat request -- download.electrum.org was not measured
    # slow, but the bound is applied here too rather than left unbounded.
    # Version detection is required rather than optional, so the fetch
    # failing -- the bound firing included -- is still fatal. What the
    # "|| {" block buys is not visibility: -fsSL carries -S, so curl
    # prints its own diagnostic and this failure is not silent the way
    # ISS 348's grep -c was. It buys a message naming the publisher and
    # the bound, and a fixed exit 1 in place of curl's own status.
    INDEX_HTML="$(curl -fsSL --max-time 300 -H "User-Agent: PortaNode" \
      https://download.electrum.org/)" || {
        echo "Failed to fetch the release index from download.electrum.org" \
             "(curl --max-time 300)."
        exit 1
    }
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

# Prevent updates while running. The mounted AppImage's own command line is
# the primary signal; the mount point it creates
# (/tmp/.mount_electrXXXXXX, seen when measuring the FUSE question above) is
# not matched here because its random suffix is not a stable pattern, and
# the process holding it is caught by the pattern below regardless. The
# python/run_electrum alternatives catch a source or extracted-tree
# invocation the way update-electrum.sh (macOS)'s own layered pattern does.
# run_electrum is anchored to where a program name can appear -- the start
# of the command line or right after a path separator, ending at a space or
# the line's end -- so a process that merely carries "run_electrum" among
# its own arguments, unrelated to Electrum, is not matched.
ELECTRUM_PGREP_PATTERN="electrum\.AppImage|python.*electrum|(^|/)run_electrum( |\$)"
if pgrep -f -i "$ELECTRUM_PGREP_PATTERN" > /dev/null; then
    echo "Error: Electrum is running. Stop it before updating."
    exit 1
fi

echo "Updating Electrum..."

BASE_URL="https://download.electrum.org/${VERSION}"
FILE="electrum-${VERSION}-x86_64.AppImage"
URL="${BASE_URL}/${FILE}"

if [ "$DRY_RUN" -eq 1 ]; then
    CURRENT="$(installed_version \
      "$BIN_DIR/electrum.AppImage" \
      "linux/bin/electrum.AppImage" \
      "$CHECKSUM_FILE")"
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
             "Content-Length)."
    fi
    df -h "$ROOTDIR" | awk -v r="$ROOTDIR" 'NR==2 {print "Free space at " r ": " $4}'
    exit 0
fi

# Download/verify on the local temp dir, never on the removable volume; only
# the final, verified AppImage is copied onto ROOTDIR (see install_verified).
# Created here, after the --dry-run exit above, so a dry run never leaves an
# empty directory behind.
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/portanode-electrum.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading $URL..."
curl -fL -o "$TMP_DIR/$FILE" "$URL"
curl -fL -o "$TMP_DIR/$FILE.asc" "${URL}.asc"

PGP_OK=0
if ! pgp_verify_or_fail \
  "$TMP_DIR/$FILE.asc" \
  "$TMP_DIR/$FILE" \
  "Electrum" \
  PGP_OK \
  "$ROOTDIR/keys/electrum.fingerprints"; then
    exit 1
fi

mkdir -p "$BIN_DIR"
mkdir -p "$BACKUP_DIR"
if [ -f "$BIN_DIR/electrum.AppImage" ]; then
    cp -p "$BIN_DIR/electrum.AppImage" "$BACKUP_DIR/electrum.AppImage"
fi

if ! install_verified "$TMP_DIR/$FILE" "$BIN_DIR/electrum.AppImage"; then
    exit 1
fi
chmod +x "$BIN_DIR/electrum.AppImage"

if [ "$PGP_OK" -eq 1 ]; then
    update_checksum \
      "$BIN_DIR/electrum.AppImage" \
      "linux/bin/electrum.AppImage" \
      "$VERSION" \
      "$CHECKSUM_FILE"
    echo "Verifying installed Electrum against checksums.sha256..."
    if ! verify_checksum_entry \
        "$BIN_DIR/electrum.AppImage" \
        "linux/bin/electrum.AppImage" \
        "$CHECKSUM_FILE" "Electrum"; then
        echo "Error: post-install verification failed (filesystem corruption?)."
        exit 1
    fi
    echo "Electrum verified."
else
    echo "Warning: PGP signature(s) not verified; skipping checksum update."
fi

# Cleanup
rm -rf "$TMP_DIR"
trap - EXIT

echo "Electrum updated to $VERSION"
