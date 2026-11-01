# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

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

finish
