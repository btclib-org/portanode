# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# shellcheck disable=SC2329 # check calls these functions by name
# The running-node guard of the macOS and Linux updaters and rollbacks: where
# pgrep is missing or fails, each refuses, and a folder whose path holds the
# pattern does not match itself. tests/win/running-guard.ps1 has the Windows
# half.
#
# Each script runs against an empty folder named by PORTANODE_ROOT, with curl,
# uname and sysctl replaced by stubs, OSTYPE set to its platform, and a PATH
# of symlinks to /bin and /usr/bin without pgrep, to which a case adds the
# pgrep it needs. Needs no network.

case "$0" in */*) ;; *) [ -f "$0" ] || {
    echo "$0: run this script by its path, not by a name found through PATH" >&2
    exit 1
} ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/portanode-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

NO_PGREP="$WORK/no-pgrep"
STUBS="$WORK/stubs"
ROOT="$WORK/root"
mkdir -p "$NO_PGREP" "$STUBS" "$ROOT/linux" "$ROOT/macos"
: > "$ROOT/VERSION"
ln -sf /bin/* /usr/bin/* "$NO_PGREP/"
rm -f "$NO_PGREP/pgrep"

# A HEAD request succeeds and any other fails, so no script downloads anything.
cat > "$STUBS/curl" << 'EOF'
#!/bin/sh
for a in "$@"; do [ "$a" = "-fsIL" ] && exit 0; done
exit 22
EOF
cat > "$STUBS/uname" << 'EOF'
#!/bin/sh
echo "$STUB_ARCH"
EOF
# sysctl answers that the Mac is Apple silicon.
printf '#!/bin/sh\necho 1\n' > "$STUBS/sysctl"
chmod +x "$STUBS/curl" "$STUBS/uname" "$STUBS/sysctl"

# pgrep_answering <status>: prints a directory whose pgrep exits <status>,
# except for the pattern ".", for which it finds a process, as a pgrep that
# understands its options does.
pgrep_answering() {
    mkdir -p "$WORK/pgrep-$1"
    # shellcheck disable=SC2016 # the stand-in expands it
    printf '#!/bin/sh\nfor a; do :; done\n[ "$a" = . ] && echo 1 && exit 0\nexit %s\n' \
        "$1" > "$WORK/pgrep-$1/pgrep"
    chmod +x "$WORK/pgrep-$1/pgrep"
    printf '%s\n' "$WORK/pgrep-$1"
}

# Busybox pgrep has no -i: getopt32 refuses it, prints the usage on stderr
# and exits 1, the status of "no match" (procps/pgrep.c and
# libbb/getopt32.c in busybox; ISS 810). Without -i this one finds a
# process.
BUSYBOX="$WORK/pgrep-busybox"
mkdir -p "$BUSYBOX"
cat > "$BUSYBOX/pgrep" << 'EOF'
#!/bin/sh
for a; do
    case "$a" in
        -i)
            echo "pgrep: invalid option -- 'i'" >&2
            echo "Usage: pgrep [-flanovx] [-s SID|-P PPID|PATTERN]" >&2
            exit 1
            ;;
    esac
done
echo 4242
EOF
chmod +x "$BUSYBOX/pgrep"

# pgrep_listing <name> <command line>...: prints a directory whose pgrep
# reads its last argument as an extended regular expression, ignoring case,
# as pgrep -f -i does, and prints 4242 where one of the command lines
# matches it.
pgrep_listing() {
    local dir="$WORK/pgrep-$1"
    shift
    mkdir -p "$dir"
    printf '%s\n' "$@" > "$dir/table"
    # shellcheck disable=SC2016 # the stand-in expands it
    printf '#!/bin/sh\nfor a; do :; done\ngrep -Eiq -e "$a" "%s" || exit 1\necho 4242\n' \
        "$dir/table" > "$dir/pgrep"
    chmod +x "$dir/pgrep"
    printf '%s\n' "$dir"
}

# run_script <PATH prefix> <ostype> <arch> <script> [argument...]: the script's
# output, then a last line holding its status.
run_script() {
    local prefix="$1" ostype="$2" arch="$3" script="$4"
    shift 4
    env PATH="$STUBS:$prefix$NO_PGREP" PORTANODE_ROOT="$ROOT" OSTYPE="$ostype" \
        STUB_ARCH="$arch" TMPDIR="$WORK" "$BASH" "$REPO/$script" "$@" 2>&1
    echo "status=$?"
}

# refused <text> <name> <doing>: 0 where the script could not tell, said so and
# exited 1.
refused() {
    contains "$1" "Error: cannot tell whether $2 is running" \
        && contains "$1" "Not $3." && contains "$1" "status=1"
}

# stops_for_a_node <text> <name> <doing>
stops_for_a_node() {
    contains "$1" "Error: $2 is running. Stop it before $3." \
        && contains "$1" "status=1"
}

# passes <text> <past>: 0 where the script went past the guard, which <past>,
# printed after it, shows.
passes() {
    contains "$1" "$2" || return 1
    case "$1" in
        *"is running"* | *"cannot tell"*) return 1 ;;
    esac
}

check "the PATH of these cases holds no pgrep" \
    same "" "$(PATH="$NO_PGREP" command -v pgrep)"

while read -r script ostype arch name doing past; do
    [ -n "$script" ] || continue
    name="${name//_/ }"
    doing="${doing//_/ }"
    past="${past//_/ }"
    args=(--dry-run)
    case "$script" in */update-*) args+=(--version 99.0) ;; esac

    out="$(run_script "" "$ostype" "$arch" "$script" "${args[@]}")"
    check "$script refuses without pgrep" refused "$out" "$name" "$doing"
    for status in 2 3 127; do
        out="$(run_script "$(pgrep_answering "$status"):" "$ostype" "$arch" \
            "$script" "${args[@]}")"
        check "$script refuses where pgrep exits $status" \
            refused "$out" "$name" "$doing"
    done
    out="$(run_script "$(pgrep_answering 0):" "$ostype" "$arch" "$script" "${args[@]}")"
    check "$script stops where pgrep finds a process" \
        stops_for_a_node "$out" "$name" "$doing"
    out="$(run_script "$(pgrep_answering 1):" "$ostype" "$arch" "$script" "${args[@]}")"
    check "$script goes on where pgrep finds no process" passes "$out" "$past"
    out="$(run_script "$BUSYBOX:" "$ostype" "$arch" "$script" "${args[@]}")"
    check "$script refuses where pgrep refuses -i, as busybox pgrep does" \
        refused "$out" "$name" "$doing"
done << 'EOF'
linux/scripts/utilities/update-bitcoin.sh linux-gnu x86_64 Bitcoin_Core updating --dry-run:
linux/scripts/utilities/update-electrum.sh linux-gnu x86_64 Electrum updating --dry-run:
linux/scripts/utilities/rollback-bitcoin.sh linux-gnu x86_64 Bitcoin_Core rolling_back No_backup_found
linux/scripts/utilities/rollback-electrum.sh linux-gnu x86_64 Electrum rolling_back No_backup_found
macos/scripts/utilities/update-bitcoin.sh darwin24 arm64 Bitcoin_Core updating --dry-run:
macos/scripts/utilities/update-electrum.sh darwin24 arm64 Electrum updating --dry-run:
macos/scripts/utilities/rollback-bitcoin.sh darwin24 arm64 Bitcoin_Core rolling_back No_backup_found
macos/scripts/utilities/rollback-electrum.sh darwin24 arm64 Electrum rolling_back No_backup_found
EOF

# The Electrum launchers start the bundle with arguments ("open --args"),
# which ps shows after the bundle's executable, whichever of the two names
# the bundle ships it under.
BUNDLE="/Volumes/PortaNode/macos/bin/Electrum.app/Contents/MacOS"
for exe in Electrum run_electrum; do
    listing="$(pgrep_listing "listing-$exe" \
        "$BUNDLE/$exe -D /Volumes/PortaNode/electrum-datadir --oneserver")"
    while read -r script doing; do
        args=(--dry-run)
        case "$script" in update-*) args+=(--version 99.0) ;; esac
        out="$(run_script "$listing:" darwin24 arm64 \
            "macos/scripts/utilities/$script" "${args[@]}")"
        check "macos $script stops where $exe runs with arguments" \
            stops_for_a_node "$out" Electrum "${doing//_/ }"
    done << 'EOF'
update-electrum.sh updating
rollback-electrum.sh rolling_back
EOF
done

# What the refusal protects: a rollback that passes its guard replaces the
# binary, and one without pgrep leaves it.
sha() {
    if command -v shasum > /dev/null; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        sha256sum "$1" | awk '{print $1}'
    fi
}
BIN="$ROOT/linux/bin"
ROLLBACK=linux/scripts/utilities/rollback-bitcoin.sh
prepare_rollback() {
    mkdir -p "$BIN/backup/bitcoin"
    echo installed > "$BIN/bitcoin-qt"
    echo backup > "$BIN/backup/bitcoin/bitcoin-qt"
    echo "$(sha "$BIN/backup/bitcoin/bitcoin-qt")  linux/bin/bitcoin-qt  version=28.1" \
        > "$ROOT/linux/checksums.sha256"
}
prepare_rollback
run_script "" linux-gnu x86_64 "$ROLLBACK" > /dev/null
check "a rollback without pgrep leaves the installed binary" \
    same installed "$(cat "$BIN/bitcoin-qt")"
prepare_rollback
run_script "$(pgrep_answering 1):" linux-gnu x86_64 "$ROLLBACK" > /dev/null
check "a rollback where pgrep finds no process replaces it" \
    same backup "$(cat "$BIN/bitcoin-qt")"

# _pids_outside_own_line on a table where 10 is the shell, 5 and 1 its
# ancestors, 11 and 12 its descendants, 20 an unrelated process and 30 and
# 31 a loop of parents.
# shellcheck source=shared/utilities/lib.sh
. "$REPO/shared/utilities/lib.sh"
TABLE="1 0
5 1
10 5
11 10
12 11
20 1
30 31
31 30"
outside() { same "$2" "$(_pids_outside_own_line 10 "$1" "$TABLE")"; }
check "the shell and its ancestors are left out" outside "10 5 1" ""
check "its descendants are kept" outside "11 12" "11
12"
check "an unrelated process is kept" outside "20" "20"
check "a pid missing from the table is kept" outside "99" "99"
check "a loop of parents among the ancestors ends" \
    same "20" "$(_pids_outside_own_line 30 "31 20" "$TABLE")"

# A process pgrep finds is not left out where ps cannot say whose it is.
mkdir -p "$WORK/ps-fails"
printf '#!/bin/sh\necho 4242\n' > "$WORK/ps-fails/pgrep"
printf '#!/bin/sh\nexit 1\n' > "$WORK/ps-fails/ps"
chmod +x "$WORK/ps-fails/pgrep" "$WORK/ps-fails/ps"
out="$(run_script "$WORK/ps-fails:" linux-gnu x86_64 \
    linux/scripts/utilities/rollback-bitcoin.sh --dry-run)"
check "a rollback refuses where pgrep finds a process and ps fails" \
    refused "$out" "Bitcoin Core" "rolling back"

# A folder whose path holds the pattern (ISS 808): the script's own command
# line, and its ancestors', match it. GNU procps pgrep reports them; macOS
# pgrep leaves its ancestors out. These cases use the real pgrep, on the
# Bitcoin scripts of a copy of the tree under such a path. Another run of
# this file matches the pattern too, so the cases hold hold_node_lock's
# lock, and a case is skipped where a process outside it matches before or
# after.
BTC_PATTERN="bitcoind|bitcoin-qt|bitcoin qt"
REAL_PGREP="$(command -v pgrep)"
# The stand-in nodes below end within 60 seconds, so that a killed run
# leaves none running for long. They close descriptor 9, so that the sleep
# one leaves when it is killed does not hold the lock. The "; :" keeps bash
# from replacing itself with sleep, which would drop the name.

# outside_match: 0 where a process this run did not start matches.
outside_match() {
    pgrep -f -i "$BTC_PATTERN" > /dev/null
}
# child_node_refused: 0 where the guard refuses a node the shell itself
# started.
child_node_refused() {
    local name="portanode-child-$$" out rc=0
    "$BASH" -c 'sleep 60; :' "$name" 9<&- &
    local node=$!
    if node_listed "$node" "$name"; then
        out="$(refuse_while_running "Bitcoin Core" updating "$name")" || rc=$?
    fi
    kill "$node"
    wait "$node" 2> /dev/null
    [ "$rc" -eq 1 ] && contains "$out" "Error: Bitcoin Core is running."
}
if [ -z "$REAL_PGREP" ]; then
    echo "ok - skipped: pgrep not found"
elif
    hold_node_lock
    lock_rc=$?
    [ "$lock_rc" -ne 0 ]
then
    case "$lock_rc" in
        1) why="another run held $NODE_LOCK for five minutes" ;;
        2) why="$NODE_LOCK cannot be opened" ;;
        *) why="perl not found" ;;
    esac
    echo "ok - skipped: the cases under bitcoind-usb ($why)"
else
    check "the guard refuses a node the shell started" child_node_refused
    mkdir -p "$WORK/real-pgrep" "$WORK/bitcoind-usb"
    ln -s "$REAL_PGREP" "$WORK/real-pgrep/pgrep"
    git -C "$REPO" ls-files -z | tar -C "$REPO" --null -T - -cf - 2> /dev/null \
        | tar -C "$WORK/bitcoind-usb" -xf -
    REPO="$WORK/bitcoind-usb"
    ROOT="$WORK/root-usb"
    mkdir -p "$ROOT/linux" "$ROOT/macos"
    : > "$ROOT/VERSION"
    while read -r script ostype arch doing past; do
        [ -n "$script" ] || continue
        doing="${doing//_/ }"
        past="${past//_/ }"
        args=(--dry-run)
        case "$script" in */update-*) args+=(--version 99.0) ;; esac
        what="$script under bitcoind-usb goes on where no node runs"
        if outside_match; then
            echo "ok - skipped: $what (a process matching $BTC_PATTERN runs here)"
        else
            out="$(run_script "$WORK/real-pgrep:" "$ostype" "$arch" "$script" "${args[@]}")"
            if outside_match; then
                echo "ok - skipped: $what (a process matching $BTC_PATTERN runs here)"
            else
                check "$what" passes "$out" "$past"
            fi
        fi
        "$BASH" -c 'sleep 60; :' bitcoind 9<&- &
        node=$!
        out=""
        if node_listed "$node" "$BTC_PATTERN"; then
            out="$(run_script "$WORK/real-pgrep:" "$ostype" "$arch" "$script" "${args[@]}")"
        fi
        kill "$node"
        wait "$node" 2> /dev/null
        check "$script under bitcoind-usb stops where a node runs" \
            stops_for_a_node "$out" "Bitcoin Core" "$doing"
    done << 'EOF'
linux/scripts/utilities/update-bitcoin.sh linux-gnu x86_64 updating --dry-run:
linux/scripts/utilities/rollback-bitcoin.sh linux-gnu x86_64 rolling_back No_backup_found
macos/scripts/utilities/update-bitcoin.sh darwin24 arm64 updating --dry-run:
macos/scripts/utilities/rollback-bitcoin.sh darwin24 arm64 rolling_back No_backup_found
EOF
fi

finish
