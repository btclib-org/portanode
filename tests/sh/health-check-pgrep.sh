# shellcheck shell=bash
# shellcheck disable=SC2329 # check calls these functions by name
# What the macOS and Linux health-checks say where pgrep is missing, run in a
# copy of the tree with a PATH of its own. pgrep, ps and bitcoin-cli are
# stand-ins, so that no process of this machine decides a case.

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

ROOT="$TMP/root"
DATADIR="$ROOT/bitcoin-datadir"
mkdir -p "$ROOT/shared" "$DATADIR"
touch "$ROOT/VERSION"
cp "$REPO/shared/lib.sh" "$ROOT/shared/"
for platform in linux macos; do
    mkdir -p "$ROOT/$platform/scripts/utilities"
    cp "$REPO/$platform/scripts/lib.sh" "$ROOT/$platform/scripts/"
    cp "$REPO/$platform/scripts/utilities/health-check.sh" \
        "$ROOT/$platform/scripts/utilities/"
done

# stand_in <dir> <name> <body>: writes an executable sh script.
stand_in() {
    printf '#!/bin/sh\n%s\n' "$3" > "$1/$2"
    chmod +x "$1/$2"
}

NO_PGREP="$TMP/no-pgrep"
mkdir -p "$NO_PGREP"
for tool in awk cat df dirname grep; do
    ln -s "$(command -v "$tool")" "$NO_PGREP/$tool"
done
stand_in "$NO_PGREP" ps 'exit 0'

# with_tools <name> [<tool> <body>]...: prints a PATH directory holding the
# tools above and these stand-ins.
with_tools() {
    local dir="$TMP/$1"
    shift
    mkdir -p "$dir"
    cp -PR "$NO_PGREP"/. "$dir/"
    while [ "$#" -gt 0 ]; do
        stand_in "$dir" "$1" "$2"
        shift 2
    done
    printf '%s\n' "$dir"
}

CLI="$(with_tools cli bitcoin-cli "echo '{}'")"
PS_BITCOIN="$(with_tools ps-bitcoin ps 'echo bitcoind')"
PS_ELECTRUM="$(with_tools ps-electrum \
    ps 'echo /Applications/Electrum.app/Contents/MacOS/run_electrum')"
PGREP_NONE="$(with_tools pgrep-none pgrep 'exit 1')"
PGREP_MATCH="$(with_tools pgrep-match pgrep 'echo 4242')"

# health_check <platform> <path>: runs the health-check.
health_check() {
    env -i PATH="$2" "$BASH" "$ROOT/$1/scripts/utilities/health-check.sh"
}

# prints <platform> <path> <line>...: the health-check prints each line whole.
prints() {
    local out line
    out="$(health_check "$1" "$2" 2>/dev/null)"
    shift 2
    for line in "$@"; do
        printf '%s\n' "$out" | grep -qxF "$line" && continue
        printf '  wanted:   %s\n  in:       %s\n' "$line" "$out"
        return 1
    done
}

# says_nothing <platform> <path>: stderr is empty.
says_nothing() {
    same "" "$(health_check "$1" "$2" 2>&1 >/dev/null)"
}

for platform in linux macos; do
    check "$platform: without pgrep neither process reads as not running" \
        prints "$platform" "$NO_PGREP" \
        "Bitcoin running: unknown (pgrep not found)" \
        "Bitcoin sync: unknown" \
        "Electrum running: unknown (pgrep not found)"
    check "$platform: without pgrep stderr is empty" \
        says_nothing "$platform" "$NO_PGREP"
    check "$platform: without pgrep bitcoin-cli still answers for Bitcoin Core" \
        prints "$platform" "$CLI" \
        "Bitcoin running: yes (bitcoin-cli: $CLI/bitcoin-cli)" \
        "Electrum running: unknown (pgrep not found)"

    # The other passes keep their answers where pgrep is missing.
    : > "$DATADIR/.cookie"
    check "$platform: without pgrep a .cookie still reads as maybe" \
        prints "$platform" "$NO_PGREP" "Bitcoin running: maybe"
    rm -f "$DATADIR/.cookie"
    echo 4242 > "$DATADIR/bitcoind.pid"
    check "$platform: without pgrep a live pid still reads as running" \
        prints "$platform" "$PS_BITCOIN" "Bitcoin running: yes (pid)"
    rm -f "$DATADIR/bitcoind.pid"

    # A pgrep that answers keeps both of its answers.
    check "$platform: a pgrep finding nothing reads as not running" \
        prints "$platform" "$PGREP_NONE" \
        "Bitcoin running: no" \
        "Bitcoin sync: n/a" \
        "Electrum running: no"
    check "$platform: a pgrep finding both reads as running" \
        prints "$platform" "$PGREP_MATCH" \
        "Bitcoin running: yes (pgrep)" \
        "Electrum running: yes (pgrep)"
done

check "macos: without pgrep the ps pass still finds Electrum" \
    prints macos "$PS_ELECTRUM" "Electrum running: yes (ps)"

finish
