# shellcheck shell=bash
# process_running_with, in shared/lib.sh.

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"
# shellcheck source=shared/lib.sh
. "$REPO/shared/lib.sh"

# A process whose command line carries the marker. The marker holds
# characters an extended regular expression would read as operators, and
# the "; :" keeps bash from replacing itself with sleep, which would drop
# the marker from the command line.
MARKER="portanode-test-$$-(a+[b"
"$BASH" -c 'sleep 60; :' "$MARKER" 2>/dev/null &
CHILD=$!
trap 'pkill -P "$CHILD" 2>/dev/null; kill "$CHILD" 2>/dev/null' EXIT

# ps lists the child once it has started; this waits up to five seconds.
for _ in 1 2 3 4 5 6 7 8 9 10; do
    procs="$(ps -A -ww -o args=)"
    grep -q -F -e "$MARKER" <<<"$procs" && break
    sleep 0.5
done

status_of() {
    "$@"
    echo $?
}

check "a running process is found by a string its command line holds" \
    same 0 "$(status_of process_running_with "$MARKER")"

check "the string is compared ignoring case" \
    same 0 "$(status_of process_running_with "PORTANODE-TEST-$$-(A+[B")"

check "a string no command line holds answers 1" \
    same 1 "$(status_of process_running_with "$MARKER-absent")"

# shellcheck disable=SC2329 # process_running_with calls it
ps() { return 1; }
check "a process list that cannot be read answers 2" \
    same 2 "$(status_of process_running_with "$MARKER")"
unset -f ps

# A line that is not UTF-8 can hide a string outside ASCII from both
# searches, so process_running_with answers 2 there, never 1. It answers 1
# for a string in ASCII, which the C search reads on any line.
BAD=$'\xff'
ARG="-datadir=/x/Disco è/b"

# listed_status <locale> <lines> <string>: the answer for a process list of
# <lines>, with <locale> in the caller's environment.
listed_status() {
    LISTED="$2"
    # shellcheck disable=SC2329 # process_running_with calls it
    _process_args() { printf '%s\n' "$LISTED"; }
    LC_ALL="$1" process_running_with "$3"
    echo $?
}

# answers_not_1 <status>: 0 where <status> is 0 or 2.
# shellcheck disable=SC2329 # check calls it
answers_not_1() {
    [ "$1" -ne 1 ]
}

UTF8="$(_utf8_locale)" || UTF8=C
for caller in C "$UTF8"; do
    check "under LC_ALL=$caller a line holding a byte that is not UTF-8 and a datadir in another case is found or refused, never denied" \
        answers_not_1 "$(listed_status "$caller" "bitcoind -uacomment=${BAD} -datadir=/x/Disco È/b" "$ARG")"
    check "under LC_ALL=$caller a string in ASCII no line holds answers 1 on a line holding a byte that is not UTF-8" \
        same 1 "$(listed_status "$caller" "bitcoind -uacomment=${BAD} -datadir=/x/Disco/b" "-datadir=/x/other")"
done

check "a string holding a byte that is not UTF-8 answers 2" \
    same 2 "$(status_of process_running_with "$MARKER$BAD")"

finish
