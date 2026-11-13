# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# shellcheck disable=SC2329 # check calls these functions by name
# What the macOS and Linux updaters do before they download anything: the
# platform and architecture they refuse, how each finds the latest release
# from its index, and what --dry-run reports where gpg is not installed.
# Each runs from the checkout against a folder of its own named by
# PORTANODE_ROOT, with OSTYPE set to its platform and a PATH of links to /bin
# and /usr/bin without gpg, in which curl, uname, sysctl, pgrep, df and
# hdiutil are stand-ins. Needs no network. updaters.sh and updater-input.sh
# have the downgrade refusal, the fetches and the verification.

case "$0" in */*) ;; *) [ -f "$0" ] || {
    echo "$0: run this script by its path, not by a name found through PATH" >&2
    exit 1
} ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

TMP="$(mktemp -d)" || exit 1
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

ROOT="$TMP/root"
INDEX="$TMP/index.html"
PROBES="$TMP/probes"
BASE="$TMP/base"
STANDINS="$TMP/stand-ins"
mkdir -p "$BASE" "$STANDINS" "$TMP/tmp"
ln -sf /bin/* /usr/bin/* "$BASE/"
rm -f "$BASE/gpg" "$BASE/curl" "$BASE/uname" "$BASE/sysctl" "$BASE/pgrep" \
    "$BASE/df" "$BASE/hdiutil"

# stand_in <name> <body>: writes an executable sh script.
stand_in() {
    printf '#!/bin/sh\n%s\n' "$2" > "$STANDINS/$1"
    chmod +x "$STANDINS/$1"
}

# Each stand-in answers only the calls the updaters make, and otherwise
# records the call in UNEXPECTED and exits 2. update then prints the
# refusal alone, so that no case passes on it, even where the script
# discards the tool's stderr.
#
# curl, called as curl_https calls it with HTTPS alone allowed, prints the
# index for a GET of it, or exits 22 where INDEX_FAILS is
# set. A HEAD request writing to /dev/null is a probe: it exits with the
# status PROBES gives on the first line whose first field the URL holds, and
# 22 where none does. Any other HEAD request prints a header naming
# CONTENT_LENGTH where that is set. Anything else exits 22.
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in curl '[ "$1 $2 $3 $4" = "--proto =https --proto-redir =https" ] \
    || { echo "curl $*" >> "$UNEXPECTED"; exit 2; }
for url; do :; done
case " $* " in
    *" -fsSL "*)
        [ -z "$INDEX_FAILS" ] || exit 22
        cat "$INDEX"
        ;;
    *" -o /dev/null "*)
        while read -r part status; do
            case "$url" in *"$part"*) exit "$status" ;; esac
        done < "$PROBES"
        exit 22
        ;;
    *" -fsIL "*)
        printf "HTTP/2 200\r\n"
        [ -z "$CONTENT_LENGTH" ] || printf "content-length: %s\r\n" "$CONTENT_LENGTH"
        ;;
    *) exit 22 ;;
esac'
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in uname '[ "$*" = -m ] || { echo "uname $*" >> "$UNEXPECTED"; exit 2; }
echo "$ARCH"'
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in sysctl '[ "$*" = "-n hw.optional.arm64" ] \
    || { echo "sysctl $*" >> "$UNEXPECTED"; exit 2; }
echo "$ARM64"'
# pgrep -f -i finds no process, and finds one for the pattern ".", as a pgrep
# that understands its options does (pgrep_outside_own_line, in
# shared/lib.sh).
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in pgrep '[ "$#" -eq 3 ] && [ "$1 $2" = "-f -i" ] \
    || { echo "pgrep $*" >> "$UNEXPECTED"; exit 2; }
[ "$3" = . ] && echo 1 && exit 0
exit 1'
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in df '[ "$*" = "-h $PORTANODE_ROOT" ] \
    || { echo "df $*" >> "$UNEXPECTED"; exit 2; }
echo "Filesystem Size Used Avail Capacity Mounted on"
echo "/dev/disk9 1T 1G 512G 1% /Volumes/PortaNode"'
stand_in hdiutil 'exit 1'

# fresh: an empty folder, an index listing nothing, no probe answering, and
# the stand-ins at the answers of a supported machine.
fresh() {
    rm -rf "$ROOT"
    mkdir -p "$ROOT/linux" "$ROOT/macos"
    touch "$ROOT/VERSION"
    : > "$INDEX"
    : > "$PROBES"
    INDEX_FAILS=""
    CONTENT_LENGTH=52428800
    ARCH=x86_64
    ARM64=1
}

# update <platform> <name> <ostype> [argument...]: runs that platform's
# update-<name>.sh, stdout and stderr together, then "exit <status>",
# or what a stand-in refused alone.
update() {
    local platform="$1" name="$2" ostype="$3" status=0 out
    shift 3
    rm -f "$TMP/unexpected"
    out="$(env PATH="$STANDINS:$BASE" OSTYPE="$ostype" PORTANODE_ROOT="$ROOT" \
        TMPDIR="$TMP/tmp" INDEX="$INDEX" PROBES="$PROBES" \
        INDEX_FAILS="$INDEX_FAILS" CONTENT_LENGTH="$CONTENT_LENGTH" \
        UNEXPECTED="$TMP/unexpected" \
        ARCH="$ARCH" ARM64="$ARM64" \
        "$BASH" "$REPO/$platform/scripts/utilities/update-$name.sh" "$@" 2>&1)" \
        || status=$?
    if [ -f "$TMP/unexpected" ]; then
        echo "a stand-in refused: $(cat "$TMP/unexpected")"
        return
    fi
    printf '%s\nexit %s\n' "$out" "$status"
}

# listing <href>...: an index linking each.
listing() {
    local href
    for href; do
        printf '<a href="%s/">%s/</a>\n' "$href" "$href"
    done > "$INDEX"
}

# --- the platform and the architecture --------------------------------------

while read -r platform name ostype; do
    fresh
    check "$platform update-$name refuses an argument it does not know" same \
        "Usage: update-$name.sh [--version <v>] [--dry-run] [--allow-downgrade]"$'\n''exit 1' \
        "$(update "$platform" "$name" "$ostype" --force)"
done << 'EOF'
linux bitcoin linux-gnu
linux electrum linux-gnu
macos bitcoin darwin24
macos electrum darwin24
EOF

for name in bitcoin electrum; do
    fresh
    check "linux update-$name refuses outside Linux" same \
        'Unsupported OS (Linux only).'$'\n''exit 1' \
        "$(update linux "$name" darwin24 --version 1.0)"
    fresh
    ARCH=riscv64
    check "linux update-$name refuses an architecture it has no build for" \
        contains "$(update linux "$name" linux-gnu --version 1.0)" \
        'Unsupported architecture: riscv64'
done

fresh
check "macos update-bitcoin refuses outside macOS" same \
    'Unsupported OS (macOS only).'$'\n''exit 1' \
    "$(update macos bitcoin linux-gnu --version 1.0)"
fresh
check "macos update-electrum refuses outside macOS" same \
    'Updating Electrum...'$'\n''Unsupported OS (macOS only).'$'\n''exit 1' \
    "$(update macos electrum linux-gnu --version 1.0)"
fresh
ARM64=0
check "macos update-bitcoin refuses a Mac without Apple silicon" same \
    "Bitcoin Core's arm64 build needs Apple silicon: nothing was downloaded or replaced."$'\n''exit 1' \
    "$(update macos bitcoin darwin24 --version 1.0)"

fresh
ARCH=aarch64
check "linux update-bitcoin takes aarch64" \
    contains "$(update linux bitcoin linux-gnu --version 29.0 --dry-run)" \
    'Would fetch: https://bitcoincore.org/bin/bitcoin-core-29.0/bitcoin-29.0-aarch64-linux-gnu.tar.gz'

# --- the index --------------------------------------------------------------

while read -r platform name ostype host; do
    fresh
    INDEX_FAILS=1
    check "$platform update-$name says it could not fetch the index" \
        contains "$(update "$platform" "$name" "$ostype" --dry-run)" \
        "Failed to fetch the release index from $host (curl --max-time 300)."$'\n''exit 1'
done << 'EOF'
linux bitcoin linux-gnu bitcoincore.org
linux electrum linux-gnu download.electrum.org
macos bitcoin darwin24 bitcoincore.org
macos electrum darwin24 download.electrum.org
EOF

# The newest release whose archive answers is taken: 0.x is never offered,
# a probe that times out and one finding no archive are skipped.
while read -r platform ostype suffix built; do
    latest() {
        fresh
        listing bitcoin-core-0.99.0 bitcoin-core-27.0 bitcoin-core-28.0 \
            bitcoin-core-28.1 bitcoin-core-27.2 notes
        printf '%s\n' "bitcoin-28.1-$suffix 28" "bitcoin-27.2-$suffix 0" \
            "bitcoin-0.99.0-$suffix 0" > "$PROBES"
        same "Determining latest Bitcoin Core version...
Skipping 28.1: bitcoincore.org did not answer within 30 seconds.
Skipping 28.0 (no $built archive published).
Latest Bitcoin Core with a $built build: 27.2
Updating Bitcoin Core...
--dry-run: nothing will be downloaded, verified or installed.
Would install Bitcoin Core 27.2 (currently installed: unknown).
Would fetch: https://bitcoincore.org/bin/bitcoin-core-27.2/bitcoin-27.2-$suffix
Would verify against: https://bitcoincore.org/bin/bitcoin-core-27.2/SHA256SUMS (signed by https://bitcoincore.org/bin/bitcoin-core-27.2/SHA256SUMS.asc)
gpg: not found -- verification would fail closed.
Archive size: 50 MB (downloaded to local temp storage, not the removable disk).
Free space at $ROOT: 512G
exit 0" "$(update "$platform" bitcoin "$ostype" --dry-run)"
    }
    check "$platform update-bitcoin takes the newest release whose archive answers" \
        latest

    fresh
    listing bitcoin-core-28.0 bitcoin-core-0.21.0
    printf '%s\n' "bitcoin-0.21.0-$suffix 0" > "$PROBES"
    check "$platform update-bitcoin without a release whose archive answers fails" \
        contains "$(update "$platform" bitcoin "$ostype" --dry-run)" \
        "Skipping 28.0 (no $built archive published)."$'\n'"Failed to find a Bitcoin Core release with a"
done << 'EOF'
linux linux-gnu x86_64-linux-gnu.tar.gz x86_64-linux-gnu
macos darwin24 arm64-apple-darwin.zip macOS
EOF

for platform in linux macos; do
    ostype=linux-gnu
    [ "$platform" = linux ] || ostype=darwin24

    fresh
    listing 4.5.8 4.10.0 4.9.12 index 5.0
    check "$platform update-electrum takes the highest version, by number" \
        contains "$(update "$platform" electrum "$ostype" --dry-run)" \
        'Would install Electrum 4.10.0 (currently installed: unknown).'

    fresh
    listing notes 5.0
    check "$platform update-electrum fails where the index lists no version" \
        contains "$(update "$platform" electrum "$ostype" --dry-run)" \
        'Failed to determine latest Electrum version from electrum.org.'$'\n''exit 1'
done

# --- --dry-run ----------------------------------------------------------------

fresh
check "linux update-electrum --dry-run says what it would fetch" same \
    "Requested Electrum version: 4.5.8
Updating Electrum...
--dry-run: nothing will be downloaded, verified or installed.
Would install Electrum 4.5.8 (currently installed: unknown).
Would fetch: https://download.electrum.org/4.5.8/electrum-4.5.8-x86_64.AppImage
gpg: not found -- verification would fail closed.
Archive size: 50 MB (downloaded to local temp storage, not the removable disk).
Free space at $ROOT: 512G
exit 0" "$(update linux electrum linux-gnu --version 4.5.8 --dry-run)"

fresh
check "macos update-electrum --dry-run says what it would fetch" same \
    "Updating Electrum...
Requested Electrum version: 4.5.8
--dry-run: nothing will be downloaded, verified or installed.
Would install Electrum 4.5.8 (currently installed: unknown).
Would fetch: https://download.electrum.org/4.5.8/electrum-4.5.8.dmg
gpg: not found -- verification would fail closed.
Archive size: 50 MB (downloaded to local temp storage, not the removable disk).
Free space at $ROOT: 512G
exit 0" "$(update macos electrum darwin24 --version 4.5.8 --dry-run)"

while read -r platform name ostype; do
    fresh
    CONTENT_LENGTH=""
    check "$platform update-$name --dry-run without a Content-Length reads unknown" \
        contains "$(update "$platform" "$name" "$ostype" --version 29.0 --dry-run)" \
        'Archive size: unknown (the HEAD request returned no Content-Length).'
done << 'EOF'
linux bitcoin linux-gnu
linux electrum linux-gnu
macos bitcoin darwin24
macos electrum darwin24
EOF

finish
