# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# shellcheck disable=SC2329 # check and shared/lib.sh call these functions by name
# The node-detection helpers of shared/lib.sh, which the Alice -clean
# launchers and the mainnet launchers use to find a running node. It starts
# no node and reads no process list: each case replaces _process_args with
# the lines it names.

case "$0" in */*) ;; *) [ -f "$0" ] || {
    echo "$0: run this script by its path, not by a name found through PATH" >&2
    exit 1
} ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"
# shellcheck source=shared/lib.sh
. "$REPO/shared/lib.sh"

PROCS=""

# the functions of lib.sh call it
_process_args() {
    printf '%s' "$PROCS"
}

# answers <status> <function> [argument...]: 0 where the function, run
# against $PROCS, exits <status>.
answers() {
    local want="$1" got
    shift
    "$@"
    got=$?
    same "$want" "$got"
}

D="/Volumes/My Drive/portanode/bitcoin-datadir"
BIN="/Volumes/My Drive/portanode/macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"

# Alice -clean guard (ISS 661): a regtest node on this datadir is found
# whatever the order or the form of its arguments.
for args in \
    "-datadir=$D -regtest" \
    "-regtest -datadir=$D" \
    "-regtest=1 -datadir=$D" \
    "-regtest=2 -datadir=$D" \
    "-regtest= -datadir=$D" \
    "-regtest=-1 -datadir=$D" \
    "-noregtest=0 -datadir=$D" \
    "-datadir=$D -chain=regtest" \
    "-chain=regtest -datadir=$D" \
    "--regtest --datadir=$D" \
    "--chain=regtest --datadir=$D" \
    "-uacomment=x -regtest -rpcport=1 -datadir=$D -listen=0" \
    "-datadir=$D/ -regtest" \
    "-DATADIR=$D -REGTEST" \
    "-datadir=$D - -regtest"; do
    PROCS="$BIN $args"$'\n'
    check "regtest node found: $args" answers 0 regtest_node_running_on "$D"
done

# ISS 885: the regtest guard reads past a lone "-", where Core stops, so that
# a program path holding " - " cannot hide a regtest node from it.
PROCS="/Volumes/My - Drive/portanode/macos/bin/bitcoind -regtest -datadir=$D"$'\n'
check "regtest node found under /Volumes/My - Drive" answers 0 regtest_node_running_on "$D"

PROCS="/usr/bin/bitcoind -regtest -datadir=$D"$'\n'
check "bitcoind found" answers 0 regtest_node_running_on "$D"
check "datadir with a trailing slash given" answers 0 regtest_node_running_on "$D/"

for args in \
    "-datadir=$D" \
    "-datadir=$D -testnet" \
    "-datadir=$D -regtest=0" \
    "-datadir=$D -regtest=abc" \
    "-datadir=$D -regtest=00" \
    "-datadir=$D -noregtest" \
    "-datadir=$D -noregtest=1" \
    "-datadir=$D -chain=main" \
    "-datadir=$D -chain=regtestx" \
    "-datadir=$D/regtest_bob -regtest" \
    "-datadir=$D-regtest" \
    "-datadir=/Volumes/other/bitcoin-datadir -regtest" \
    "-regtest"; do
    PROCS="$BIN $args"$'\n'
    check "regtest node not found: $args" answers 1 regtest_node_running_on "$D"
done

PROCS=$'/bin/ls\n/usr/bin/vim notes\n'
check "no node running" answers 1 regtest_node_running_on "$D"

# ISS 888: on a datadir that exists, a node's -datadir counts by the
# directory it resolves to. One that is relative or does not resolve
# answers 2.
TMP="$(mktemp -d)" || exit 1
trap 'rm -rf "$TMP"' EXIT
REAL="$TMP/My Drive/portanode/bitcoin-datadir"
mkdir -p "$REAL" "$TMP/My Drive/portanode/x" "$TMP/other" "$TMP/My"
ln -s "$REAL" "$TMP/link"
for args in \
    "-datadir=$TMP/link -regtest" \
    "-regtest -datadir=$TMP/link/" \
    "-DATADIR=$TMP/link -REGTEST" \
    "-Chain=RegTest -datadir=$TMP/link" \
    "-datadir=$TMP/link -noRegTest=0" \
    "--datadir=$TMP/My Drive/portanode/x/../bitcoin-datadir -regtest" \
    "-datadir=/$REAL -regtest" \
    "-datadir=$TMP//My Drive/./portanode/bitcoin-datadir -regtest -listen=0"; do
    PROCS="$BIN $args"$'\n'
    check "regtest node found by its resolved datadir: $args" \
        answers 0 regtest_node_running_on "$REAL"
done
PROCS="$BIN -datadir=$REAL -regtest"$'\n'
check "regtest node found through a link in the datadir given" \
    answers 0 regtest_node_running_on "$TMP/link"
for args in \
    "-datadir=$TMP/other -regtest" \
    "-datadir=$TMP/My Drive/portanode/x -regtest" \
    "-datadir=bitcoin-datadir" \
    "-uacomment=-datadir=bitcoin-datadir -datadir=$TMP/other -regtest" \
    "-regtest -datadir=$TMP/other"; do
    PROCS="$BIN $args"$'\n'
    check "regtest node not found by its resolved datadir: $args" \
        answers 1 regtest_node_running_on "$REAL"
done
for args in \
    "-datadir=bitcoin-datadir -regtest" \
    "-datadir=./bitcoin-datadir -regtest" \
    "-datadir=$TMP/absent -regtest" \
    "-datadir=$TMP/My Drive/absent -regtest"; do
    PROCS="$BIN $args"$'\n'
    check "regtest node whose datadir is not known: $args" \
        answers 2 regtest_node_running_on "$REAL"
done
# "$TMP/My" resolves, but no word starting with "-" follows it.
PROCS="$BIN -datadir=$TMP/My Drive/gone -regtest"$'\n'
check "regtest node whose datadir is not known, with a shorter reading that resolves" \
    answers 2 regtest_node_running_on "$REAL"
# The residual ASSURANCE_CASE.md's *The launcher and its environment* states
# last: "$TMP/other -c" does not exist, so the -datadir reads as
# "$TMP/other", another directory than the guard's.
PROCS="$BIN -datadir=$TMP/other -c -regtest"$'\n'
check "documented residual: a datadir holding \" -\" reads as its part before it" \
    answers 1 regtest_node_running_on "$REAL"
PROCS="$BIN -datadir=bitcoin-datadir -regtest"$'\n'
check "a datadir that does not exist is compared as spelled" \
    answers 1 regtest_node_running_on "$TMP/absent"
check "a datadir under a directory that does not exist is compared as spelled" \
    answers 1 regtest_node_running_on "$TMP/absent/regtest"

# A datadir that may exist and does not resolve: a node with any -datadir
# that does not spell it answers 2, and the spelling still answers 0. Its
# bitcoin.conf cannot be read either, so a node with a -datadir that selects
# no network answers 2 too (ISS 887).
: > "$TMP/file"
ln -s "$TMP/gone" "$TMP/dangling"
for own in "$TMP/file" "$TMP/file/regtest" "$TMP/dangling"; do
    PROCS="$BIN -datadir=$TMP/other -regtest"$'\n'
    check "regtest node on another datadir, the guard's not resolving: $own" \
        answers 2 regtest_node_running_on "$own"
    PROCS="$BIN -datadir=$own -regtest"$'\n'
    check "regtest node on the datadir as spelled, the guard's not resolving: $own" \
        answers 0 regtest_node_running_on "$own"
    PROCS="$BIN -datadir=$TMP/other"$'\n'
    check "node with a -datadir, the guard's not resolving: $own" \
        answers 2 regtest_node_running_on "$own"
    PROCS="$BIN -regtest"$'\n'
    check "regtest node with no -datadir, the guard's not resolving: $own" \
        answers 1 regtest_node_running_on "$own"
done
# A directory that cannot be entered, which root enters all the same.
if [ "$(id -u)" -ne 0 ]; then
    mkdir -p "$TMP/locked/bitcoin-datadir"
    ln -s "$TMP/locked/bitcoin-datadir" "$TMP/to-locked"
    chmod 000 "$TMP/locked"
    PROCS="$BIN -datadir=$TMP/to-locked -regtest"$'\n'
    check "regtest node through a link, the guard's datadir not enterable" \
        answers 2 regtest_node_running_on "$TMP/locked/bitcoin-datadir"
    chmod 755 "$TMP/locked"
else
    echo "ok - skipped: the datadir that cannot be entered (root enters it)"
fi

# Two letters outside ASCII that differ in case: one directory on a volume
# that ignores case, two on one that does not, and the node counts on both.
U=$(printf '\303\211lan')
L=$(printf '\303\251LAN')
mkdir -p "$TMP/$U" "$TMP/$L"
PROCS="$BIN -datadir=$TMP/./$L -regtest"$'\n'
check "regtest node found by its resolved datadir, differing in case outside ASCII" \
    answers 0 regtest_node_running_on "$TMP/$U"

# Without a UTF-8 locale, a datadir that resolves outside ASCII cannot be
# compared as spelled: the same directory answers 0, any other 2.
R=$(printf 'r\303\251el')
mkdir -p "$TMP/$R"
ln -s "$TMP/$R" "$TMP/linkA"
ln -s "$TMP/$R" "$TMP/linkB"
no_utf8() {
    _utf8_locale() { return 1; }
    answers "$@"
}
PROCS="$BIN -datadir=$TMP/linkB -regtest"$'\n'
check "regtest node found through another link, with no UTF-8 locale" \
    no_utf8 0 regtest_node_running_on "$TMP/linkA"
PROCS="$BIN -datadir=$TMP/other -regtest"$'\n'
check "regtest node on another datadir, with no UTF-8 locale" \
    no_utf8 2 regtest_node_running_on "$TMP/linkA"

# macOS pwd -P keeps the NFC or NFD form of a name as it was given, and
# macOS opens the one directory for both.
if [ "$(uname)" = Darwin ]; then
    NFC=$(printf '\303\251t\303\251')
    NFD=$(printf 'e\314\201te\314\201')
    mkdir -p "$TMP/$NFD"
    PROCS="$BIN -datadir=$TMP/$NFC -regtest"$'\n'
    check "regtest node found by its datadir in NFC, the guard's in NFD" \
        answers 0 regtest_node_running_on "$TMP/$NFD"
    PROCS="$BIN -datadir=$TMP/$NFD -regtest"$'\n'
    check "regtest node found by its datadir in NFD, the guard's in NFC" \
        answers 0 regtest_node_running_on "$TMP/$NFC"
else
    echo "ok - skipped: the NFC and NFD cases (they run on macOS only)"
fi

# ISS 887: a node on the datadir that selects regtest in its configuration
# files. Each case writes the files it names, as "<file>:<content>", and
# expects the guard's answer: 0 where Core selects regtest, 1 where it does
# not, 2 where the guard cannot tell.
CONF="$TMP/conf dir/bitcoin-datadir"
mkdir -p "$CONF"
conf_case() {
    local want="$1" args="$2" file shown
    shift 2
    shown="$*"
    shown=${shown//$'\r'/\\r}
    shown=${shown//$'\n'/\\n}
    shown=${shown//$'\v'/\\v}
    shown=${shown//$'\f'/\\f}
    rm -f "$CONF"/*.conf
    for file in "$@"; do
        printf '%s' "${file#*:}" > "$CONF/${file%%:*}"
    done
    PROCS="$BIN -datadir=$CONF $args"$'\n'
    check "regtest in the configuration files: [$args] $shown" \
        answers "$want" regtest_node_running_on "$CONF"
}
conf_case 0 "" "bitcoin.conf:regtest=1"$'\n'
conf_case 1 "" "bitcoin.conf:txindex=1"$'\n'
# Core compares names byte for byte, so a byte order mark or a zero-width
# space makes a name of its own.
conf_case 0 "" "bitcoin.conf:"$'\xef\xbb\xbf'"chain=main"$'\n'"chain=regtest"$'\n'
conf_case 1 "" "bitcoin.conf:"$'\xef\xbb\xbf'"regtest=1"$'\n'
conf_case 0 "" "bitcoin.conf:regtest=1"$'\n'"no"$'\xe2\x80\x8b'"regtest=1"$'\n'
conf_case 1 "" "bitcoin.conf:["$'\xe2\x80\x8b'"]"$'\n'"regtest=1"$'\n'
conf_case 2 "" "bitcoin.conf:"$'\xef\xbb\xbf'"[regtest]"$'\n'
# Core trims vertical tab and form feed before the value's integer.
conf_case 0 "" "bitcoin.conf:regtest="$'\v'"1"$'\n'
conf_case 0 "" "bitcoin.conf:regtest="$'\f'"1"$'\n'
conf_case 2 "" "bitcoin.conf:rpcpassword=x # a comment"$'\n'
# Core reads no switch after a lone "-".
conf_case 0 "- -noconf" "bitcoin.conf:regtest=1"$'\n'
conf_case 0 "- -regtest=0" "bitcoin.conf:regtest=1"$'\n'
conf_case 0 "- -noincludeconf" "bitcoin.conf:includeconf=x.conf"$'\n' "x.conf:regtest=1"$'\n'
conf_case 0 "-regtest" "bitcoin.conf:chain=main"$'\n'
conf_case 0 "-regtest" "bitcoin.conf:regtest.includeconf=x.conf"$'\n' "x.conf:chain=main"$'\n'
# Core refuses more than one network, before it reads the included files or
# after, and the guard counts that node, as on Windows.
conf_case 0 "" "bitcoin.conf:regtest=1"$'\n'"signet=1"$'\n'"includeconf=x.conf"$'\n' "x.conf:regtest=0"$'\n'
conf_case 0 "" "bitcoin.conf:chain=regtest"$'\n'"signet=1"$'\n'"includeconf=x.conf"$'\n' "x.conf:nochain=1"$'\n'
conf_case 0 "" "bitcoin.conf:signet=1"$'\n'"testnet=1"$'\n'
conf_case 0 "" "bitcoin.conf:includeconf=x.conf"$'\n' "x.conf:signet=1"$'\n'"testnet=1"$'\n'
# bash cannot read a NUL byte as Core does, so the guard cannot tell.
rm -f "$CONF"/*.conf
printf 'noregtest=\0001\n' > "$CONF/bitcoin.conf"
PROCS="$BIN -datadir=$CONF"$'\n'
check "regtest in the configuration files: a NUL byte in bitcoin.conf" \
    answers 2 regtest_node_running_on "$CONF"
# Any other byte is read as itself under a UTF-8 locale too, a Latin-1
# comment included, which BSD tr refuses under that locale. The locale is
# set as a launcher's caller sets it: LANG, with no LC_ALL.
under_lang() {
    local lang="$1"
    shift
    (
        unset LC_ALL LC_CTYPE
        LANG=$lang
        export LANG
        "$@"
    )
}
if loc="$(_utf8_locale)"; then
    printf '# comment \351\ntxindex=1\n' > "$CONF/bitcoin.conf"
    check "no network in bitcoin.conf, with a Latin-1 comment, under LANG=$loc" \
        under_lang "$loc" answers 1 regtest_node_running_on "$CONF"
    printf 'regtest=1\n# comment \351\n' > "$CONF/bitcoin.conf"
    check "regtest in bitcoin.conf, with a Latin-1 comment, under LANG=$loc" \
        under_lang "$loc" answers 0 regtest_node_running_on "$CONF"
else
    echo "ok - skipped: the Latin-1 comment under a UTF-8 locale (no UTF-8 locale here)"
fi
conf_case 1 ""
conf_case 0 "" "bitcoin.conf:chain=regtest"$'\n'
conf_case 0 "" "bitcoin.conf:  regtest = 1 # a comment"$'\r\n'
conf_case 0 "" "bitcoin.conf:regtest=1"
conf_case 0 "" "bitcoin.conf:noregtest=0"$'\n'
conf_case 1 "" "bitcoin.conf:regtest=1"$'\n'"noregtest=1"$'\n'
conf_case 1 "" "bitcoin.conf:#regtest=1"$'\n'
conf_case 1 "" "bitcoin.conf:Regtest=1"$'\n'
conf_case 1 "" "bitcoin.conf:[regtest]"$'\n'"regtest=1"$'\n'
conf_case 1 "" "bitcoin.conf:regtest.regtest=1"$'\n'
conf_case 0 "" "bitcoin.conf:[regtest]"$'\n'"[]"$'\n'"regtest=1"$'\n'
# -chain takes its first value in the files after their last negation.
conf_case 0 "" "bitcoin.conf:chain=regtest"$'\n'"chain=main"$'\n'
conf_case 0 "" "bitcoin.conf:chain=main"$'\n'"nochain=1"$'\n'"chain=regtest"$'\n'"chain=main"$'\n'
# A negated -chain reads as the chain "0", which Core refuses as unknown.
conf_case 1 "" "bitcoin.conf:chain=regtest"$'\n'"nochain=1"$'\n'
# The command line wins, but Core skips a negation there.
conf_case 1 "-regtest=0" "bitcoin.conf:regtest=1"$'\n'
conf_case 0 "-noregtest" "bitcoin.conf:regtest=1"$'\n'
conf_case 1 "-chain=main" "bitcoin.conf:chain=regtest"$'\n'
conf_case 1 "-noconf" "bitcoin.conf:regtest=1"$'\n'
conf_case 1 "-conf=bitcoin.conf -noconf" "bitcoin.conf:regtest=1"$'\n'
conf_case 0 "-conf=x.conf" "x.conf:regtest=1"$'\n'
conf_case 0 "-conf=$CONF/x.conf -listen=0" "x.conf:regtest=1"$'\n'
conf_case 2 "-conf=x.conf" "bitcoin.conf:regtest=1"$'\n'
conf_case 2 "-conf"
conf_case 2 "" "bitcoin.conf:regtest"$'\n'
conf_case 2 "" "bitcoin.conf:-regtest=1"$'\n'
# The files that includeconf names, the top's and the selected network's.
conf_case 0 "" "bitcoin.conf:includeconf=x.conf"$'\n' "x.conf:regtest=1"$'\n'
conf_case 1 "-noincludeconf" "bitcoin.conf:includeconf=x.conf"$'\n' "x.conf:regtest=1"$'\n'
conf_case 1 "" "bitcoin.conf:includeconf=x.conf"$'\n'"noincludeconf=1"$'\n' "x.conf:regtest=1"$'\n'
conf_case 0 "" "bitcoin.conf:[main]"$'\n'"includeconf=x.conf"$'\n' "x.conf:regtest=1"$'\n'
conf_case 1 "" "bitcoin.conf:[test]"$'\n'"includeconf=x.conf"$'\n' "x.conf:regtest=1"$'\n'
conf_case 0 "" "bitcoin.conf:regtest=0"$'\n'"includeconf=x.conf"$'\n' "x.conf:regtest=1"$'\n'
conf_case 2 "" "bitcoin.conf:includeconf=x.conf"$'\n'
conf_case 2 "" "bitcoin.conf:noincludeconf=0"$'\n'
# A node on another datadir answers 1 where the guard's files select
# regtest, as they do for a node on its datadir, and where they cannot be
# read. Each case writes the files it reads.
rm -f "$CONF"/*.conf
printf 'regtest=1\n' > "$CONF/bitcoin.conf"
PROCS="$BIN -datadir=$CONF"$'\n'
check "a node on the datadir, regtest in the guard's bitcoin.conf" \
    answers 0 regtest_node_running_on "$CONF"
PROCS="$BIN -datadir=$TMP/other"$'\n'
check "a node on another datadir, regtest in the guard's bitcoin.conf" \
    answers 1 regtest_node_running_on "$CONF"
rm -f "$CONF"/*.conf
PROCS="$BIN -datadir=$TMP/other -conf=missing.conf"$'\n'
check "a node on another datadir, its -conf missing" \
    answers 1 regtest_node_running_on "$CONF"
rm -f "$CONF"/*.conf

# Mainnet check (ISS 662): the network flags count only as whole arguments.
for args in \
    "-datadir=/Volumes/btc-testnet-old" \
    "-datadir=/Volumes/btc-regtest-old/data" \
    "-datadir=/Volumes/btc-signet-old" \
    "-datadir=/Volumes/btc-testnet4-old -uacomment=x" \
    "-datadir=/Volumes/chain=regtest" \
    "-testnet=0" \
    "-testnet=abc" \
    "-notestnet" \
    "-notestnet=1" \
    "-chain=main" \
    "-chain=testnet" \
    "-chain=testnet3" \
    "-datadir=$D" \
    "-datadir=/d - -regtest" \
    "- -testnet" \
    "- -chain=signet" \
    ""; do
    PROCS="$BIN $args"$'\n'
    check "mainnet node found: $args" answers 0 mainnet_node_running
done

PROCS="/usr/local/bin/bitcoind -datadir=/Volumes/btc-testnet-old"$'\n'
check "mainnet bitcoind found" answers 0 mainnet_node_running

for args in \
    "-testnet" \
    "-testnet=1" \
    "-testnet=2" \
    "-notestnet=0" \
    "-testnet4" \
    "-regtest" \
    "-signet" \
    "--signet" \
    "-chain=test" \
    "-chain=testnet4" \
    "-chain=regtest" \
    "-chain=signet" \
    "-datadir=/Volumes/btc-testnet-old -regtest" \
    "-regtest - -x" \
    "-REGTEST"; do
    PROCS="$BIN $args"$'\n'
    check "mainnet node not found: $args" answers 1 mainnet_node_running
done

PROCS=$'/bin/ls /Volumes/btc-testnet-old\n'
check "no node running (mainnet)" answers 1 mainnet_node_running

PROCS=$'bitcoind -datadir=/Volumes/btc\n'
check "mainnet bare bitcoind found" answers 0 mainnet_node_running
PROCS=$'/usr/local/bin/bitcoind\n'
check "mainnet bitcoind with no argument found" answers 0 mainnet_node_running

# These directory names hold either word and name no node.
for line in \
    "/bin/bash /Volumes/bitcoind-disk/portanode/macos/scripts/bitcoin/mainnet-8333-qt.command" \
    "/bin/bash /Volumes/Bitcoin-Qt/portanode/linux/scripts/bitcoin/mainnet-8333-qt.sh"; do
    PROCS="$line"$'\n'
    check "mainnet node not found: $line" answers 1 mainnet_node_running
done

# A directory name that starts with either word and a space reads as a node:
# a false alarm, on the safe side.
PROCS=$'/bin/bash /Volumes/Bitcoin-Qt Drive/portanode/linux/scripts/bitcoin/mainnet-8333-qt.sh\n'
check "mainnet node found under /Volumes/Bitcoin-Qt Drive" answers 0 mainnet_node_running

# ISS 885: the mainnet check reads no flag after a lone "-", as Core reads
# none. A program path holding " - " then reads as a node with no network
# flag: a false alarm, on the safe side.
PROCS=$'/Volumes/My - Drive/portanode/macos/bin/bitcoind -regtest\n'
check "mainnet node found under /Volumes/My - Drive" answers 0 mainnet_node_running

# ISS 906: a value holding a byte that is not UTF-8 reads as Core reads it
# under a UTF-8 locale too, with LC_ALL unset (under_lang, above).
if loc="$(_utf8_locale)"; then
    PROCS="$BIN -datadir=$D -regtest="$'\xe9\n'
    check "no regtest node under LANG=$loc: -regtest=<0xE9>" \
        under_lang "$loc" answers 1 regtest_node_running_on "$D"
    PROCS="$BIN -datadir=$D -regtest=0"$'\xe9\n'
    check "no regtest node under LANG=$loc: -regtest=0<0xE9>" \
        under_lang "$loc" answers 1 regtest_node_running_on "$D"
    PROCS="/x/bitcoind -testnet="$'\xe9\n'
    check "mainnet node found under LANG=$loc: -testnet=<0xE9>" \
        under_lang "$loc" answers 0 mainnet_node_running
else
    echo "ok - skipped: the cases that need a UTF-8 locale (this machine has none)"
fi

# A process list that cannot be read answers 2 and not "no node".
_process_args() {
    return 1
}
check "unreadable list (regtest guard)" answers 2 regtest_node_running_on "$D"
check "unreadable list (mainnet)" answers 2 mainnet_node_running
check "unreadable list (process_running_with)" answers 2 process_running_with x

finish
