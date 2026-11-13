# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# shellcheck disable=SC2329 # check calls these functions by name
# The macOS and Linux rollbacks past their running-node guard: what each
# refuses, what --dry-run reports, and what a rollback moves. Each runs from
# the checkout against a folder of its own named by PORTANODE_ROOT, with OSTYPE
# set to its platform and a PATH of links to /bin and /usr/bin in which pgrep
# is a stand-in finding no process, so that no process of this machine
# decides a case. running-guard.sh has the guard itself.

case "$0" in */*) ;; *) [ -f "$0" ] || {
    echo "$0: run this script by its path, not by a name found through PATH" >&2
    exit 1
} ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"
# shellcheck source=shared/utilities/lib.sh
. "$REPO/shared/utilities/lib.sh"

TMP="$(mktemp -d)" || exit 1
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

ROOT="$TMP/root"
BASE="$TMP/base"
STANDINS="$TMP/stand-ins"
mkdir -p "$BASE" "$STANDINS"
ln -sf /bin/* /usr/bin/* "$BASE/"
rm -f "$BASE/pgrep"

# pgrep -f -i finds no process, and finds one for the pattern ".", as a pgrep
# that understands its options does (pgrep_outside_own_line, in
# shared/lib.sh). Called otherwise, it exits 2, which the rollbacks refuse.
# shellcheck disable=SC2016 # the stand-in expands it
printf '%s\n' '#!/bin/sh' \
    '[ "$#" -eq 3 ] && [ "$1 $2" = "-f -i" ] || exit 2' \
    '[ "$3" = . ] && echo 1 && exit 0' 'exit 1' > "$STANDINS/pgrep"
# mv refuses to move a source matching one of the patterns MV_REFUSES lists,
# separated by spaces, and moves the rest. The rollbacks give it no option.
# shellcheck disable=SC2016 # the stand-in expands it
printf '%s\n' '#!/bin/sh' 'set -f' 'for p in $MV_REFUSES; do' \
    '    case "$1" in $p) echo "mv: refused $1" >&2 && exit 1 ;; esac' \
    'done' 'exec /bin/mv "$@"' > "$STANDINS/mv"
chmod +x "$STANDINS/pgrep" "$STANDINS/mv"

# fresh: an empty folder at ROOT.
fresh() {
    rm -rf "$ROOT"
    mkdir -p "$ROOT/linux/bin" "$ROOT/macos/bin"
    touch "$ROOT/VERSION"
}

# rollback <platform> <name> <ostype> [argument...]: runs that platform's
# rollback-<name>.sh, stdout and stderr together, then "exit <status>".
rollback() {
    local platform="$1" name="$2" ostype="$3" status=0
    shift 3
    env PATH="$STANDINS:$BASE" OSTYPE="$ostype" PORTANODE_ROOT="$ROOT" \
        MV_REFUSES="${MV_REFUSES:-}" "$BASH" \
        "$REPO/$platform/scripts/utilities/rollback-$name.sh" "$@" 2>&1 \
        || status=$?
    echo "exit $status"
}

# record <checksums> <path> <file> [version]: adds the entry for <file>, a
# file or an app bundle, under <path> to the checksum file.
record() {
    local hash
    hash="$(tree_hash "$3")" || return 1
    printf '%s  %s%s\n' "$hash" "$2" "${4:+  version=$4}" >> "$1"
}

# bundle <dir> <executable> <content>: an app bundle holding that executable.
bundle() {
    mkdir -p "$1/Contents/MacOS"
    printf '%s\n' "$3" > "$1/Contents/MacOS/$2"
}

# names <name>: the macOS app, its executable, and the name as messages
# capitalise it.
names() {
    case "$1" in
        bitcoin) echo "Bitcoin-Qt.app Bitcoin-Qt Bitcoin" ;;
        electrum) echo "Electrum.app run_electrum Electrum" ;;
        *) return 1 ;;
    esac
}

# entries <dir>: the names in <dir>, in the C locale's order, on one line.
entries() {
    local LC_ALL=C f out=""
    for f in "$1"/*; do
        [ -e "$f" ] && out="$out${out:+ }${f##*/}"
    done
    printf '%s\n' "$out"
}

# snapshot <dir>: every path under <dir>, the checksum of each file in it,
# and the files its owner can run, so that two snapshots differ where a path,
# a content or that bit moved.
snapshot() {
    (
        cd "$1" || exit 1
        find . -print | LC_ALL=C sort
        find . -type f -exec cksum {} + | LC_ALL=C sort
        find . -type f -perm -u+x -print | LC_ALL=C sort
    )
}

# untouched <dir> <before>: <dir> holds what the snapshot <before> held.
untouched() {
    same "$2" "$(snapshot "$1")"
}

# --- every rollback ---------------------------------------------------------

while read -r platform name ostype; do
    script="$platform/scripts/utilities/rollback-$name.sh"
    fresh
    check "$script refuses an argument it does not know" same \
        "Usage: rollback-$name.sh [--dry-run]"$'\n''exit 1' \
        "$(rollback "$platform" "$name" "$ostype" --force)"
done << 'EOF'
linux bitcoin linux-gnu
linux electrum linux-gnu
macos bitcoin darwin24
macos electrum darwin24
EOF

# --- Linux ------------------------------------------------------------------

LBIN="$ROOT/linux/bin"
LSUMS="$ROOT/linux/checksums.sha256"

for name in bitcoin electrum; do
    script="linux/scripts/utilities/rollback-$name.sh"
    read -r _ _ cap <<< "$(names "$name")"
    fresh
    check "$script refuses outside Linux" same \
        "Unsupported OS (Linux only)."$'\n''exit 1' \
        "$(rollback linux "$name" darwin24)"
    fresh
    check "$script refuses without a backup" same \
        "Rolling back $cap binaries..."$'\n'"No backup found in linux/bin/backup/$name"$'\n'"Debug: linux/bin/backup/$name contents: "$'\n''exit 1' \
        "$(rollback linux "$name" linux-gnu)"
done

# linux_backup <name> <file>...: a backup of those files, each holding its own
# name, and an empty checksum file.
linux_backup() {
    local name="$1" file
    shift
    mkdir -p "$LBIN/backup/$name"
    for file; do
        printf 'old %s\n' "$file" > "$LBIN/backup/$name/$file"
    done
    : > "$LSUMS"
}

fresh
linux_backup bitcoin bitcoind
rm "$LSUMS"
check "linux rollback-bitcoin refuses without linux/checksums.sha256" same \
    'Rolling back Bitcoin binaries...'$'\n''Error: linux/checksums.sha256 not found.'$'\n''exit 1' \
    "$(rollback linux bitcoin linux-gnu)"

fresh
linux_backup electrum electrum.AppImage
rm "$LSUMS"
check "linux rollback-electrum refuses without linux/checksums.sha256" same \
    'Rolling back Electrum binaries...'$'\n''Error: linux/checksums.sha256 not found.'$'\n''exit 1' \
    "$(rollback linux electrum linux-gnu)"

fresh
linux_backup bitcoin
check "linux rollback-bitcoin refuses a backup holding no binary" same \
    'Rolling back Bitcoin binaries...'$'\n''Backup files not found in linux/bin/backup/bitcoin'$'\n''exit 1' \
    "$(rollback linux bitcoin linux-gnu)"

fresh
linux_backup electrum
check "linux rollback-electrum refuses a backup without electrum.AppImage" same \
    'Rolling back Electrum binaries...'$'\n''No backup found in linux/bin/backup/electrum'$'\n''Debug: linux/bin/backup/electrum contents: '$'\n''exit 1' \
    "$(rollback linux electrum linux-gnu)"

# A backup with one binary recorded and one not is refused whole.
unrecognized_bitcoin_left_alone() {
    fresh
    linux_backup bitcoin bitcoind bitcoin-cli
    record "$LSUMS" linux/bin/bitcoind "$LBIN/backup/bitcoin/bitcoind" 27.0
    same 'Rolling back Bitcoin binaries...'$'\n''Error: backup binary checksum not recognized for bitcoin-cli.'$'\n''exit 1' \
        "$(rollback linux bitcoin linux-gnu)" \
        && same 'bitcoin-cli bitcoind' \
            "$(entries "$LBIN/backup/bitcoin")" \
        && same backup "$(entries "$LBIN")"
}
check "linux rollback-bitcoin refuses an unrecognized binary and moves none" \
    unrecognized_bitcoin_left_alone

# An entry for the same content under another path is not this binary's.
fresh
linux_backup electrum electrum.AppImage
record "$LSUMS" linux/bin/electrum.AppImag "$LBIN/backup/electrum/electrum.AppImage" 4.5.8
check "linux rollback-electrum refuses an unrecognized AppImage" same \
    'Rolling back Electrum binaries...'$'\n''Error: backup binary checksum not recognized for electrum.AppImage.'$'\n''exit 1' \
    "$(rollback linux electrum linux-gnu)"

# A dry run names both versions, and leaves linux/bin and the backup in it as
# they were.
bitcoin_dry_run() {
    fresh
    linux_backup bitcoin bitcoind bitcoin-qt
    record "$LSUMS" linux/bin/bitcoind "$LBIN/backup/bitcoin/bitcoind" 27.0
    record "$LSUMS" linux/bin/bitcoin-qt "$LBIN/backup/bitcoin/bitcoin-qt" 27.0
    printf 'new bitcoin-qt\n' > "$LBIN/bitcoin-qt"
    record "$LSUMS" linux/bin/bitcoin-qt "$LBIN/bitcoin-qt" 28.0
    local before
    before="$(snapshot "$LBIN")"
    same 'Rolling back Bitcoin binaries...
--dry-run: nothing will be changed.
Backup found in linux/bin/backup/bitcoin, checksum recognized: version 27.0.
Currently installed: 28.0.
Would replace linux/bin binaries with the backup.
exit 0' "$(rollback linux bitcoin linux-gnu --dry-run)" \
        && untouched "$LBIN" "$before"
}
check "linux rollback-bitcoin --dry-run names both versions and moves nothing" \
    bitcoin_dry_run

# Without bitcoin-qt in the backup or in linux/bin, neither version is known.
unknown_dry_run() {
    fresh
    linux_backup bitcoin bitcoind
    record "$LSUMS" linux/bin/bitcoind "$LBIN/backup/bitcoin/bitcoind" 27.0
    local before
    before="$(snapshot "$LBIN")"
    same 'Rolling back Bitcoin binaries...
--dry-run: nothing will be changed.
Backup found in linux/bin/backup/bitcoin, checksum recognized: version unknown.
Currently installed: unknown.
Would replace linux/bin binaries with the backup.
exit 0' \
        "$(rollback linux bitcoin linux-gnu --dry-run)" \
        && untouched "$LBIN" "$before"
}
check "linux rollback-bitcoin --dry-run without bitcoin-qt reads unknown and moves nothing" \
    unknown_dry_run

electrum_dry_run() {
    fresh
    linux_backup electrum electrum.AppImage
    record "$LSUMS" linux/bin/electrum.AppImage \
        "$LBIN/backup/electrum/electrum.AppImage" 4.5.8
    printf 'new\n' > "$LBIN/electrum.AppImage"
    local before
    before="$(snapshot "$LBIN")"
    same 'Rolling back Electrum binaries...
--dry-run: nothing will be changed.
Backup found in linux/bin/backup/electrum, checksum recognized: version 4.5.8.
Currently installed: unknown.
Would replace linux/bin/electrum.AppImage with the backup.
exit 0' "$(rollback linux electrum linux-gnu --dry-run)" \
        && untouched "$LBIN" "$before"
}
check "linux rollback-electrum --dry-run names both versions and moves nothing" \
    electrum_dry_run

# A rollback moves each binary into linux/bin, executable, and consumes the
# backup.
bitcoin_rolled_back() {
    fresh
    linux_backup bitcoin bitcoind bitcoin-cli
    record "$LSUMS" linux/bin/bitcoind "$LBIN/backup/bitcoin/bitcoind" 27.0
    record "$LSUMS" linux/bin/bitcoin-cli "$LBIN/backup/bitcoin/bitcoin-cli" 27.0
    printf 'new bitcoind\n' > "$LBIN/bitcoind"
    same 'Rolling back Bitcoin binaries...
Rollback complete
The backup in linux/bin/backup/bitcoin is consumed: a second rollback has nothing to restore.
update-bitcoin.sh is what installs the current release again.
exit 0' "$(rollback linux bitcoin linux-gnu)" \
        && same 'old bitcoind' "$(cat "$LBIN/bitcoind")" \
        && same 'old bitcoin-cli' "$(cat "$LBIN/bitcoin-cli")" \
        && [ -x "$LBIN/bitcoind" ] && [ -x "$LBIN/bitcoin-cli" ] \
        && [ ! -e "$LBIN/backup/bitcoin" ]
}
check "linux rollback-bitcoin restores every binary and consumes the backup" \
    bitcoin_rolled_back

electrum_rolled_back() {
    fresh
    linux_backup electrum electrum.AppImage
    record "$LSUMS" linux/bin/electrum.AppImage \
        "$LBIN/backup/electrum/electrum.AppImage" 4.5.8
    same 'Rolling back Electrum binaries...
Rollback complete
The backup in linux/bin/backup/electrum is consumed: a second rollback has nothing to restore.
update-electrum.sh is what installs the current release again.
exit 0' "$(rollback linux electrum linux-gnu)" \
        && same 'old electrum.AppImage' "$(cat "$LBIN/electrum.AppImage")" \
        && [ -x "$LBIN/electrum.AppImage" ] \
        && [ ! -e "$LBIN/backup/electrum" ]
}
check "linux rollback-electrum restores the AppImage and consumes the backup" \
    electrum_rolled_back

# A move that fails stops the rollback, and what it did not move stays in the
# backup. The script walks bitcoind, bitcoin-cli, then bitcoin-qt.
bitcoin_move_fails() {
    fresh
    linux_backup bitcoin bitcoind bitcoin-cli bitcoin-qt
    record "$LSUMS" linux/bin/bitcoin-qt "$LBIN/backup/bitcoin/bitcoin-qt" 27.0
    record "$LSUMS" linux/bin/bitcoind "$LBIN/backup/bitcoin/bitcoind" 27.0
    record "$LSUMS" linux/bin/bitcoin-cli "$LBIN/backup/bitcoin/bitcoin-cli" 27.0
    same 'Rolling back Bitcoin binaries...
mv: refused '"$LBIN"'/backup/bitcoin/bitcoin-cli
Error: restoring linux/bin/bitcoin-cli from the backup failed.
The rollback stopped before restoring every binary. What it did not move is still in linux/bin/backup/bitcoin. Once the cause is cleared, move what is left there into linux/bin by hand, or run update-bitcoin.sh to install the current release over whatever linux/bin now holds.
exit 1' "$(MV_REFUSES='*/bitcoin-cli' rollback linux bitcoin linux-gnu)" \
        && same 'old bitcoind' "$(cat "$LBIN/bitcoind")" \
        && same 'bitcoin-cli bitcoin-qt' "$(entries "$LBIN/backup/bitcoin")"
}
check "linux rollback-bitcoin stops at a move that fails and keeps the rest" \
    bitcoin_move_fails

electrum_move_fails() {
    fresh
    linux_backup electrum electrum.AppImage
    record "$LSUMS" linux/bin/electrum.AppImage \
        "$LBIN/backup/electrum/electrum.AppImage" 4.5.8
    same 'Rolling back Electrum binaries...
mv: refused '"$LBIN"'/backup/electrum/electrum.AppImage
Error: restoring linux/bin/electrum.AppImage from the backup failed.
exit 1' "$(MV_REFUSES='*/backup/*' rollback linux electrum linux-gnu)" \
        && [ -f "$LBIN/backup/electrum/electrum.AppImage" ]
}
check "linux rollback-electrum stops at a move that fails and keeps the backup" \
    electrum_move_fails

# --- macOS ------------------------------------------------------------------

MBIN="$ROOT/macos/bin"
MSUMS="$ROOT/macos/checksums.sha256"

# macos_backup <name> [version]: a backup of that app, recorded under its
# version where one is given, and the same app installed holding "new" and
# recorded as 99.0.
macos_backup() {
    local app exe
    read -r app exe _ <<< "$(names "$1")"
    bundle "$MBIN/backup/$1/$app" "$exe" old
    bundle "$MBIN/$app" "$exe" new
    : > "$MSUMS"
    if [ -n "${2:-}" ]; then
        record "$MSUMS" "macos/bin/$app" "$MBIN/backup/$1/$app"
        record "$MSUMS" "macos/bin/$app/Contents/MacOS/$exe" \
            "$MBIN/backup/$1/$app/Contents/MacOS/$exe" "$2"
    fi
    record "$MSUMS" "macos/bin/$app/Contents/MacOS/$exe" \
        "$MBIN/$app/Contents/MacOS/$exe" 99.0
}

# installed <name>: the content of the installed app's executable.
installed() {
    local app exe
    read -r app exe _ <<< "$(names "$1")"
    cat "$MBIN/$app/Contents/MacOS/$exe" 2> /dev/null
}

for name in bitcoin electrum; do
    script="macos/scripts/utilities/rollback-$name.sh"
    read -r app exe cap <<< "$(names "$name")"
    fresh
    if [ "$name" = bitcoin ]; then
        want="Rolling back Bitcoin binaries..."$'\n'
    else
        want=""
    fi
    check "$script refuses without a backup" same \
        "${want}No backup found in macos/bin/backup/$name"$'\n'"Debug: macos/bin/backup/$name contents: "$'\n''exit 1' \
        "$(rollback macos "$name" darwin24)"

    fresh
    macos_backup "$name" 1.0
    check "$script refuses outside macOS" same \
        "Rolling back $cap binaries..."$'\n''Unsupported OS'$'\n''exit 1' \
        "$(rollback macos "$name" linux-gnu)"

    fresh
    macos_backup "$name" 1.0
    rm "$MSUMS"
    check "$script refuses without macos/checksums.sha256" same \
        "Rolling back $cap binaries..."$'\n''Error: macos/checksums.sha256 not found.'$'\n''Debug: macos contents: bin'$'\n''exit 1' \
        "$(rollback macos "$name" darwin24)"

    unrecognized() {
        fresh
        macos_backup "$name"
        same "Rolling back $cap binaries..."$'\n'"Error: the backup's checksum is not recognized: no macos/bin/$app entry in macos/checksums.sha256 matches it."$'\n''exit 1' \
            "$(rollback macos "$name" darwin24)" \
            && same new "$(installed "$name")" \
            && [ -d "$MBIN/backup/$name/$app" ]
    }
    check "$script refuses an unrecognized backup and moves nothing" \
        unrecognized

    dry_run() {
        fresh
        macos_backup "$name" 1.0
        local before
        before="$(snapshot "$MBIN")"
        same "Rolling back $cap binaries...
--dry-run: nothing will be changed.
Backup found in macos/bin/backup/$name, checksum recognized: version 1.0.
Currently installed: 99.0.
Would replace macos/bin/$app with the backup.
exit 0" "$(rollback macos "$name" darwin24 --dry-run)" \
            && untouched "$MBIN" "$before"
    }
    check "$script --dry-run names both versions and moves nothing" dry_run

    rolled_back() {
        fresh
        macos_backup "$name" 1.0
        local out
        out="$(rollback macos "$name" darwin24)"
        contains "$out" "Rolling back $cap binaries..."$'\n''Rollback complete'$'\n'"The backup in macos/bin/backup/$name is consumed: a second rollback has nothing to restore." \
            && contains "$out" 'exit 0' \
            && same old "$(installed "$name")" \
            && [ ! -e "$MBIN/backup/$name" ] \
            && same "$app backup" "$(entries "$MBIN")"
    }
    check "$script replaces the app, removes the one it replaced and consumes the backup" \
        rolled_back

    without_installed() {
        fresh
        macos_backup "$name" 1.0
        rm -r "${MBIN:?}/$app"
        contains "$(rollback macos "$name" darwin24)" 'exit 0' \
            && same old "$(installed "$name")"
    }
    check "$script restores the app where none is installed" without_installed

    move_back() {
        fresh
        macos_backup "$name" 1.0
        same "Rolling back $cap binaries...
mv: refused $MBIN/backup/$name/$app
Error: restoring macos/bin/$app from the backup failed.
macos/bin/$app is the version that was installed, and the backup is untouched.
exit 1" "$(MV_REFUSES='*/backup/*' rollback macos "$name" darwin24)" \
            && same new "$(installed "$name")" \
            && [ -d "$MBIN/backup/$name/$app" ] \
            && same "$app backup" "$(entries "$MBIN")"
    }
    check "$script puts the installed app back where the backup cannot move" \
        move_back

    by_hand() {
        fresh
        macos_backup "$name" 1.0
        local out
        out="$(MV_REFUSES='*/backup/* *.rollback-*' rollback macos "$name" darwin24)"
        contains "$out" "Error: restoring macos/bin/$app from the backup failed." \
            && contains "$out" "The version that was installed is at macos/bin/$app.rollback-" \
            && contains "$out" ' and has to be moved back by hand.'$'\n''exit 1' \
            && same "$app.rollback-" "$(entries "$MBIN" | grep -o "$app.rollback-")" \
            && [ -d "$MBIN/backup/$name/$app" ]
    }
    check "$script names where the installed app is where it cannot put it back" \
        by_hand
done

# A backup folder without the app is refused by its own message.
fresh
mkdir -p "$MBIN/backup/electrum/other"
check "macos/scripts/utilities/rollback-electrum.sh refuses a backup without Electrum.app" same \
    'Rolling back Electrum binaries...'$'\n''Electrum.app not found in backup'$'\n''Debug: macos/bin/backup/electrum contents: other'$'\n''exit 1' \
    "$(rollback macos electrum darwin24)"

finish
