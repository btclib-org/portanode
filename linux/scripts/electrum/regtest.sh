#!/bin/bash
# Launch Electrum for regtest.
# Data directory: electrum-datadir
# Network: regtest
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
  --regtest
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

# The daemon's own RPC channel is a unix socket bound inside
# electrum-datadir (daemon_rpc_socket); a filesystem that cannot hold one
# lets Electrum start and then die with nothing printed by this launcher
# -- ISS 148, measured on exFAT under both exfat-fuse (bind answers EIO)
# and Ubuntu's own kernel driver (bind answers EPERM instead), the
# datadir left unusable either way. Bound and released here, before
# Electrum ever runs, this is the same call that fails rather than a
# guess at the filesystem type: a type check would miss a future
# filesystem with the same limitation and misfire on an exFAT mount
# where the bind happens to work.
mkdir -p "${ROOTDIR}/electrum-datadir"
SOCKET_PROBE="${ROOTDIR}/electrum-datadir/.portanode-socket-probe.$$"
if command -v python3 >/dev/null 2>&1; then
    if ! python3 - "$SOCKET_PROBE" <<'PYEOF' 2>/dev/null
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.bind(sys.argv[1])
PYEOF
    then
        rm -f "$SOCKET_PROBE"
        echo "Error: ${ROOTDIR}/electrum-datadir cannot hold a unix domain" \
             "socket."
        echo "Electrum's daemon binds one there (daemon_rpc_socket) for its" \
             "own RPC channel, and every wallet command -- getinfo included" \
             "-- goes through it; this is the filesystem refusing the bind," \
             "not a missing package or a wrong argument."
        echo "No wallet can be kept in a datadir on this filesystem. To run" \
             "Electrum anyway, point --dir at a directory on a filesystem" \
             "that supports unix sockets (ext4 and most others do):"
        printf '  %q --dir <path-on-another-filesystem>' "$ELECTRUM_APPIMAGE"
        printf ' %q' "${ELECTRUM_ARGS[@]:2}"
        printf '\n'
        exit 1
    fi
    rm -f "$SOCKET_PROBE"
else
    echo "Note: python3 not found; skipping the unix-socket check for" \
         "electrum-datadir. If Electrum's daemon fails to start, this" \
         "directory's filesystem may not support unix domain sockets."
fi

"$ELECTRUM_APPIMAGE" "${ELECTRUM_ARGS[@]}"
