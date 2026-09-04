#!/bin/bash
# Set secure permissions for PortaNode data directories (Linux)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=linux/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"

echo "Setting restrictive permissions on data directories..."

if [ ! -d "$ROOTDIR/bitcoin-datadir" ]; then
    echo "Error: bitcoin-datadir not found."
    exit 1
fi
if [ ! -d "$ROOTDIR/electrum-datadir" ]; then
    echo "Error: electrum-datadir not found."
    exit 1
fi

# The chmod's own exit status is kept rather than discarded, because on a
# filesystem that stores no mode it is not the same for everybody: on an
# exFAT mount carrying uid=<the caller>, chmod exits 0 and changes nothing,
# and for anybody else it exits 1 with "Operation not permitted" -- both
# measured on a loopback exFAT image on a GitHub Actions ubuntu-latest
# runner. Neither status says whether the directory ended up restricted,
# which is why the mode is read back below instead. chmod's diagnostics
# are left on stderr because they name the path that failed, which the
# messages below do not -- at the cost of one such line per path under
# a large data directory on a mount carrying somebody else's uid, rather
# than the single summary report_permission_effect already prints for
# that case (btclib-org/portanode#410, measured the same way).
#
# GNU chmod -R has no -P/-H/-L distinction: measured on a GitHub Actions
# ubuntu-latest runner (coreutils' chmod), -R on a symlinked directory
# dereferences the command-line argument and recurses into what it
# points at -- a file inside read the recursive call's mode afterwards,
# where BSD chmod's default for -R leaves such a file untouched (see
# macos/scripts/utilities/set-permissions.sh's restrict(), which needs
# -H for the same call to reach it). A symlink met while walking the
# tree, rather than named on the command line, is left alone either way
# -- measured with a second symlink inside the directory pointing
# outside it, whose target's mode did not move.
restrict() {
    local dir="$1"
    local rc=0
    chmod -R u=rwX,go= "$dir" || rc=$?
    chmod 700 "$dir" || rc=$?
    return "$rc"
}

# findmnt is util-linux's and is on any ordinary Linux; GNU stat naming the
# filesystem from its magic number is the fallback where it is not, and it
# answers "exfat" for exFAT and "msdos" for the FAT family (both measured
# on loopback images).
filesystem_type() {
    local dir="$1" fstype=""
    if command -v findmnt >/dev/null 2>&1; then
        fstype="$(findmnt -n -o FSTYPE --target "$dir" 2>/dev/null | tail -1)"
    fi
    if [ -z "$fstype" ]; then
        fstype="$(stat -f -c '%T' "$dir" 2>/dev/null || true)"
    fi
    printf "%s" "$fstype"
}

mount_options() {
    local dir="$1"
    command -v findmnt >/dev/null 2>&1 || return 0
    findmnt -n -o OPTIONS --target "$dir" 2>/dev/null | tail -1
}

# What this utility can and cannot guarantee, measured on a loopback exFAT
# image on a GitHub Actions ubuntu-latest runner (kernel 6.17, exfatprogs
# 1.2.2) rather than derived from the driver's source:
#
#   * exFAT stores no Unix mode. The mode a file or directory reads is
#     computed at each stat from the mount's fmask and dmask, so it is a
#     property of the mount and not of the file.
#   * A mount naming neither reported fmask=0022,dmask=0022 -- "mount -o
#     loop", no mask option, under a umask of 022 -- and every file read
#     rwxr-xr-x and every directory drwxr-xr-x. A directory at 0755 is
#     readable by any user who can also reach the mount point. What a
#     desktop automounter passes was not measured, a loopback image
#     having none, which is why this script reads the mode and the mount
#     options back rather than predicting either.
#   * chmod against such a mount is not an error and not an effect: chmod
#     700 on a directory exited 0 for the volume's owner and the directory
#     went on reading drwxr-xr-x.
#   * Restricting the volume is a mount option: fmask=077,dmask=077 makes
#     every file and directory on it owner-only, and leaves the owner's
#     execute bit, which the launchers and the linux/bin binaries need.
#   * fmask=133 is what takes that execute bit away. A file then reads
#     rw-r--r--, running it directly fails with "Permission denied" and
#     exit 126, and only an explicit interpreter ("bash <file>") still
#     works.
#
# So on exFAT the execute bit survives the masks measured above and a
# mount option defeats it, where macOS synthesises rwx------ whatever
# chmod asked (CLAUDE.md's "The bit decides nothing on the volume this is
# built for"). Neither platform's behaviour follows the volume: the next
# machine mounts it with its own options, which is why the closing line
# below names encryption and physical control rather than a mode.
#
# -L makes the readback follow $dir when it is itself a symlink to the
# data directory. Without it, a Linux symlink -- always reported as
# 777 by stat, its permission bits carrying no meaning -- is what gets
# read and compared against 700, which fails for every symlinked data
# directory whatever the target's real mode is: measured against the
# GNU chmod behaviour recorded in restrict()'s own comment, a symlinked
# bitcoin-datadir that chmod -R had correctly restricted to 700 (600 on
# the file inside it) was reported as reading 777 and not restricted.
MODELESS_VOLUME=0
report_permission_effect() {
    local dir="$1" chmod_rc="$2"
    local rel mode fstype opts
    rel="${dir#"$ROOTDIR/"}"
    mode="$(stat -L -c '%a' "$dir" 2>/dev/null || true)"
    fstype="$(filesystem_type "$dir")"
    opts="$(mount_options "$dir")"

    case "$fstype" in
        exfat|vfat|msdos|fat)
            MODELESS_VOLUME=1
            echo "Warning: $rel is on $fstype, which stores no Unix mode." \
                 "The chmod above changed nothing on disk; $rel reads" \
                 "${mode:-unknown} because the mount says so, and every" \
                 "other directory on the volume reads the same."
            if [ "$chmod_rc" -ne 0 ]; then
                echo "chmod itself was refused (exit $chmod_rc), the volume" \
                     "not being mounted for this user."
            fi
            if [ -n "$opts" ]; then
                echo "Mount options: $opts"
            fi
            ;;
        "")
            echo "Warning: could not determine the filesystem of $rel; it" \
                 "reads ${mode:-unknown} after the chmod above."
            ;;
        *)
            if [ "$mode" != "700" ]; then
                echo "Warning: $rel is on $fstype, which stores a Unix" \
                     "mode, and reads ${mode:-unknown} rather than 700" \
                     "after the chmod above (chmod exit $chmod_rc)."
            elif [ "$chmod_rc" -ne 0 ]; then
                echo "Warning: $rel is on $fstype and reads 700, but" \
                     "chmod exited $chmod_rc: at least one path it was" \
                     "given kept the mode it had. List what under $rel" \
                     "is not owner-only with: find \"$dir\" -perm /077"
            else
                echo "$rel is on $fstype, which stores a Unix mode, and" \
                     "reads 700: restricted to its owner."
            fi
            ;;
    esac
}

BITCOIN_RC=0
restrict "$ROOTDIR/bitcoin-datadir" || BITCOIN_RC=$?
ELECTRUM_RC=0
restrict "$ROOTDIR/electrum-datadir" || ELECTRUM_RC=$?

report_permission_effect "$ROOTDIR/bitcoin-datadir" "$BITCOIN_RC"
report_permission_effect "$ROOTDIR/electrum-datadir" "$ELECTRUM_RC"

# Said once rather than after each directory: it is the volume's property,
# and both data directories are on one volume in the layout this folder is
# used in.
if [ "$MODELESS_VOLUME" -eq 1 ]; then
    echo "Restricting such a volume is a mount option and not a chmod:" \
         "uid=<your uid>,fmask=077,dmask=077 makes every file and directory" \
         "on it owner-only and keeps the execute bit the launchers and the" \
         "linux/bin binaries need. fmask=133 is the setting that takes that" \
         "bit away and stops them starting."
    echo "A mount option restricts this machine only: the next one mounts" \
         "the volume with its own. Encryption or physical control of the" \
         "device is what restricts it everywhere."
fi
