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
    echo "Error: Binaries directory not found at ${BIN_DIR#"$ROOTDIR"/}"
    exit 1
fi

if [ ! -e "$ELECTRUM_APPIMAGE" ]; then
    echo "Error: Binary not found at ${ELECTRUM_APPIMAGE#"$ROOTDIR"/}"
    exit 1
fi

# A volume mounted noexec fails this test with the bit set, the same way
# a cleared bit does, and the kernel refuses the exec in both cases.
if [ ! -x "$ELECTRUM_APPIMAGE" ]; then
    echo "Error: Binary not executable at ${ELECTRUM_APPIMAGE#"$ROOTDIR"/}"
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
    # Absolute: CLAUDE.md's ROOTDIR convention turns on the use, and
    # this line is printed for use outside this process rather than
    # consumed by it. Rendered relative it would not merely orient a
    # reader worse, it would not run. It is still built from ROOTDIR
    # rather than written down.
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
#
# A bind the kernel refuses is the only outcome that stops the launcher.
# A probe that could not be made prints a note and lets Electrum start,
# because refusing on a datadir nothing measured locks a user out of a
# filesystem that works.
#
# sockaddr_un carries a fixed-width path, and CPython raises rather than
# truncating a longer one. It raises while converting the address, before
# any system call, and that exception carries no errno where a bind the
# kernel refuses carries one -- which separates a path that does not fit
# from a filesystem that will not hold a socket, without asking the
# runtime for the width. The question is put to daemon_rpc_socket's own
# path, that being the one the answer is about, through connect rather
# than bind so that asking it creates nothing there.
#
# unlink before bind: any name already at the probe path answers
# EADDRINUSE, which is a fact about the leftover rather than about the
# filesystem underneath it.
#
# The probe's name is kept shorter than daemon_rpc_socket so the guard is
# never the more fragile of the two. A longer one stops measuring across
# a band of ROOTDIR lengths where Electrum's own socket path still fits,
# and ROOTDIR is wherever the folder is plugged in.
#
# A refused bind exits 4 rather than 1 because an uncaught exception in
# the script below exits 1 as well, and the case below that stops the
# launcher has to be the measured refusal alone.
mkdir -p "${ROOTDIR}/electrum-datadir"
SOCKET_PROBE="${ROOTDIR}/electrum-datadir/.probe.$$"
if command -v python3 >/dev/null 2>&1; then
    python3 - "${ROOTDIR}/electrum-datadir/daemon_rpc_socket" \
             "$SOCKET_PROBE" <<'PYEOF' 2>/dev/null
import os
import socket
import sys

for path in sys.argv[1:]:
    try:
        socket.socket(socket.AF_UNIX, socket.SOCK_STREAM).connect(path)
    except OSError as err:
        if err.errno is None:
            raise SystemExit(2)
try:
    os.unlink(sys.argv[2])
except OSError:
    pass
try:
    socket.socket(socket.AF_UNIX, socket.SOCK_STREAM).bind(sys.argv[2])
except OSError:
    raise SystemExit(4)
PYEOF
    SOCKET_PROBE_STATUS=$?
    rm -f "$SOCKET_PROBE"
    case "$SOCKET_PROBE_STATUS" in
    0) ;;
    4)
        echo "Error: electrum-datadir cannot hold a unix domain" \
             "socket."
        echo "Electrum's daemon binds one there (daemon_rpc_socket) for its" \
             "own RPC channel, and every command against a wallet kept here" \
             "goes through it; this is the filesystem refusing the bind, not" \
             "a missing package or a wrong argument."
        echo "To run Electrum anyway, point --dir at a directory on a" \
             "filesystem that supports unix sockets (ext4 and most others" \
             "do):"
        printf '  %q --dir <path-on-another-filesystem>' "$ELECTRUM_APPIMAGE"
        # The slice drops --dir and the datadir the line has just replaced,
        # leaving the network flag. mainnet.sh has none, and printf with no
        # operand left runs its format once more against an empty string,
        # printing a trailing '' the reader would paste.
        if [ "${#ELECTRUM_ARGS[@]}" -gt 2 ]; then
            printf ' %q' "${ELECTRUM_ARGS[@]:2}"
        fi
        printf '\n'
        exit 1
        ;;
    2)
        # Absolute where the message above names electrum-datadir
        # relative: CLAUDE.md's ROOTDIR convention turns on the use, and
        # this message's subject is the path's own length. The relative
        # form fits any sockaddr_un, so rendering it would report that a
        # path is too long by naming one that is not, and the remedy the
        # sentence gives -- a mount point with a shorter path -- would
        # have nothing left to act on.
        echo "Note: a unix domain socket address cannot hold a path as long" \
             "as ${ROOTDIR}/electrum-datadir/daemon_rpc_socket, so whether" \
             "that filesystem supports one was not tested. Electrum's daemon" \
             "meets the same limit binding that path; a mount point with a" \
             "shorter path is what shortens it."
        ;;
    *)
        echo "Note: the unix-socket check for electrum-datadir did not run." \
             "If Electrum's daemon fails to start, this directory's" \
             "filesystem may not support unix domain sockets."
        ;;
    esac
else
    echo "Note: python3 not found; skipping the unix-socket check for" \
         "electrum-datadir. If Electrum's daemon fails to start, this" \
         "directory's filesystem may not support unix domain sockets."
fi

"$ELECTRUM_APPIMAGE" "${ELECTRUM_ARGS[@]}"
