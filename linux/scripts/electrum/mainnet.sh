#!/bin/bash
# Launch Electrum for mainnet.
# Data directory: electrum-datadir
# Network: mainnet
# readlink -f: $0 is the symlink's own path where a launcher is started
# through one, which would send both the source below and the root walk
# into the wrong directory.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd -P)"
# shellcheck source=linux/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
echo "ROOTDIR is ${ROOTDIR}"
BIN_DIR="${ROOTDIR}/linux/bin"
ELECTRUM_APPIMAGE="${BIN_DIR}/electrum.AppImage"

# An array rather than a literal argument list at the foot of the file,
# because the /dev/fuse message below prints the command to run in place
# of this one, and a printed command that has drifted from what the
# script runs is worse than no printed command.
ELECTRUM_ARGS=(
  --dir "${ROOTDIR}/electrum-datadir"
)

if [ ! -d "$BIN_DIR" ]; then
    echo "Error: Binaries directory not found at $BIN_DIR"
    exit 1
fi

if [ ! -e "$ELECTRUM_APPIMAGE" ]; then
    echo "Error: Binary not found at $ELECTRUM_APPIMAGE"
    exit 1
fi

# A volume mounted noexec fails this test with the bit set, the same way
# a cleared bit does, and the kernel refuses the exec in both cases.
if [ ! -x "$ELECTRUM_APPIMAGE" ]; then
    echo "Error: Binary not executable at $ELECTRUM_APPIMAGE"
    exit 1
fi

# The AppImage mounts its own filesystem through the kernel's /dev/fuse
# before any of Electrum runs. Checked here rather than left to the
# AppImage, whose own failure offers --appimage-extract and then links
# AppImageKit's FUSE page, where the remedy is installing libfuse2t64, a
# library this binary does not load. The message below drops that half
# and names --appimage-extract-and-run instead, which needs no privilege
# and was measured to run this AppImage with no /dev/fuse present.
if [ ! -r /dev/fuse ] || [ ! -w /dev/fuse ]; then
    echo "Error: /dev/fuse is not available to this user."
    echo "The Electrum AppImage mounts its own filesystem through that device."
    echo "Loading the kernel's fuse module and granting access to it both need"
    echo "privilege; --appimage-extract-and-run needs none, unpacking the"
    echo "AppImage to a temporary directory and running it from there:"
    # Absolute where every other path in these messages is not: this
    # line is meant to be pasted into a shell rather than read. It is
    # still built from ROOTDIR rather than written down.
    printf '  %q --appimage-extract-and-run' "$ELECTRUM_APPIMAGE"
    printf ' %q' "${ELECTRUM_ARGS[@]}"
    printf '\n'
    exit 1
fi

"$ELECTRUM_APPIMAGE" "${ELECTRUM_ARGS[@]}"
