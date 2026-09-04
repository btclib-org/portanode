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

# findmnt is util-linux's and is on any ordinary Linux; GNU stat naming the
# filesystem from its magic number is the fallback where it is not, and it
# answers "exfat" for exFAT and "msdos" for the FAT family (both measured
# on loopback images). Called before restrict() runs, not only from
# report_permission_effect afterwards, because restrict() itself now needs
# the answer.
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

# The chmod's own exit status is kept rather than discarded, because on a
# filesystem that stores no mode it is not the same for everybody: on an
# exFAT mount carrying uid=<the caller>, chmod exits 0 and changes nothing,
# and for anybody else it exits 1 with "Operation not permitted" -- both
# measured on a loopback exFAT image on a GitHub Actions ubuntu-latest
# runner. Neither status says whether the directory ended up restricted,
# which is why the mode is read back below instead.
#
# chmod's own diagnostics are kept on stderr on a filesystem that stores a
# Unix mode, because they name the path that failed and nothing else in
# this script's output does -- a file carrying the immutable attribute
# (chattr +i) refuses chmod and leaves no other trace (btclib-org/portanode#396,
# measured with such a file: the directory still read 700 and the sentence
# printed restricted, with no diagnostic anywhere in the output before
# this stayed on stderr). On a modeless filesystem the same diagnostic is
# pure repetition: every path under the directory fails the same way for
# the same reason, and report_permission_effect's own one-line summary
# already names that reason without walking the tree, so chmod's own
# stderr is discarded there instead -- at the cost of losing the failing
# path's name, which the summary does not carry either (measured on a
# loopback exFAT image mounted for another uid: one "Operation not
# permitted" line per file and directory chmod -R was given, ahead of the
# same clean sentence -- btclib-org/portanode#410). fstype is resolved
# before either chmod runs so this choice can be made before the first one
# is attempted, rather than only afterwards as the mode readback below
# already does.
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
    local dir="$1" fstype="$2"
    local rc=0
    case "$fstype" in
        exfat|vfat|msdos|fat)
            chmod -R u=rwX,go= "$dir" 2>/dev/null || rc=$?
            chmod 700 "$dir" 2>/dev/null || rc=$?
            ;;
        *)
            chmod -R u=rwX,go= "$dir" || rc=$?
            chmod 700 "$dir" || rc=$?
            ;;
    esac
    return "$rc"
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
#
# The "*)" arm below reads no access ACL of its own, unlike
# macos/scripts/utilities/set-permissions.sh's report_permission_effect,
# which reads one back with ls -lde because chmod there never touches an
# ACL at all. acl(5) has chmod's own group-class bits set a POSIX access
# ACL's mask entry where one is present, so chmod 700 reduces the mask to
# no-permissions and takes every named-user and named-group entry's
# effective permissions down with it, whatever those entries still say on
# their own -- measured on a GitHub Actions ubuntu-latest runner (ext4,
# acl package 2.3.2), with a baseline in front so the result can be told
# apart from the mode alone denying access: chmod 700 with no ACL present
# refused another user outright (exit 2); adding a setfacl u:other:rx
# entry to that same directory, with no further chmod, read mode 750
# (POSIX's own group-class display for an ACL's mask) and let that user
# list the directory (exit 0); this script's own chmod calls, run
# afterward against the same entry, read "user:other:r-x #effective:---"
# in getfacl's own output and refused that user again (exit 2 --
# btclib-org/portanode#405). getfacl still lists the access ACL entry,
# so a reader who wants to see it uses that directly; what the mode
# alone already says here is whether it can still be used, which is
# what the restricted sentence is about.
#
# A *default* ACL is untouched by any of this: chmod neither reads nor
# writes one, and every "default:" entry setfacl -d -m added read
# unchanged afterwards, with no "#effective:" reduction on any of them
# -- measured the same way, immediately after the access-ACL run above.
# A default ACL governs what is created under the directory afterwards
# rather than access to the directory itself, so its survival is
# invisible to the restricted sentence: a file the owner created next
# under umask 077 still read 644, "other::r--", because the default
# ACL's own entries set its mode instead of the umask. Whether this
# script should clear, report, or accept a default ACL is open at
# btclib-org/portanode#419.
#
# fstype is passed in rather than resolved again here: restrict() above
# already needed filesystem_type()'s own answer before this ran, and
# calling it a second time on the same directory would only risk
# reading a different answer if the volume were remounted in between --
# unlike mount_options() below, whose own findmnt call reads a
# different field (OPTIONS, not FSTYPE) and is not this repetition.
MODELESS_VOLUME=0
report_permission_effect() {
    local dir="$1" chmod_rc="$2" fstype="$3"
    local rel mode opts
    rel="${dir#"$ROOTDIR/"}"
    mode="$(stat -L -c '%a' "$dir" 2>/dev/null || true)"
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

BITCOIN_FSTYPE="$(filesystem_type "$ROOTDIR/bitcoin-datadir")"
BITCOIN_RC=0
restrict "$ROOTDIR/bitcoin-datadir" "$BITCOIN_FSTYPE" || BITCOIN_RC=$?
ELECTRUM_FSTYPE="$(filesystem_type "$ROOTDIR/electrum-datadir")"
ELECTRUM_RC=0
restrict "$ROOTDIR/electrum-datadir" "$ELECTRUM_FSTYPE" || ELECTRUM_RC=$?

report_permission_effect "$ROOTDIR/bitcoin-datadir" "$BITCOIN_RC" \
    "$BITCOIN_FSTYPE"
report_permission_effect "$ROOTDIR/electrum-datadir" "$ELECTRUM_RC" \
    "$ELECTRUM_FSTYPE"

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
