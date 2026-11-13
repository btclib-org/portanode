# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# shellcheck disable=SC2329 # check calls these functions by name
# What the macOS and Linux set-permissions report, and the status each exits
# with, by the filesystem, the mode read back and chmod's status. Each runs
# from the checkout against a folder of its own named by PORTANODE_ROOT,
# with a PATH of links to /bin and /usr/bin in which chmod, stat, df,
# findmnt, getfacl, diskutil and ls are stand-ins answering as a case's
# variables say. One case runs the real chmod.

case "$0" in */*) ;; *) [ -f "$0" ] || {
    echo "$0: run this script by its path, not by a name found through PATH" >&2
    exit 1
} ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'chmod -R u+rwx "$TMP" 2> /dev/null; rm -rf "$TMP"' EXIT

ROOT="$TMP/root"
CALLS="$TMP/calls"
BASE="$TMP/base"
STANDINS="$TMP/stand-ins"
mkdir -p "$BASE"
ln -sf /bin/* /usr/bin/* "$BASE/"
rm -f "$BASE/chmod" "$BASE/stat" "$BASE/df" "$BASE/findmnt" \
    "$BASE/getfacl" "$BASE/diskutil" "$BASE/ls"

# stand_in <dir> <name> <body>: writes an executable sh script.
stand_in() {
    mkdir -p "$1"
    printf '#!/bin/sh\n%s\n' "$3" > "$1/$2"
    chmod +x "$1/$2"
}

# Each stand-in answers only the calls the set-permissions of PLATFORM makes,
# and records any other in UNEXPECTED and exits 2, so that a call the other
# platform's tool would take, or that neither would, does not pass where the
# script discards the tool's stderr. set_permissions prints what was
# recorded.
# shellcheck disable=SC2016 # the stand-ins expand it
REFUSE='echo "$(basename "$0") $*" >> "$UNEXPECTED"
exit 2'

# chmod records its arguments on a line and exits CHMOD_RC, or runs the
# machine's chmod where CHMOD_RC is "real". chmod -N, macOS's alone, exits
# CHMOD_N_RC.
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$STANDINS" chmod 'case "$PLATFORM:$*" in
    "linux:-R u=rwX,go= $PORTANODE_ROOT/"* | "macos:-R -H u=rwX,go= $PORTANODE_ROOT/"*) ;;
    *":700 $PORTANODE_ROOT/"*) ;;
    "macos:-N $PORTANODE_ROOT/"*)
        echo "chmod $*" >> "$CALLS"
        exit "$CHMOD_N_RC"
        ;;
    *) '"$REFUSE"' ;;
esac
echo "chmod $*" >> "$CALLS"
[ "$CHMOD_RC" != real ] || exec /bin/chmod "$@"
exit "$CHMOD_RC"'
# stat prints MODE for the mode, as GNU's "-L -c %a" and BSD's "-L -f %OLp"
# ask, and STAT_FSTYPE for the filesystem, as GNU's "-f -c %T" asks, failing
# where that is empty.
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$STANDINS" stat '[ "$#" -eq 4 ] || { '"$REFUSE"'; }
case "$PLATFORM $1 $2 $3" in
    "linux -L -c %a" | "macos -L -f %OLp") echo "$MODE" ;;
    "linux -f -c %T") [ -n "$STAT_FSTYPE" ] || exit 1; echo "$STAT_FSTYPE" ;;
    *) '"$REFUSE"' ;;
esac'
# findmnt, util-linux's, prints OPTIONS, or the filesystem: FSTYPE_ELECTRUM
# for electrum-datadir where that is set, and FSTYPE otherwise.
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$STANDINS" findmnt '[ "$PLATFORM $#:$1 $2 $4" = "linux 5:-n -o --target" ] \
    || { '"$REFUSE"'; }
case "$3 $5" in
    "FSTYPE "*electrum-datadir) echo "${FSTYPE_ELECTRUM:-$FSTYPE}" ;;
    "FSTYPE "*) echo "$FSTYPE" ;;
    "OPTIONS "*) echo "$OPTIONS" ;;
    *) '"$REFUSE"' ;;
esac'
# df -P names the device /dev/disk9s2 for electrum-datadir and /dev/disk9s1
# otherwise.
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$STANDINS" df '[ "$PLATFORM $#:$1" = "macos 2:-P" ] || { '"$REFUSE"'; }
device=/dev/disk9s1
case "$2" in *electrum-datadir) device=/dev/disk9s2 ;; esac
echo "Filesystem 512-blocks Used Available Capacity Mounted on"
echo "$device 100 1 99 1% /Volumes/PortaNode"'
# diskutil info names the personality of /dev/disk9s1 PERSONALITY, and that
# of /dev/disk9s2 PERSONALITY_ELECTRUM where that is set, and nothing where
# the name is empty.
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$STANDINS" diskutil '[ "$PLATFORM $#" = "macos 2" ] || { '"$REFUSE"'; }
case "$1 $2" in
    "info /dev/disk9s1") name="$PERSONALITY" ;;
    "info /dev/disk9s2") name="${PERSONALITY_ELECTRUM:-$PERSONALITY}" ;;
    *) '"$REFUSE"' ;;
esac
[ -z "$name" ] || echo "   File System Personality:  $name"'
# ls -lde prints ACL_LINES lines, as it prints a directory and its ACL
# entries.
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$STANDINS" ls '[ "$PLATFORM $#:$1" = "macos 2:-lde" ] || { '"$REFUSE"'; }
i=0
while [ "$i" -lt "$ACL_LINES" ]; do echo "line $i"; i=$((i + 1)); done'
# getfacl -p prints a default entry where DEFAULT_ACL is set.
GETFACL="$TMP/getfacl"
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$GETFACL" getfacl '[ "$PLATFORM $1" = "linux -p" ] || { '"$REFUSE"'; }
echo "# file: x"
echo "user::rwx"
[ -z "$DEFAULT_ACL" ] || echo "default:user:nobody:r-x"'

# fresh: a folder with both data directories, each holding a file, and every
# variable at the answer of a filesystem storing a mode that chmod sets.
fresh() {
    rm -rf "$ROOT" "$CALLS"
    mkdir -p "$ROOT/linux" "$ROOT/macos" "$ROOT/bitcoin-datadir/wallets" \
        "$ROOT/electrum-datadir"
    touch "$ROOT/VERSION" "$ROOT/bitcoin-datadir/wallets/w.dat" \
        "$ROOT/electrum-datadir/config"
    CHMOD_RC=0
    CHMOD_N_RC=0
    MODE=700
    FSTYPE=ext4
    FSTYPE_ELECTRUM=""
    STAT_FSTYPE=""
    OPTIONS=rw,relatime
    PERSONALITY=APFS
    PERSONALITY_ELECTRUM=""
    ACL_LINES=1
    DEFAULT_ACL=""
    TOOLS="$STANDINS"
}

# set_permissions <platform>: runs that platform's set-permissions, stdout
# and stderr together, then a line for each call a stand-in refused, then
# "exit <status>".
set_permissions() {
    local status=0 call
    rm -f "$TMP/unexpected"
    env PATH="$TOOLS:$BASE" PORTANODE_ROOT="$ROOT" CALLS="$CALLS" \
        PLATFORM="$1" UNEXPECTED="$TMP/unexpected" \
        CHMOD_RC="$CHMOD_RC" CHMOD_N_RC="$CHMOD_N_RC" MODE="$MODE" \
        FSTYPE="$FSTYPE" FSTYPE_ELECTRUM="$FSTYPE_ELECTRUM" \
        STAT_FSTYPE="$STAT_FSTYPE" OPTIONS="$OPTIONS" \
        PERSONALITY="$PERSONALITY" PERSONALITY_ELECTRUM="$PERSONALITY_ELECTRUM" \
        ACL_LINES="$ACL_LINES" \
        DEFAULT_ACL="$DEFAULT_ACL" \
        "$BASH" "$REPO/$1/scripts/utilities/set-permissions.sh" 2>&1 \
        || status=$?
    if [ -f "$TMP/unexpected" ]; then
        while IFS= read -r call; do
            echo "unexpected call: $call"
        done < "$TMP/unexpected"
    fi
    echo "exit $status"
}

# reads <platform> <part>...: what set-permissions prints holds each part,
# and no stand-in refused a call.
reads() {
    local out part
    out="$(set_permissions "$1")"
    shift
    lacks_in "$out" 'unexpected call:' || return 1
    for part; do
        contains "$out" "$part" || return 1
    done
}

# lacks_in <text> <part>: <text> does not hold <part>.
lacks_in() {
    case "$1" in
        *"$2"*)
            printf '  unwanted: %s\n  in:       %s\n' "$2" "$1"
            return 1
            ;;
        *) ;;
    esac
}

# lacks <platform> <part>: what set-permissions prints does not hold <part>,
# and no stand-in refused a call.
lacks() {
    local out
    out="$(set_permissions "$1")"
    lacks_in "$out" "$2" && lacks_in "$out" 'unexpected call:'
}

# --- both -------------------------------------------------------------------

for platform in linux macos; do
    for dir in bitcoin-datadir electrum-datadir; do
        fresh
        rm -r "${ROOT:?}/$dir"
        check "$platform: without $dir it refuses" same \
            'Setting restrictive permissions on data directories...'$'\n'"Error: $dir not found."$'\n''exit 1' \
            "$(set_permissions "$platform")"
    done

    fresh
    MODE=755
    check "$platform: a mode other than 700 read back exits 1" \
        reads "$platform" \
        'bitcoin-datadir is on' 'reads 755 rather than 700 after the chmod above (chmod exit 0).' \
        'exit 1'

    fresh
    MODE=""
    check "$platform: a mode it cannot read back reads unknown and exits 1" \
        reads "$platform" 'reads unknown rather than 700' 'exit 1'

    fresh
    CHMOD_RC=1
    check "$platform: 700 read back after a chmod that failed exits 1" \
        reads "$platform" 'and reads 700, but chmod exited 1: at least one path it was given kept the mode it had.' \
        "find \"$ROOT/electrum-datadir\" -perm" 'exit 1'
done

# --- Linux ------------------------------------------------------------------

fresh
TOOLS="$GETFACL:$STANDINS"
check "linux: ext4 read back at 700 is restricted, and exits 0" same \
    'Setting restrictive permissions on data directories...
bitcoin-datadir is on ext4, which stores a Unix mode, and reads 700: restricted to its owner.
electrum-datadir is on ext4, which stores a Unix mode, and reads 700: restricted to its owner.
exit 0' "$(set_permissions linux)"

fresh
check "linux: without getfacl it says the default ACL was not checked" \
    reads linux 'Note: getfacl is not installed; whether bitcoin-datadir or a directory under it carries a default POSIX ACL' \
    'Note: getfacl is not installed; whether electrum-datadir' 'exit 0'

# A default ACL is reported and leaves the status at 0.
fresh
TOOLS="$GETFACL:$STANDINS"
DEFAULT_ACL=1
check "linux: a default ACL is reported, and the status stays 0" \
    reads linux 'Warning: bitcoin-datadir or a directory under it carries a default POSIX ACL' \
    "setfacl -k -R \"$ROOT/bitcoin-datadir\" clears every one under bitcoin-datadir" \
    'exit 0'

# The chmods restrict the tree: a directory 700 and a file 600.
real_chmod() {
    fresh
    CHMOD_RC=real
    chmod 755 "$ROOT/bitcoin-datadir/wallets"
    chmod 644 "$ROOT/bitcoin-datadir/wallets/w.dat"
    contains "$(set_permissions linux)" 'exit 0' \
        && same drwx------ \
            "$(command ls -ld "$ROOT/bitcoin-datadir/wallets" | cut -c 1-10)" \
        && same -rw------- \
            "$(command ls -l "$ROOT/bitcoin-datadir/wallets/w.dat" | cut -c 1-10)" \
        && same drwx------ \
            "$(command ls -ld "$ROOT/electrum-datadir" | cut -c 1-10)"
}
check "linux: the real chmod leaves directories at 700 and files at 600" \
    real_chmod

for fs in exfat vfat msdos fat; do
    fresh
    FSTYPE="$fs"
    OPTIONS="rw,uid=1000,fmask=0022,dmask=0022"
    MODE=755
    check "linux: $fs stores no mode, and exits 2 with the mount option to use" \
        reads linux \
        "Warning: bitcoin-datadir is on $fs, which stores no Unix mode. The chmod above changed nothing on disk; bitcoin-datadir reads 755 because the mount says so" \
        'Mount options: rw,uid=1000,fmask=0022,dmask=0022' \
        'uid=<your uid>,fmask=077,dmask=077 makes every file and directory on it owner-only' \
        'Encryption or physical control of the device is what restricts it everywhere.' \
        'exit 2'
done

fresh
FSTYPE=exfat
OPTIONS=""
CHMOD_RC=1
check "linux: exfat refusing chmod says the volume is not mounted for this user" \
    reads linux 'chmod itself was refused (exit 1), the volume not being mounted for this user.' \
    'exit 2'

fresh
FSTYPE=exfat
OPTIONS=""
check "linux: exfat without mount options prints no Mount options line" \
    lacks linux 'Mount options:'

# Without findmnt, stat names the filesystem.
fresh
TOOLS="$TMP/no-findmnt"
mkdir -p "$TOOLS"
cp -P "$STANDINS"/* "$TOOLS/"
rm "$TOOLS/findmnt"
STAT_FSTYPE=msdos
check "linux: without findmnt, stat names the filesystem" \
    reads linux 'bitcoin-datadir is on msdos, which stores no Unix mode.' 'exit 2'

fresh
TOOLS="$TMP/no-findmnt"
check "linux: a filesystem nothing names exits 1" \
    reads linux 'Warning: could not determine the filesystem of bitcoin-datadir; it reads 700 after the chmod above.' \
    'Note: getfacl is not installed' 'exit 1'

# The higher status wins, whichever directory it comes from: one on exfat
# exits 2, and the other read back at 755 exits 1.
fresh
FSTYPE=exfat
FSTYPE_ELECTRUM=ext4
MODE=755
check "linux: bitcoin-datadir on exfat and electrum-datadir at 755 exit 2" \
    reads linux 'electrum-datadir is on ext4' 'exit 2'
fresh
FSTYPE_ELECTRUM=exfat
MODE=755
check "linux: bitcoin-datadir at 755 and electrum-datadir on exfat exit 2" \
    reads linux 'electrum-datadir is on exfat' 'exit 2'

# --- macOS ------------------------------------------------------------------

macos_restricted() {
    fresh
    same 'Setting restrictive permissions on data directories...
bitcoin-datadir is on APFS and reads 700: permissions restricted to the owner.
electrum-datadir is on APFS and reads 700: permissions restricted to the owner.
exit 0' "$(set_permissions macos)" \
        && same "chmod -R -H u=rwX,go= $ROOT/bitcoin-datadir
chmod 700 $ROOT/bitcoin-datadir
chmod -N $ROOT/bitcoin-datadir
chmod -R -H u=rwX,go= $ROOT/electrum-datadir
chmod 700 $ROOT/electrum-datadir
chmod -N $ROOT/electrum-datadir" "$(cat "$CALLS")"
}
check "macos: APFS read back at 700 is restricted, after chmod -R -H, 700 and -N" \
    macos_restricted

# chmod -N failing on a directory without an ACL is not a failure.
fresh
CHMOD_N_RC=1
check "macos: a chmod -N that fails is not reported" \
    lacks macos 'chmod exited'

for personality in ExFAT MS-DOS FAT32; do
    fresh
    PERSONALITY="$personality"
    check "macos: $personality stores no permissions, and exits 2" \
        reads macos \
        "Warning: bitcoin-datadir is on $personality, which does not store POSIX permissions." \
        'Restrict access with encryption or physical control of the device instead.' \
        'exit 2'
done

# The higher status wins, whichever directory it comes from.
fresh
PERSONALITY_ELECTRUM=ExFAT
check "macos: bitcoin-datadir restricted and electrum-datadir on ExFAT exit 2" \
    reads macos 'bitcoin-datadir is on APFS and reads 700' \
    'electrum-datadir is on ExFAT' 'exit 2'
fresh
PERSONALITY=ExFAT
PERSONALITY_ELECTRUM=APFS
check "macos: bitcoin-datadir on ExFAT and electrum-datadir restricted exit 2" \
    reads macos 'electrum-datadir is on APFS and reads 700' 'exit 2'

fresh
PERSONALITY=""
check "macos: a filesystem diskutil does not name exits 1" \
    reads macos 'Warning: could not determine the filesystem of bitcoin-datadir; it reads 700 after the chmod above (chmod exit 0).' \
    'exit 1'

fresh
ACL_LINES=2
check "macos: an ACL entry left on a directory at 700 exits 1" \
    reads macos 'Warning: bitcoin-datadir is on APFS and reads 700, but still carries an ACL entry chmod -N did not clear' \
    "ls -lde \"$ROOT/bitcoin-datadir/\" lists it." 'exit 1'

finish
