# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# shellcheck disable=SC2329 # check calls these functions by name
# The disk, Bitcoin Core and Electrum lines of the macOS and Linux
# health-checks, by the way each finds what it reports. Each runs from the
# checkout against a folder of its own named by PORTANODE_ROOT, with a PATH
# of links to /bin and /usr/bin in which df, pgrep, ps, jq and bc are
# stand-ins answering as a case's variables say, so that no process of this
# machine decides a case. health-check.sh has the sync percentages and
# health-check-pgrep.sh what a missing or failing pgrep reads as.

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
trap 'rm -rf "$TMP"' EXIT

ROOT="$TMP/root"
DATADIR="$ROOT/bitcoin-datadir"
BASE="$TMP/base"
STANDINS="$TMP/stand-ins"
mkdir -p "$BASE"
ln -sf /bin/* /usr/bin/* "$BASE/"
rm -f "$BASE/bitcoin-cli" "$BASE/df" "$BASE/pgrep" "$BASE/ps" "$BASE/jq" \
    "$BASE/bc"

# stand_in <dir> <name> <body>: writes an executable sh script.
stand_in() {
    mkdir -p "$1"
    printf '#!/bin/sh\n%s\n' "$3" > "$1/$2"
    chmod +x "$1/$2"
}

# Each stand-in answers only the arguments the health-checks give it, and
# otherwise records the call in UNEXPECTED and exits 2. health_check prints
# what was recorded, which reads refuses, even where the script discards the
# tool's stderr.
#
# df -Pk <root> prints a header and the line DF_LINE.
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$STANDINS" df '[ "$#" -eq 2 ] && [ "$1" = -Pk ] && [ "$2" = "$PORTANODE_ROOT" ] \
    || { echo "df $*" >> "$UNEXPECTED"; exit 2; }
echo "Filesystem 1024-blocks Used Available Capacity Mounted on"
echo "$DF_LINE"'
# pgrep -f -i <pattern> exits PGREP_BITCOIN for a pattern naming bitcoind
# and PGREP_ELECTRUM for one naming Electrum, printing the pid 4242 where
# that is 0, and PGREP_ERROR on stderr. It finds a process for the pattern
# ".", as a pgrep that understands its options does (pgrep_outside_own_line,
# in shared/lib.sh).
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$STANDINS" pgrep '[ "$#" -eq 3 ] && [ "$1 $2" = "-f -i" ] \
    || { echo "pgrep $*" >> "$UNEXPECTED"; exit 2; }
a="$3"
[ -z "$PGREP_ERROR" ] || echo "$PGREP_ERROR" >&2
case "$a" in
    .) echo 1; exit 0 ;;
    *bitcoind*) rc="$PGREP_BITCOIN" ;;
    *) rc="$PGREP_ELECTRUM" ;;
esac
[ "$rc" -ne 0 ] || echo 4242
exit "$rc"'
# ps -A -o pid= -o ppid= prints the table of pids and parents, ps -p <pid>
# -o comm= the name PS_COMM, and ps -ax -o comm= the names PS_NAMES, failing
# there where PS_NAMES is "fail".
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$STANDINS" ps 'case "$*" in
    "-A -o pid= -o ppid=") echo "4242 1" ;;
    "-p "*" -o comm=") echo "$PS_COMM" ;;
    "-ax -o comm=")
        [ "$PS_NAMES" != fail ] || exit 1
        printf "%s\n" "$PS_NAMES"
        ;;
    *)
        echo "ps $*" >> "$UNEXPECTED"
        exit 2
        ;;
esac'
# jq -r .verificationprogress prints SYNC, and bc -l multiplies.
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$STANDINS" jq '[ "$*" = "-r .verificationprogress" ] \
    || { echo "jq $*" >> "$UNEXPECTED"; exit 2; }
cat > /dev/null
printf "%s\n" "$SYNC"'
# shellcheck disable=SC2016 # the stand-ins expand it
stand_in "$STANDINS" bc '[ "$*" = -l ] \
    || { echo "bc $*" >> "$UNEXPECTED"; exit 2; }
LC_ALL=C exec awk "{ printf \"%.4f\\n\", \$1 * \$3 }"'
# without <tool>: prints a PATH directory holding every stand-in but <tool>.
without() {
    local dir="$TMP/no-$1"
    mkdir -p "$dir"
    cp -P "$STANDINS"/* "$dir/"
    rm "$dir/$1"
    printf '%s\n' "$dir"
}

# cli <path>: an executable bitcoin-cli at <path> that, asked for
# getblockchaininfo with the folder's datadir, prints CLI_ANSWER, and, where
# CLI_LATER is set, prints CLI_ANSWER only from its second call on.
# shellcheck disable=SC2016 # the stand-ins expand it
CLI_BODY='[ "$*" = "-datadir=$PORTANODE_ROOT/bitcoin-datadir getblockchaininfo" ] \
    || { echo "bitcoin-cli $*" >> "$UNEXPECTED"; exit 2; }
if [ -n "$CLI_LATER" ] && [ ! -e "$CLI_LATER" ]; then
    : > "$CLI_LATER"
    exit 1
fi
printf "%s\n" "$CLI_ANSWER"'
cli() {
    stand_in "$(dirname "$1")" "$(basename "$1")" "$CLI_BODY"
}

# fresh: an empty folder at ROOT, and every variable at the answer of an
# idle machine with 500 GB free.
fresh() {
    rm -rf "$ROOT" "$TMP/on-path"
    mkdir -p "$ROOT/linux/bin" "$ROOT/macos/bin" "$DATADIR"
    touch "$ROOT/VERSION"
    DF_LINE="/dev/disk9 1000000000 1 524288000 1% /Volumes/PortaNode"
    PGREP_BITCOIN=1
    PGREP_ELECTRUM=1
    PGREP_ERROR=""
    PS_COMM=""
    PS_NAMES="launchd"
    CLI_ANSWER='{}'
    CLI_LATER=""
    SYNC=0.5
    TOOLS="$STANDINS"
}

# health_check <platform>: runs that platform's health-check, stdout and
# stderr together, then a line for each call a stand-in refused.
health_check() {
    local call
    rm -f "$TMP/unexpected"
    env PATH="$TOOLS:$BASE" PORTANODE_ROOT="$ROOT" DF_LINE="$DF_LINE" \
        UNEXPECTED="$TMP/unexpected" \
        PGREP_BITCOIN="$PGREP_BITCOIN" PGREP_ELECTRUM="$PGREP_ELECTRUM" \
        PGREP_ERROR="$PGREP_ERROR" \
        PS_COMM="$PS_COMM" PS_NAMES="$PS_NAMES" CLI_ANSWER="$CLI_ANSWER" \
        CLI_LATER="$CLI_LATER" SYNC="$SYNC" \
        "$BASH" "$REPO/$1/scripts/utilities/health-check.sh" 2>&1
    [ -f "$TMP/unexpected" ] || return 0
    while IFS= read -r call; do
        echo "unexpected arguments: $call"
    done < "$TMP/unexpected"
}

# reads <platform> <line>...: the health-check prints each line whole, and no
# stand-in was given arguments it does not answer.
reads() {
    local out line
    out="$(health_check "$1")"
    shift
    case "$out" in
        *"unexpected arguments"*)
            printf '  a stand-in refused a call in: %s\n' "$out"
            return 1
            ;;
        *) ;;
    esac
    for line; do
        printf '%s\n' "$out" | grep -qxF -- "$line" && continue
        printf '  wanted:   %s\n  in:       %s\n' "$line" "$out"
        return 1
    done
}

# --- the disk line ----------------------------------------------------------

for platform in linux macos; do
    fresh
    check "$platform: the disk line names the free space and the mount" \
        reads "$platform" 'Health Check' \
        'Disk free: 500 GB (/Volumes/PortaNode)'
    fresh
    DF_LINE="/dev/disk9 1000000000 1 1048575"
    check "$platform: a df line without a mount names the free space alone" \
        reads "$platform" 'Disk free: 0 GB'
done

# --- Bitcoin Core -----------------------------------------------------------

for platform in linux macos; do
    fresh
    cli "$ROOT/$platform/bin/bitcoin-cli"
    check "$platform: the folder's bitcoin-cli answering reads as running, by name" \
        reads "$platform" \
        "Bitcoin running: yes (bitcoin-cli: $platform/bin/bitcoin-cli)" \
        'Bitcoin sync: 50.00%'

    fresh
    cli "$TMP/on-path/bitcoin-cli"
    TOOLS="$TMP/on-path:$STANDINS"
    check "$platform: a bitcoin-cli found through PATH reads as running, by its path" \
        reads "$platform" \
        "Bitcoin running: yes (bitcoin-cli: $TMP/on-path/bitcoin-cli)"

    fresh
    cli "$ROOT/$platform/bin/bitcoin-cli"
    TOOLS="$(without jq)"
    check "$platform: without jq the sync reads unknown" \
        reads "$platform" 'Bitcoin sync: unknown'

    fresh
    cli "$ROOT/$platform/bin/bitcoin-cli"
    SYNC=null
    check "$platform: a progress of null reads unknown" \
        reads "$platform" 'Bitcoin sync: unknown'

    # bitcoin-cli does not answer at first, pgrep finds the node, and the
    # second call answers for the sync line.
    fresh
    cli "$ROOT/$platform/bin/bitcoin-cli"
    CLI_LATER="$TMP/cli-called"
    rm -f "$CLI_LATER"
    PGREP_BITCOIN=0
    check "$platform: a node pgrep finds reads as running, and bitcoin-cli asked again gives the sync" \
        reads "$platform" 'Bitcoin running: yes (pgrep)' 'Bitcoin sync: 50.00%'

    fresh
    PGREP_BITCOIN=0
    check "$platform: a node pgrep finds without bitcoin-cli has an unknown sync" \
        reads "$platform" 'Bitcoin running: yes (pgrep)' 'Bitcoin sync: unknown'

    fresh
    check "$platform: nothing found reads as not running" \
        reads "$platform" 'Bitcoin running: no' 'Bitcoin sync: n/a'

    fresh
    : > "$DATADIR/.cookie"
    check "$platform: a .cookie left behind reads as maybe" \
        reads "$platform" 'Bitcoin artifacts: .cookie' \
        'Bitcoin running: maybe' 'Bitcoin sync: unknown'

    fresh
    echo 4242 > "$DATADIR/bitcoind.pid"
    PS_COMM=bitcoind
    check "$platform: a pid file naming a Bitcoin process reads as running" \
        reads "$platform" 'Bitcoin running: yes (pid)' 'Bitcoin sync: unknown'

    fresh
    echo 4242 > "$DATADIR/bitcoind.pid"
    : > "$DATADIR/.cookie"
    PS_COMM=launchd
    check "$platform: a pid file naming another process reads as stale" \
        reads "$platform" 'Bitcoin artifacts: .cookie bitcoind.pid (stale pid)' \
        'Bitcoin running: maybe'

    fresh
    : > "$DATADIR/bitcoind.pid"
    check "$platform: an empty pid file reads as stale" \
        reads "$platform" 'Bitcoin artifacts: bitcoind.pid (stale pid)'

    # A .lock is left by a clean shutdown and says nothing.
    fresh
    : > "$DATADIR/.lock"
    check "$platform: a .lock alone reads as not running" \
        reads "$platform" 'Bitcoin running: no'

    fresh
    PGREP_BITCOIN=3
    check "$platform: a pgrep that fails for Bitcoin Core reads unknown" \
        reads "$platform" 'Bitcoin running: unknown (pgrep or ps failed)' \
        'Bitcoin sync: unknown'

    fresh
    TOOLS="$(without pgrep)"
    check "$platform: without pgrep neither reads as not running" \
        reads "$platform" 'Bitcoin running: unknown (pgrep not found)' \
        'Bitcoin sync: unknown' 'Electrum running: unknown (pgrep not found)'
done

fresh
cli "$ROOT/macos/bin/Bitcoin-Qt.app/Contents/MacOS/bitcoin-cli"
check "macos: the bitcoin-cli inside Bitcoin-Qt.app reads as running, by name" \
    reads macos \
    'Bitcoin running: yes (bitcoin-cli: macos/bin/Bitcoin-Qt.app/Contents/MacOS/bitcoin-cli)'

# The folder's own bitcoin-cli comes before one found through PATH.
fresh
cli "$ROOT/linux/bin/bitcoin-cli"
cli "$TMP/on-path/bitcoin-cli"
TOOLS="$TMP/on-path:$STANDINS"
check "linux: the folder's bitcoin-cli comes before one found through PATH" \
    reads linux 'Bitcoin running: yes (bitcoin-cli: linux/bin/bitcoin-cli)'

# --- Electrum ---------------------------------------------------------------

for platform in linux macos; do
    fresh
    PGREP_ELECTRUM=0
    check "$platform: Electrum pgrep finds reads as running" \
        reads "$platform" 'Electrum running: yes (pgrep)'
    fresh
    check "$platform: Electrum nothing finds reads as not running" \
        reads "$platform" 'Electrum running: no'
    fresh
    PGREP_ELECTRUM=2
    check "$platform: a pgrep that fails for Electrum reads unknown" \
        reads "$platform" 'Electrum running: unknown (pgrep or ps failed)'
done

for name in Electrum run_electrum /Applications/Electrum.app/Contents/MacOS/run_electrum; do
    fresh
    PS_NAMES="launchd"$'\n'"$name"
    check "macos: a process named $name that pgrep misses reads as running" \
        reads macos 'Electrum running: yes (ps)'
done

fresh
PS_NAMES="launchd"$'\n'"electrum-helper"
check "macos: a name that only holds electrum is not Electrum" \
    reads macos 'Electrum running: no'

fresh
PS_NAMES=fail
check "macos: a ps that fails after pgrep finds no Electrum reads unknown" \
    reads macos 'Electrum running: unknown (pgrep or ps failed)'

fresh
TOOLS="$(without ps)"
check "macos: without ps, after pgrep finds no Electrum, it reads unknown" \
    reads macos 'Electrum running: unknown (ps not found)'

# The error the macOS health-check looks for on pgrep's stderr.
fresh
PGREP_BITCOIN=3
PGREP_ERROR="pgrep: Cannot get process list"
check "macos: a pgrep that cannot list processes says it falls back" \
    reads macos 'Note: process listing unavailable; falling back to CLI/artifacts.' \
    'Bitcoin running: unknown (pgrep or ps failed)'

finish
