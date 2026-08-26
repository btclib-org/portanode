#!/bin/bash
# readlink -f: $0 is the symlink's own path where a launcher is
# started through one, which would send both the source below and
# the root walk into the wrong directory.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd -P)"
# shellcheck source=macos/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
echo "ROOTDIR is ${ROOTDIR}"
BIN_DIR="${ROOTDIR}/macos/bin"
ELECTRUM_APP="${BIN_DIR}/Electrum.app"
ELECTRUM_MACOS="${ELECTRUM_APP}/Contents/MacOS"
ELECTRUM_RUN="${ELECTRUM_MACOS}/run_electrum"
ELECTRUM_BIN="${ELECTRUM_MACOS}/Electrum"

if [ ! -d "$BIN_DIR" ]; then
    echo "Error: Binaries directory not found at $BIN_DIR"
    exit 1
fi

if [ ! -x "$ELECTRUM_RUN" ] && [ ! -x "$ELECTRUM_BIN" ]; then
    echo "Error: binary not found in $ELECTRUM_MACOS"
    exit 1
fi

# The daemon's own RPC channel is a unix socket bound inside
# electrum-datadir (daemon_rpc_socket), and every command against a
# wallet kept there goes through it. Measured on macOS against an exFAT
# volume -- ISS 175: the bind answers ENOTSUP, Electrum's daemon then
# fails to start its RPC server with that errno, and the app's own
# window opens anyway, so what the user gets is Electrum's crash
# reporter rather than anything from this launcher -- open(1) below has
# detached the app by then. Bound and released here, before Electrum
# ever runs, this is the same call that fails rather than a guess at the
# filesystem type: a type check would miss a future filesystem with the
# same limitation and misfire on an exFAT mount where the bind happens
# to work.
#
# A bind the kernel refuses is the only outcome that stops the launcher.
# A probe that could not be made prints a note and lets Electrum start,
# because refusing on a datadir nothing measured locks a user out of a
# filesystem that works.
#
# sockaddr_un carries a fixed-width path, and perl truncates a longer
# one to that width and binds at the shortened name rather than failing.
# That leaves a socket at a path the rm below does not name, and the
# next run's bind onto the same shortened name answers EADDRINUSE.
# Packing the address and unpacking it back detects the truncation and
# touches no filesystem doing it; Electrum's own path is checked beside
# the probe's, being the one the answer is about.
#
# unlink before bind: any name already at the probe path answers
# EADDRINUSE, which is a fact about the leftover rather than about the
# filesystem underneath it.
#
# The probe's name is kept shorter than daemon_rpc_socket so the guard
# is never the more fragile of the two. A longer one stops measuring
# across a band of ROOTDIR lengths where Electrum's own socket path
# still fits, and ROOTDIR is wherever the folder is plugged in.
#
# perl where linux/scripts/electrum/'s launchers use python3:
# /usr/bin/python3 on macOS is an xcode_select tool shim -- the same
# inode as /usr/bin/git and /usr/bin/clang -- and xcrun --find python3
# answers /Library/Developer/CommandLineTools/usr/bin/python3, so
# command -v answers for the shim rather than for the interpreter behind
# it. /usr/bin/perl is the interpreter itself.
mkdir -p "${ROOTDIR}/electrum-datadir"
SOCKET_PROBE="${ROOTDIR}/electrum-datadir/.probe.$$"
if command -v perl >/dev/null 2>&1; then
    perl - "${ROOTDIR}/electrum-datadir/daemon_rpc_socket" \
         "$SOCKET_PROBE" <<'PLEOF' 2>/dev/null
use Socket qw(PF_UNIX SOCK_STREAM pack_sockaddr_un unpack_sockaddr_un);
for my $path (@ARGV) {
    exit 2 if unpack_sockaddr_un(pack_sockaddr_un($path)) ne $path;
}
socket(my $sock, PF_UNIX, SOCK_STREAM, 0) or exit 3;
unlink $ARGV[1];
bind($sock, pack_sockaddr_un($ARGV[1])) or exit 1;
PLEOF
    SOCKET_PROBE_STATUS=$?
    rm -f "$SOCKET_PROBE"
    case "$SOCKET_PROBE_STATUS" in
    0) ;;
    1)
        echo "Error: electrum-datadir cannot hold a unix domain" \
             "socket."
        echo "Electrum's daemon binds one there (daemon_rpc_socket) for its" \
             "own RPC channel, and every command against a wallet kept here" \
             "goes through it; this is the filesystem refusing the bind, not" \
             "a missing package or a wrong argument."
        echo "To run Electrum anyway, start it with --dir pointing at a" \
             "directory on a filesystem that supports unix sockets (APFS" \
             "does)."
        exit 1
        ;;
    2)
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
    echo "Note: perl not found; skipping the unix-socket check for" \
         "electrum-datadir. If Electrum's daemon fails to start, this" \
         "directory's filesystem may not support unix domain sockets."
fi

open -n "$ELECTRUM_APP" --args \
  --dir "${ROOTDIR}/electrum-datadir" \
  --oneserver \
  --server localhost:50002:s
