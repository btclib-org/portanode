# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# The Bitcoin launchers of macOS and Linux, each run from the tree on a root
# of its own whose Bitcoin Core binaries are stand-ins that record their
# arguments. ps is always a stand-in too, so that no node running on the
# machine decides a case. A case checks what the launcher gives Bitcoin Core
# and the folders it reports, or that it refuses with its message and then
# starts nothing and deletes nothing. One case checks the deadline every
# case puts on a launcher.
# shellcheck disable=SC2329 # check calls these functions by name

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
mkdir -p "$TMP/home" "$TMP/tmpdir" "$TMP/ps-none" "$TMP/ps-list" \
    "$TMP/ps-fails" "$TMP/rm-fails" "$TMP/mktemp"

# The stand-in for bitcoind, bitcoin-cli and bitcoin-qt: one line per call,
# its name and then each argument in brackets.
cat > "$TMP/stand-in" << 'EOF'
#!/bin/sh
{
    printf '%s' "${0##*/}"
    printf '[%s]' "$@"
    printf '\n'
} >> "${PORTANODE_TEST_CALLS:?}"
EOF
chmod +x "$TMP/stand-in"

printf '#!/bin/sh\nprintf "unrelated-process\\n"\n' > "$TMP/ps-none/ps"
# shellcheck disable=SC2016 # the stand-in expands it
printf '#!/bin/sh\ncat "${PORTANODE_TEST_PS:?}"\n' > "$TMP/ps-list/ps"
printf '#!/bin/sh\nexit 1\n' > "$TMP/ps-fails/ps"
printf '#!/bin/sh\nexit 1\n' > "$TMP/rm-fails/rm"

# mktemp -t writes into the TMPDIR the case gives, with the XXXXXX suffix
# GNU mktemp requires and the .command launchers' template lacks, as in
# regtest-cli-rcfile.sh.
real_mktemp="$(command -v mktemp)"
# The stub's own parameters expand when it runs, not here.
# shellcheck disable=SC2016
{
    echo '#!/bin/sh'
    echo 'if [ "$1" = -t ]; then'
    echo '    case "$2" in *XXX*) t="$2" ;; *) t="$2.XXXXXX" ;; esac'
    printf '    exec "%s" "${TMPDIR:?}/$t"\n' "$real_mktemp"
    echo 'fi'
    printf 'exec "%s" "$@"\n' "$real_mktemp"
} > "$TMP/mktemp/mktemp"
chmod +x "$TMP/ps-none/ps" "$TMP/ps-list/ps" "$TMP/ps-fails/ps" \
    "$TMP/rm-fails/rm" "$TMP/mktemp/mktemp"

# node_args <stem>: what the launcher <stem> gives Bitcoin Core after
# -datadir, as the stand-in records it.
node_args() {
    case "$1" in
        mainnet-8333-qt) echo '' ;;
        testnet3-18333-qt) echo '[-testnet]' ;;
        testnet4-48333-qt) echo '[-testnet4]' ;;
        regtest-18444-Alice-qt | regtest-18444-Alice-qt-clean)
            echo '[-regtest][-server][-addnode=localhost:18555][-addnode=localhost:18666]'
            ;;
        regtest-18444-Alice-cli | regtest-18444-Alice-cli-clean)
            echo '[-regtest][-rpcallowip=127.0.0.1][-addnode=localhost:18555][-addnode=localhost:18666]'
            ;;
        regtest-18555-Bob-qt | regtest-18555-Bob-qt-clean)
            echo '[-regtest][-server][-port=18555][-rpcport=18554][-addnode=localhost:18444][-addnode=localhost:18666]'
            ;;
        regtest-18555-Bob-cli | regtest-18555-Bob-cli-clean)
            echo '[-regtest][-port=18555][-rpcport=18554][-rpcallowip=127.0.0.1][-addnode=localhost:18444][-addnode=localhost:18666]'
            ;;
        regtest-18666-Carol-qt | regtest-18666-Carol-qt-clean)
            echo '[-regtest][-server][-port=18666][-rpcport=18665][-addnode=localhost:18444][-addnode=localhost:18555]'
            ;;
        regtest-18666-Carol-cli | regtest-18666-Carol-cli-clean)
            echo '[-regtest][-port=18666][-rpcport=18665][-rpcallowip=127.0.0.1][-addnode=localhost:18444][-addnode=localhost:18555]'
            ;;
        *)
            echo "  no arguments are known for $1; add them to node_args"
            return 1
            ;;
    esac
}

# datadir_of <stem>, netdir_of <stem>: the datadir under the root, and the
# network directory under the datadir.
datadir_of() {
    case "$1" in
        *-Bob-*) echo bitcoin-datadir/regtest_bob ;;
        *-Carol-*) echo bitcoin-datadir/regtest_carol ;;
        *) echo bitcoin-datadir ;;
    esac
}
netdir_of() {
    case "$1" in
        mainnet-*) echo '' ;;
        testnet3-*) echo /testnet3 ;;
        testnet4-*) echo /testnet4 ;;
        *) echo /regtest ;;
    esac
}

# rpcport_of <stem>: the -rpcport the btc function passes, if any.
rpcport_of() {
    case "$1" in
        *-Bob-*) echo '[-rpcport=18554]' ;;
        *-Carol-*) echo '[-rpcport=18665]' ;;
        *) echo '' ;;
    esac
}

# binaries_of <platform> <stem>: the binaries the launcher checks, relative
# to the root, in the order it checks them.
binaries_of() {
    case "$1/$2" in
        */*-cli*) printf '%s\n' "$1/bin/bitcoind" "$1/bin/bitcoin-cli" ;;
        linux/*) echo linux/bin/bitcoin-qt ;;
        *) echo macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt ;;
    esac
}

# new_case: a directory of its own for one case, holding the root, with a
# space in its path, and every stand-in binary. Sets CASE, ROOT, CALLS and
# PSLIST.
new_case() {
    local binary
    CASE="$(mktemp -d "$TMP/case.XXXXXX")" || return 1
    ROOT="$CASE/portanode root"
    CALLS="$CASE/calls"
    PSLIST="$CASE/ps"
    mkdir -p "$ROOT/linux/bin" "$ROOT/macos/bin/Bitcoin-Qt.app/Contents/MacOS"
    : > "$ROOT/VERSION"
    for binary in linux/bin/bitcoind linux/bin/bitcoin-cli linux/bin/bitcoin-qt \
        macos/bin/bitcoind macos/bin/bitcoin-cli \
        macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt; do
        cp "$TMP/stand-in" "$ROOT/$binary"
    done
}

# run <stubs> <input> <launcher path>: runs the launcher on ROOT with the
# stand-ins in <stubs> first on PATH and <input>, read by printf '%b', as
# its standard input. Sets OUT to what it printed and RC to its status, or
# to "killed" where it still ran after a minute (ends_within).
run() {
    local pid
    printf '%b' "$2" > "$CASE/stdin"
    HOME="$TMP/home" \
        TMPDIR="$TMP/tmpdir" \
        PORTANODE_ROOT="$ROOT" \
        PORTANODE_TEST_CALLS="$CALLS" \
        PORTANODE_TEST_PS="$PSLIST" \
        PATH="$1:$TMP/mktemp:$PATH" \
        "$BASH" "$3" < "$CASE/stdin" > "$CASE/stdout" 2>&1 &
    pid=$!
    RC=killed
    ends_within 60 "$pid" && RC="$STATUS"
    OUT="$(cat "$CASE/stdout")"
}

# input_of <stem>: the line confirming a clean launcher's wipe, and the
# command a -cli launcher's session runs: btc with an argument holding a
# space and an empty one, each of which btc passes on as it is.
input_of() {
    local input=''
    case "$1" in *-clean) input='\n' ;; *) ;; esac
    case "$1" in
        *-cli*) input="${input}btc echo 'one two' three ''\\n" ;;
        *) ;;
    esac
    printf '%s' "$input"
}

# calls_of <platform> <stem> <uacomment>: the calls the stand-ins record
# where the launcher starts.
calls_of() {
    local datadir node
    datadir="$ROOT/$(datadir_of "$2")"
    case "$1/$2" in
        */*-cli*) node=bitcoind ;;
        linux/*) node=bitcoin-qt ;;
        *) node=Bitcoin-Qt ;;
    esac
    case "$2" in *-cli*) node="${node}[-daemon]" ;; *) ;; esac
    printf '%s[-uacomment=%s][-datadir=%s]%s\n' \
        "$node" "$3" "$datadir" "$(node_args "$2")"
    case "$2" in
        *-cli*)
            printf 'bitcoin-cli[-regtest][-datadir=%s]%s[echo][one two][three][]\n' \
                "$datadir" "$(rpcport_of "$2")"
            ;;
        *) ;;
    esac
}

# started_nothing: 0 where no stand-in binary was called.
started_nothing() {
    [ ! -e "$CALLS" ] && return 0
    printf '  a stand-in was called:\n'
    sed 's/^/    /' "$CALLS"
    return 1
}

# refused <message>: 0 where the launcher printed <message> as its only
# error, exited 1 and started nothing.
refused() {
    contains "$OUT" "$1" \
        && same 1 "$(grep -c '^Error' <<< "$OUT")" \
        && same 1 "$RC" \
        && started_nothing
}

# starts <platform> <stem> <launcher>: with no network directory, the
# launcher reports its folders, starts Bitcoin Core with its arguments and,
# for -cli, defines btc for its datadir.
starts() {
    local datadir netdir
    node_args "$2" > /dev/null || return 1
    new_case || return 1
    datadir="$ROOT/$(datadir_of "$2")"
    netdir="$datadir$(netdir_of "$2")"
    run "$TMP/ps-none" "$(input_of "$2")" "$3"
    same 0 "$RC" \
        && contains "$OUT" "ROOTDIR is $ROOT" \
        && contains "$OUT" "DATADIR is $datadir" \
        && contains "$OUT" "BLOCKCHAINDIR is $netdir/blocks" \
        && contains "$OUT" "WALLETDIR is $netdir/wallets" \
        && same "$(calls_of "$1" "$2" "$2")" "$(cat "$CALLS" 2> /dev/null)"
}

# wallets_in_netdir <platform> <stem> <launcher>: with a network directory
# that has no wallets subfolder, the launcher reports that directory as the
# wallet directory, unless it is a clean launcher, whose wipe removes it.
wallets_in_netdir() {
    local netdir
    new_case || return 1
    netdir="$ROOT/$(datadir_of "$2")$(netdir_of "$2")"
    mkdir -p "$netdir"
    run "$TMP/ps-none" "$(input_of "$2")" "$3"
    same 0 "$RC" \
        && same "$(calls_of "$1" "$2" "$2")" "$(cat "$CALLS" 2> /dev/null)" \
        || return 1
    case "$2" in
        *-clean) contains "$OUT" "WALLETDIR is $netdir/wallets" ;;
        *) contains "$OUT" "WALLETDIR is $netdir" \
            && ! contains "$OUT" "WALLETDIR is $netdir/wallets" > /dev/null ;;
    esac
}

# The three cases below seed a clean launcher's folders with
# with_old_data, and check that its refusal deleted nothing.
seed_if_clean() {
    case "$1" in *-clean) with_old_data "$1" ;; *) ;; esac
}
intact_if_clean() {
    case "$1" in *-clean) kept_old_data "$1" && kept_others "$1" ;; *) ;; esac
}

# no_bin_dir <platform> <stem> <launcher>: without its platform's bin
# folder, the launcher refuses.
no_bin_dir() {
    new_case || return 1
    seed_if_clean "$2"
    rm -rf "${ROOT:?}/$1/bin"
    run "$TMP/ps-none" "$(input_of "$2")" "$3"
    refused "Error: Binaries directory not found at $1/bin" \
        && intact_if_clean "$2"
}

# no_binary <binary> <platform> <stem> <launcher>: without <binary>, the
# launcher refuses.
no_binary() {
    new_case || return 1
    seed_if_clean "$3"
    rm -f "${ROOT:?}/$1"
    run "$TMP/ps-none" "$(input_of "$3")" "$4"
    refused "Error: Binary not found at $1" && intact_if_clean "$3"
}

# not_executable <binary> <platform> <stem> <launcher>: with <binary> not
# executable, the launcher refuses.
not_executable() {
    new_case || return 1
    seed_if_clean "$3"
    chmod a-x "$ROOT/$1"
    run "$TMP/ps-none" "$(input_of "$3")" "$4"
    refused "Error: Binary not executable at $1" && intact_if_clean "$3"
}

# through_links <platform> <stem> <launcher>: started through a relative
# symbolic link to an absolute one, the launcher finds its library beside
# the file the links lead to, and names itself after the first link.
through_links() {
    new_case || return 1
    mkdir "$CASE/a" "$CASE/b"
    ln -s "$3" "$CASE/b/hop"
    ln -s ../b/hop "$CASE/a/by-link.sh"
    run "$TMP/ps-none" "$(input_of "$2")" "$CASE/a/by-link.sh"
    same 0 "$RC" \
        && same "$(calls_of "$1" "$2" by-link)" "$(cat "$CALLS" 2> /dev/null)"
}

# mainnet_running <launcher>: the mainnet launcher refuses while ps lists a
# mainnet node.
mainnet_running() {
    new_case || return 1
    printf '%s\n' unrelated-process '/opt/bitcoin/bin/bitcoind -datadir=/elsewhere' \
        > "$PSLIST"
    run "$TMP/ps-list" '' "$1"
    refused "Error: A Bitcoin Core mainnet process appears to be running."
}

# The clean launchers. wiped_of <stem> is the folder each deletes, under the
# root; in_use_of <stem> the message refusing a node on it.
wiped_of() {
    case "$1" in
        *-Alice-*) echo bitcoin-datadir/regtest ;;
        *) datadir_of "$1" ;;
    esac
}
in_use_of() {
    case "$1" in
        *-Alice-*) echo 'Error: a regtest Bitcoin process is using bitcoin-datadir.' ;;
        *) echo "Error: a Bitcoin process is using $(datadir_of "$1")." ;;
    esac
}
cannot_tell_of() {
    case "$1" in
        *-Alice-*) echo 'Error: could not tell whether a regtest Bitcoin process is' ;;
        *) echo 'Error: could not tell whether a Bitcoin process is using' ;;
    esac
}

# NODE_DIRS: the folder of each launcher's network, under the root.
NODE_DIRS=(bitcoin-datadir bitcoin-datadir/testnet3 bitcoin-datadir/testnet4
    bitcoin-datadir/regtest bitcoin-datadir/regtest_bob
    bitcoin-datadir/regtest_carol)

# others_of <stem>: each folder of NODE_DIRS that the clean launcher <stem>
# does not wipe.
others_of() {
    local dir wiped
    wiped="$(wiped_of "$1")"
    for dir in "${NODE_DIRS[@]}"; do
        case "$dir" in "$wiped" | "$wiped"/*) ;; *) echo "$dir" ;; esac
    done
}

# with_old_data <stem>: a file in the folder a clean launcher wipes, and one
# in each other network's folder.
with_old_data() {
    local dir
    mkdir -p "$ROOT/$(wiped_of "$1")"
    : > "$ROOT/$(wiped_of "$1")/old"
    while IFS= read -r dir; do
        mkdir -p "$ROOT/$dir"
        : > "$ROOT/$dir/kept"
    done < <(others_of "$1")
}

# kept_others <stem>: 0 where the file with_old_data put in each other
# network's folder is still there.
kept_others() {
    local dir missing=0
    while IFS= read -r dir; do
        [ -e "$ROOT/$dir/kept" ] && continue
        printf '  %s/kept was deleted\n' "$dir"
        missing=1
    done < <(others_of "$1")
    return "$missing"
}

# kept_old_data <stem>: 0 where the file with_old_data put in the wiped
# folder is still there.
kept_old_data() {
    [ -e "$ROOT/$(wiped_of "$1")/old" ] && return 0
    printf '  %s/old was deleted\n' "$(wiped_of "$1")"
    return 1
}

# wipes <platform> <stem> <launcher>: the clean launcher deletes its folder
# and no other network's folder.
wipes() {
    new_case || return 1
    with_old_data "$2"
    run "$TMP/ps-none" "$(input_of "$2")" "$3"
    same 0 "$RC" || return 1
    if kept_old_data "$2" > /dev/null; then
        printf '  %s/old was not deleted\n' "$(wiped_of "$2")"
        return 1
    fi
    kept_others "$2"
}

# blocked_on_input <pid>: 0 where process <pid> is asleep with no child
# process, which for a launcher past its prompt means its read is waiting
# on input: a command it ran instead would be a child, and work of its own
# would keep it running.
blocked_on_input() {
    case "$(ps -o stat= -p "$1" 2> /dev/null)" in
        S*) ! pgrep -P "$1" > /dev/null ;;
        *) return 1 ;;
    esac
}

# ends_within <seconds> <pid>: 0 once process <pid>, a child of this shell,
# has ended, with STATUS set to its exit status; 1 where it still runs after
# <seconds>, after killing it and its descendants (kill_tree).
ends_within() {
    local tenths=$(($1 * 10))
    while [ "$tenths" -gt 0 ]; do
        kill -0 "$2" 2> /dev/null || {
            STATUS=0
            wait "$2" || STATUS=$?
            return 0
        }
        sleep 0.1
        tenths=$((tenths - 1))
    done
    printf '  the launcher still ran after %s seconds\n' "$1"
    kill_tree "$2"
    wait "$2" 2> /dev/null
    return 1
}

# kill_tree <pid>: kills process <pid> and its descendants. Each process is
# stopped before its children are listed, so that it starts no other, and
# killed after them.
kill_tree() {
    local child
    kill -STOP "$1" 2> /dev/null
    for child in $(pgrep -P "$1"); do
        kill_tree "$child"
    done
    kill -9 "$1" 2> /dev/null
}

# alive <pid>: 0 where process <pid> runs, a zombie not counted.
alive() {
    case "$(ps -o stat= -p "$1" 2> /dev/null)" in
        '' | Z*) return 1 ;;
        *) return 0 ;;
    esac
}

# A stand-in launcher that never ends. It starts sleep, and a shell that
# starts sleep in turn, writes the pid of each of the three to the file it
# is given, one per line, and waits.
cat > "$TMP/hangs" << 'EOF'
"$BASH" -c 'sleep 300 & echo "$!" >> "$1"; wait' hangs "$1" &
echo "$!" >> "$1"
sleep 300 &
echo "$!" >> "$1"
wait
EOF

# kills_descendants: past its deadline, ends_within kills a launcher and
# every process it started, a child's child included. A process found
# alive is killed after the case reports it.
kills_descendants() {
    local pid listed=0 left=''
    new_case || return 1
    "$BASH" "$TMP/hangs" "$CASE/pids" &
    pid=$!
    for _ in $(seq 100); do
        [ -f "$CASE/pids" ] && listed="$(wc -l < "$CASE/pids")"
        [ "$((listed))" -eq 3 ] && break
        sleep 0.1
    done
    if ends_within 1 "$pid" > /dev/null; then
        printf '  the stand-in ended before its deadline\n'
        return 1
    fi
    same 3 "$((listed))" || return 1
    for _ in $(seq 50); do
        left=''
        while IFS= read -r pid; do
            alive "$pid" && left="$left $pid"
        done < "$CASE/pids"
        [ -z "$left" ] && return 0
        sleep 0.1
    done
    printf '  still running after the deadline:%s\n' "$left"
    # shellcheck disable=SC2086 # one pid per word
    kill -9 $left 2> /dev/null
    return 1
}

# waits_for_enter <platform> <stem> <launcher>: the clean launcher, past its
# prompt, waits on its input with its folder intact, and deletes the folder
# once Enter comes. Its input is a FIFO this shell holds open, so that the
# read waits rather than meeting the end of its input. Every wait has a
# deadline, after which the case fails.
waits_for_enter() {
    local pid waiting=no
    new_case || return 1
    with_old_data "$2"
    mkfifo "$CASE/in" || return 1
    HOME="$TMP/home" \
        TMPDIR="$TMP/tmpdir" \
        PORTANODE_ROOT="$ROOT" \
        PORTANODE_TEST_CALLS="$CALLS" \
        PORTANODE_TEST_PS="$PSLIST" \
        PATH="$TMP/ps-none:$TMP/mktemp:$PATH" \
        "$BASH" "$3" < "$CASE/in" > "$CASE/out" 2>&1 &
    pid=$!
    exec 3> "$CASE/in"
    for _ in $(seq 300); do
        kept_old_data "$2" > /dev/null || break
        if grep -q 'Press Enter' "$CASE/out" && blocked_on_input "$pid"; then
            waiting=yes
            break
        fi
        sleep 0.1
    done
    if [ "$waiting" = no ] || ! kept_old_data "$2"; then
        printf '  the launcher did not wait on its input past its prompt\n'
        exec 3>&-
        ends_within 30 "$pid"
        return 1
    fi
    printf '\n' >&3
    exec 3>&-
    ends_within 30 "$pid" || return 1
    if kept_old_data "$2" > /dev/null; then
        printf '  %s/old was not deleted after Enter\n' "$(wiped_of "$2")"
        return 1
    fi
}

# node_on_datadir <platform> <stem> <launcher>: the clean launcher refuses
# while ps lists a regtest node on its datadir, and deletes nothing.
node_on_datadir() {
    new_case || return 1
    with_old_data "$2"
    printf '%s\n' unrelated-process \
        "/opt/bitcoin/bin/bitcoind -regtest -datadir=$ROOT/$(datadir_of "$2")" \
        > "$PSLIST"
    run "$TMP/ps-list" "$(input_of "$2")" "$3"
    refused "$(in_use_of "$2")" && kept_old_data "$2" && kept_others "$2"
}

# ps_fails <platform> <stem> <launcher>: the clean launcher refuses where
# the process list cannot be read, and deletes nothing.
ps_fails() {
    new_case || return 1
    with_old_data "$2"
    run "$TMP/ps-fails" "$(input_of "$2")" "$3"
    refused "$(cannot_tell_of "$2")" && kept_old_data "$2" && kept_others "$2"
}

# rm_fails <platform> <stem> <launcher>: the clean launcher stops where its
# folder cannot be deleted.
rm_fails() {
    new_case || return 1
    with_old_data "$2"
    run "$TMP/ps-none:$TMP/rm-fails" "$(input_of "$2")" "$3"
    refused "Error: could not delete $(wiped_of "$2")." \
        && intact_if_clean "$2"
}

check "a launcher past its deadline is killed with every process it started" \
    kills_descendants

launchers=("$REPO"/linux/scripts/bitcoin/*.sh "$REPO"/macos/scripts/bitcoin/*.command)
for launcher in "${launchers[@]}"; do
    rel="${launcher#"$REPO"/}"
    platform="${rel%%/*}"
    name="${rel##*/}"
    stem="${name%.*}"
    check "$rel starts Bitcoin Core with its arguments" \
        starts "$platform" "$stem" "$launcher"
    check "$rel reports the wallet directory a network directory implies" \
        wallets_in_netdir "$platform" "$stem" "$launcher"
    check "$rel refuses without $platform/bin" \
        no_bin_dir "$platform" "$stem" "$launcher"
    while IFS= read -r binary; do
        check "$rel refuses without $binary" \
            no_binary "$binary" "$platform" "$stem" "$launcher"
        check "$rel refuses where $binary is not executable" \
            not_executable "$binary" "$platform" "$stem" "$launcher"
    done < <(binaries_of "$platform" "$stem")
    check "$rel runs through symbolic links" \
        through_links "$platform" "$stem" "$launcher"
    case "$stem" in
        mainnet-*)
            check "$rel refuses while a mainnet node runs" \
                mainnet_running "$launcher"
            ;;
        *-clean)
            check "$rel deletes $(wiped_of "$stem") and no other network's folder" \
                wipes "$platform" "$stem" "$launcher"
            check "$rel deletes nothing before Enter" \
                waits_for_enter "$platform" "$stem" "$launcher"
            check "$rel refuses while a node uses its datadir" \
                node_on_datadir "$platform" "$stem" "$launcher"
            check "$rel refuses where ps fails" \
                ps_fails "$platform" "$stem" "$launcher"
            check "$rel stops where the delete fails" \
                rm_fails "$platform" "$stem" "$launcher"
            ;;
        *) ;;
    esac
done

finish
