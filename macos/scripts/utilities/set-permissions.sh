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
#
# -H makes the recursive chmod dereference $dir when it is itself a
# symlink -- BSD chmod's default for -R is -P, which changes the
# symlink's own mode and never reaches what it points at, leaving every
# file under a symlinked data directory at whatever mode it already had
# (measured: a fixture with bitcoin-datadir a symlink to
# bitcoin-datadir-real read the target at 700 and bitcoin.conf inside it
# unchanged at 644, with plain -R). -H dereferences only the argument
# named on the command line; a symlink met while walking the tree is
# left alone, so a file inside the data directory that itself points
# elsewhere is not reached through it (measured against a nested symlink
# pointing outside the tree: its target's mode was untouched). Where
# bitcoin-datadir is a symlink, -H is also what makes the recursive call
# reach past this folder: everything under wherever the link points now
# gets u=rwX,go=, not only what is physically inside the folder.
#
# -N drops the directory's ACL. chmod does not touch one, and macOS
# evaluates an ACL ahead of the POSIX mode, so an inherited or
# hand-added ACE granting another identity access survives every chmod
# call above it: a directory read back at 700 can still be reachable by
# whoever the ACE names (measured: an "everyone allow list,search" ACE
# added before the run was still present after a plain chmod 700).
# -N is idempotent on APFS, exiting 0 whether or not a directory already
# carries an ACL (measured). exFAT and FAT32 carry no ACL concept at
# all, and -N there is refused rather than a no-op -- "Operation not
# supported", exit 1 (measured on a loopback exFAT image) -- which is
# not a failure of anything this script asked for, so its stderr is
# discarded and its exit status left out of rc: the ACL readback below
# is what actually says whether one is present, on every filesystem,
# the same way the mode readback below is trusted over chmod 700's own
# exit status.
restrict() {
    local dir="$1"
    local rc=0
    chmod -R -H u=rwX,go= "$dir" || rc=$?
    chmod 700 "$dir" || rc=$?
    chmod -N "$dir" 2>/dev/null || true
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
# gives the read the same subject as the -d test above and both chmod
# calls in restrict(), all of which follow a symlink where stat does
# not: without -L a symlinked data directory would report the link's
# own mode rather than the target's.
#
# The ACL readback is separate from the mode because macOS keeps the
# two independent: ls -lde prints one line for the directory and, below
# it, one line per ACL entry, so a directory with no ACL prints exactly
# one line and a directory carrying one prints more. It is the only
# signal this script trusts for the ACL: restrict()'s own chmod -N exits
# 1 on exFAT and FAT32, which carry no ACL to clear, so that exit status
# is discarded there rather than read as a failure, and this readback is
# what says whether one is actually still present, on every filesystem.
# A trailing slash on $dir is what makes ls -e follow a symlink here: -d
# alone, with or without -L or -H beside it, still reports the link's
# own (empty) ACL rather than descending through it -- measured against
# a fixture, ls -lde on a symlinked directory read 1 line where ls -lde
# on the same path with a trailing slash, and ls -lde on the real path
# directly, both read 2 -- so this is the same dereferencing the mode
# above needs -L for, in ls's own idiom rather than stat's.
#
# That readback needs no control in front of it, unlike a search whose
# informative answer is a miss: stat prints the mode on stdout and prints
# nothing at all when it fails, for a path that is absent and for a path
# under an unsearchable directory alike, so the empty answer is not one
# of the modes it could report.
#
# What this returns is the status the script exits with, and README.md's
# Permissions bullet states them for every platform: 0 where the
# directory is restricted to its owner, 1 where this run fell short
# of that and acting on what the message names is what would reach it, 2
# where the volume stores no mode and no run of this script restricts
# the directory at all.
#
# The filesystem is read ahead of the mode rather than after it because
# on a volume storing no mode the mode is not evidence: macOS
# synthesises rwx------ there, so the readback answers the same 700 a
# real restriction does -- measured on macos-latest against an exFAT
# disk image, which read 700 after a run that changed nothing on it.
# win/scripts/utilities/set-permissions.bat's own readback does not have
# that problem, icacls answering "No permissions are set. All users have
# full control." on a volume that holds no ACL, so there the readback
# rather than the name is what says whether the restriction is in force.
# What a filesystem missing from the case below costs therefore differs
# by platform: here the mode alone reports it restricted; there the
# readback reports it unrestricted and the run exits 1, the status for a
# run that fell short, against the 2 the named volumes exit with.
report_permission_effect() {
    local dir="$1" chmod_rc="$2"
    local rel mode device personality acl_lines
    rel="${dir#"$ROOTDIR/"}"
    mode="$(stat -L -f '%OLp' "$dir" 2>/dev/null || true)"
    device="$(df -P "$dir" 2>/dev/null | tail -1 | awk '{print $1}')"
    personality="$(diskutil info "$device" 2>/dev/null \
        | awk -F': +' '/File System Personality/ {print $2}')"
    # ls -e is BSD's ACL listing and has no find equivalent; SC2012 reads
    # this as parsing an arbitrary directory listing, but $dir is always
    # one of the two fixed data-directory paths above, never a name built
    # from user input, so the filenames-with-newlines case the check
    # guards against does not apply here.
    # shellcheck disable=SC2012
    acl_lines="$(ls -lde "$dir/" 2>/dev/null | wc -l | tr -d ' ')"
    case "$personality" in
        ExFAT|MS-DOS*|FAT32)
            echo "Warning: $rel is on $personality, which does not store" \
                 "POSIX permissions. chmod above changed nothing on" \
                 "disk; the directory is still readable by anyone with" \
                 "access to the volume. Restrict access with encryption or" \
                 "physical control of the device instead."
            return 2
            ;;
        "")
            echo "Warning: could not determine the filesystem of $rel; it" \
                 "reads ${mode:-unknown} after the chmod above (chmod exit" \
                 "$chmod_rc)."
            return 1
            ;;
        *)
            if [ "$mode" != "700" ]; then
                echo "Warning: $rel is on $personality, which stores" \
                     "POSIX permissions, and reads ${mode:-unknown}" \
                     "rather than 700 after the chmod above (chmod exit" \
                     "$chmod_rc)."
                return 1
            elif [ "$chmod_rc" -ne 0 ]; then
                echo "Warning: $rel is on $personality and reads 700, but" \
                     "chmod exited $chmod_rc: at least one path it was" \
                     "given kept the mode it had. List what under $rel is" \
                     "not owner-only with: find \"$dir\" -perm +077"
                return 1
            elif [ "$acl_lines" -gt 1 ]; then
                echo "Warning: $rel is on $personality and reads 700, but" \
                     "still carries an ACL entry chmod -N did not clear" \
                     "-- ls -lde \"$dir/\" lists it. macOS evaluates an ACL" \
                     "ahead of the mode, so an entry granting another" \
                     "identity access can still reach $rel."
                return 1
            else
                echo "$rel is on $personality and reads 700: permissions" \
                     "restricted to the owner."
                return 0
            fi
            ;;
    esac
}

BITCOIN_RC=0
restrict "$ROOTDIR/bitcoin-datadir" || BITCOIN_RC=$?
ELECTRUM_RC=0
restrict "$ROOTDIR/electrum-datadir" || ELECTRUM_RC=$?

BITCOIN_STATUS=0
report_permission_effect "$ROOTDIR/bitcoin-datadir" "$BITCOIN_RC" \
    || BITCOIN_STATUS=$?
ELECTRUM_STATUS=0
report_permission_effect "$ROOTDIR/electrum-datadir" "$ELECTRUM_RC" \
    || ELECTRUM_STATUS=$?

# The higher of the two is what the script exits with, which orders the
# statuses by how far the answer is out of a caller's reach: a directory
# this run fell short on is reachable by acting on what its own message
# names, and a volume storing no mode is reachable by neither that nor a
# second run. Each directory's own message is printed either way, so
# what the single status drops is which of the two directories it came
# from rather than anything the reader is not told.
STATUS="$BITCOIN_STATUS"
if [ "$ELECTRUM_STATUS" -gt "$STATUS" ]; then
    STATUS="$ELECTRUM_STATUS"
fi
exit "$STATUS"
