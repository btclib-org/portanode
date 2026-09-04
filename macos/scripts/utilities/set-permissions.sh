#!/bin/bash
# Set secure permissions for PortaNode data directories

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=macos/scripts/lib.sh
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

# The chmod's own exit status is kept rather than discarded, because the
# readback below stats the data directory itself: a chmod that failed on
# a path under it -- a file carrying the uchg flag, say -- leaves that
# directory reading 700, and the read alone cannot tell that case from a
# run where everything was set. chmod's diagnostics are left on stderr
# because they name the path that failed, which the messages below do
# not.
restrict() {
    local dir="$1"
    local rc=0
    chmod -R u=rwX,go= "$dir" || rc=$?
    chmod 700 "$dir" || rc=$?
    return "$rc"
}

# macOS synthesises a fixed mode for exFAT and FAT32 rather than storing
# one it was asked to set: every file and directory on such a volume reads
# u=rwx,go= regardless of what chmod requested, so the calls above ran and
# changed nothing on disk (measured on an exFAT image, see CLAUDE.md's
# "The bit decides nothing on the volume this is built for"). On a volume
# that does store a mode, the filesystem's name says nothing about what
# the chmod did, so the restricted sentence is printed on the mode read
# back off the directory and on the chmod's exit status rather than on
# the personality alone.
#
# The stat here is BSD's: -c is GNU's spelling and this one answers
# "illegal option -- c" and exits 1; %OLp prints the permission bits
# alone in octal, where %Op carries the file type and the high mode bits
# beside them -- a file at 4700 reads 700 under the first and 104700
# under the second -- so the comparison below is against a mode; and -L
# gives the read the same subject as the -d test above and the chmod 700
# in restrict(), both of which follow a symlink where stat does not,
# answering 755 for a link to a 700 directory. The chmod -R beside it
# does not follow one, so where a data directory is a symlink this reads
# the target's 700 while the files under it keep their modes (#394).
#
# That readback needs no control in front of it, unlike a search whose
# informative answer is a miss: stat prints the mode on stdout and prints
# nothing at all when it fails, for a path that is absent and for a path
# under an unsearchable directory alike, so the empty answer is not one
# of the modes it could report.
report_permission_effect() {
    local dir="$1" chmod_rc="$2"
    local rel mode device personality
    rel="${dir#"$ROOTDIR/"}"
    mode="$(stat -L -f '%OLp' "$dir" 2>/dev/null || true)"
    device="$(df -P "$dir" 2>/dev/null | tail -1 | awk '{print $1}')"
    personality="$(diskutil info "$device" 2>/dev/null \
        | awk -F': +' '/File System Personality/ {print $2}')"
    case "$personality" in
        ExFAT|MS-DOS*|FAT32)
            echo "Warning: $rel is on $personality, which does not store" \
                 "POSIX permissions. chmod above changed nothing on" \
                 "disk; the directory is still readable by anyone with" \
                 "access to the volume. Restrict access with encryption or" \
                 "physical control of the device instead."
            ;;
        "")
            echo "Warning: could not determine the filesystem of $rel; it" \
                 "reads ${mode:-unknown} after the chmod above (chmod exit" \
                 "$chmod_rc)."
            ;;
        *)
            if [ "$mode" != "700" ]; then
                echo "Warning: $rel is on $personality, which stores" \
                     "POSIX permissions, and reads ${mode:-unknown}" \
                     "rather than 700 after the chmod above (chmod exit" \
                     "$chmod_rc)."
            elif [ "$chmod_rc" -ne 0 ]; then
                echo "Warning: $rel is on $personality and reads 700, but" \
                     "chmod exited $chmod_rc: at least one path it" \
                     "was given kept the mode it had. List what under $rel" \
                     "is not owner-only with: find \"$dir\" -perm +077"
            else
                echo "$rel is on $personality and reads 700: permissions" \
                     "restricted to the owner."
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
