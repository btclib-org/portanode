# shellcheck shell=bash
# Tests of process_running_with and regtest_node_running_on in shared/lib.sh
# on a string holding a character outside ASCII, with and without a UTF-8
# locale in the caller's environment. Run from anywhere, on macOS or Linux:
#
#     bash shared/tests/process-running-with-locale.sh
#
# It starts a stand-in process, a bash whose command line carries a datadir
# argument, and no node. Exit 0 where every case passes, 1 where one fails.

set -u

# bash looks for a bare name in the current directory, then in PATH. Found
# through PATH, $0 has no directory, so the directory below would be wrong.
case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=shared/lib.sh
. "$SCRIPT_DIR/../lib.sh"

failures=0

# expect <status> <description> <command> [argument...]: runs the command
# in a subshell and compares its exit status with <status>.
expect() {
    local want="$1" what="$2" got
    shift 2
    ("$@")
    got=$?
    if [ "$got" -ne "$want" ]; then
        echo "FAIL: $what (wanted $want, got $got)"
        failures=$((failures + 1))
    fi
}

# without_locale <command> [argument...]: runs the command with no locale
# variable set.
without_locale() {
    unset LANG LC_ALL LC_CTYPE
    "$@"
}

# under <locale> <command> [argument...]
under() {
    local loc="$1"
    shift
    LC_ALL="$loc" "$@"
}

# not_1 <command> [argument...]: 0 where the command answers 0 or 2, 1
# where it answers 1. A guard may refuse where it cannot tell, never deny.
not_1() {
    "$@"
    [ $? -ne 1 ]
}

# listing <lines> <command> [argument...]: runs the command with <lines> as
# the process list.
listing() {
    PROCS="$1"
    shift
    # shellcheck disable=SC2329 # the functions of lib.sh call it
    _process_args() { printf '%s\n' "$PROCS"; }
    "$@"
}

# no_utf8_locale <command> [argument...]: runs the command as on a machine
# that has no UTF-8 locale.
no_utf8_locale() {
    # shellcheck disable=SC2329 # the functions of lib.sh call it
    _utf8_locale() { return 1; }
    "$@"
}

ARG="-datadir=/portanode-test-$$/Disco è/bitcoin-datadir/regtest_bob"
ASCII_ARG="-datadir=/portanode-test-$$/Disco/bitcoin-datadir/regtest_bob"
DIR="${ARG#-datadir=}"
ASCII_DIR="${ASCII_ARG#-datadir=}"

# The "; :" keeps bash from replacing itself with sleep, which would drop
# the arguments from the command line.
"$BASH" -c 'sleep 60; :' bitcoind -regtest "$ARG" "$ASCII_ARG" 2>/dev/null &
CHILD=$!
trap 'pkill -P "$CHILD" 2>/dev/null; kill "$CHILD" 2>/dev/null' EXIT

# ps lists the child once it has started; this waits up to five seconds.
for _ in 1 2 3 4 5 6 7 8 9 10; do
    process_running_with "$ASCII_ARG" && break
    sleep 0.5
done

if loc="$(_utf8_locale)"; then
    expect 0 "found with no locale variable set" \
        without_locale process_running_with "$ARG"
    expect 0 "found under LC_ALL=C" under C process_running_with "$ARG"
    expect 0 "found under LC_ALL=$loc" under "$loc" process_running_with "$ARG"
    expect 1 "a string outside ASCII no process holds answers 1" \
        process_running_with "$ARG-absent"
    expect 0 "found under LC_ALL=$loc on a line holding a byte that is not UTF-8" \
        under "$loc" listing "bitcoind -uacomment="$'\xff'" $ARG" \
        process_running_with "$ARG"
    for caller in "$loc" C; do
        expect 0 "found under LC_ALL=$caller whatever the case of a letter outside ASCII" \
            under "$caller" listing "bitcoind ${ARG/è/È}" \
            process_running_with "$ARG"
    done
    expect 0 "found with no locale variable set whatever the case of a letter outside ASCII" \
        without_locale listing "bitcoind ${ARG/è/È}" process_running_with "$ARG"

    expect 0 "regtest node found with no locale variable set" \
        without_locale regtest_node_running_on "$DIR"
    expect 0 "regtest node found under LC_ALL=C" \
        under C regtest_node_running_on "$DIR"
    expect 0 "regtest node found under LC_ALL=$loc" \
        under "$loc" regtest_node_running_on "$DIR"
    expect 1 "a datadir outside ASCII no node runs on answers 1" \
        regtest_node_running_on "$DIR-absent"
    for caller in "$loc" C; do
        expect 0 "regtest node found under LC_ALL=$caller whatever the case of a letter outside ASCII" \
            under "$caller" regtest_node_running_on "${DIR/è/È}"
        expect 0 "regtest node found under LC_ALL=$caller on a line of upper case letters outside ASCII" \
            under "$caller" listing "bitcoind -regtest ${ARG/è/È}" \
            regtest_node_running_on "$DIR"
    done
    for caller in "$loc" C; do
        expect 0 "regtest node found under LC_ALL=$caller on a line holding a byte that is not UTF-8" \
            under "$caller" listing "bitcoind -regtest -uacomment="$'\xff'" $ARG" \
            regtest_node_running_on "$DIR"
        expect 0 "a line holding a byte that is not UTF-8 and a letter of another case is found or refused under LC_ALL=$caller, never denied" \
            under "$caller" listing "bitcoind -regtest -uacomment="$'\xff'" ${ARG/è/È}" \
            not_1 regtest_node_running_on "$DIR"
    done
else
    echo "This machine has no UTF-8 locale."
    expect 2 "a string outside ASCII answers 2" process_running_with "$ARG"
    expect 2 "a datadir outside ASCII answers 2" regtest_node_running_on "$DIR"
fi

expect 2 "no UTF-8 locale: a string outside ASCII answers 2" \
    no_utf8_locale process_running_with "$ARG"
expect 0 "no UTF-8 locale: a string in ASCII is still found" \
    no_utf8_locale process_running_with "$ASCII_ARG"
expect 1 "no UTF-8 locale: a string in ASCII no process holds answers 1" \
    no_utf8_locale process_running_with "$ASCII_ARG-absent"

expect 2 "no UTF-8 locale: a datadir outside ASCII answers 2" \
    no_utf8_locale regtest_node_running_on "$DIR"
expect 0 "no UTF-8 locale: a regtest node on a datadir in ASCII is still found" \
    no_utf8_locale regtest_node_running_on "$ASCII_DIR"
expect 1 "no UTF-8 locale: a datadir in ASCII no node runs on answers 1" \
    no_utf8_locale regtest_node_running_on "$ASCII_DIR-absent"
expect 2 "a datadir holding a tab answers 2" \
    regtest_node_running_on "$DIR"$'\t'

expect 2 "a string holding a tab, which ps escapes, answers 2" \
    process_running_with "$ARG"$'\t'
expect 2 "a string holding a byte that is not UTF-8 answers 2" \
    process_running_with "$ARG"$'\xff'

if [ "$failures" -ne 0 ]; then
    echo "$failures case(s) failed"
    exit 1
fi
echo "Every case passed."
