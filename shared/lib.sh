#!/bin/bash
# Shared helpers for every platform's scripts. This file names no
# platform on purpose. macos/scripts/lib.sh and linux/scripts/lib.sh each
# forward to it rather than holding the implementation, so the path
# arithmetic into shared/ lives in one forwarder per platform instead of
# in every script that would otherwise source it directly.

resolve_root() {
    local start_dir="$1"

    if [ -n "${PORTANODE_ROOT:-}" ]; then
        if [ -d "$PORTANODE_ROOT" ]; then
            (cd "$PORTANODE_ROOT" && pwd -P)
            return 0
        fi
        printf "%s" "$PORTANODE_ROOT"
        return 0
    fi

    local dir="$start_dir"
    while [ -n "$dir" ]; do
        # A root is marked by VERSION plus at least one platform
        # directory, not by all three: a checkout of a source archive, or
        # a tree being assembled, need not hold every platform directory
        # yet, and requiring all three here would make this probe fail on
        # such a checkout, sending its caller to the fallback below
        # instead of to the root it is actually sitting in.
        #
        # This is looser than requiring all three: an ancestor holding
        # VERSION plus only one platform directory now matches, where the
        # stricter form would have refused it and kept walking. That is
        # safe for a real caller in this tree, and not merely assumed
        # safe: this loop starts at start_dir and walks upward, returning
        # on the first match, and a genuine checkout's own root already
        # satisfies the probe (VERSION, macos/ and win/ are all there) --
        # so the walk from any script actually inside this folder stops
        # at that real root before it can reach any looser-matching
        # ancestor further up. The loosened match only fires where no
        # real root sits between start_dir and it, which is not a shape
        # any caller in this tree is in.
        if [ -f "$dir/VERSION" ] && \
           { [ -d "$dir/macos" ] || [ -d "$dir/win" ] || [ -d "$dir/linux" ]; }; then
            (cd "$dir" && pwd -P)
            return 0
        fi
        # The walk stops at "/", not where the next directory comes
        # back equal to the current one. That test never fires: the next
        # directory is "$dir/..", which at "/" is "//..", and a leading
        # double slash is implementation-defined in POSIX and kept by
        # bash -- "//.." resolves to "//" and "///.." back to "/", so the
        # two alternate and the walk does not end. Measured on bash 3.2
        # and on 5.x.
        #
        # Stopping at "/" is enough because nothing else repeats: the
        # parent of any other directory has one component fewer, and "//"
        # steps to "/" rather than to itself.
        if [ "$dir" = "/" ]; then
            break
        fi
        dir="$(cd "$dir/.." && pwd -P)"
    done

    (cd "$start_dir" && pwd -P)
}

# _process_args: one line per running process, holding its arguments as
# ps prints them. A test replaces this function to feed the functions below
# a process list of its own.
_process_args() {
    ps -A -ww -o args=
}

# process_running_with <string>: 0 where the command line of a running
# process holds <string>, ignoring case; 1 where none does; 2 where the
# process list could not be read or searched, which a caller about to
# delete something treats as 0.
#
# The string is compared as a string. pgrep -f reads its pattern as an
# extended regular expression, so a path holding "(", "+" or "[" does not
# match itself there, and a guard built on it reports no process. The
# list is read in full before grep starts, so grep's own command line,
# which carries the string, is not in it.
process_running_with() {
    local procs
    procs="$(_process_args)" || return 2
    grep -q -i -F -e "$1" <<<"$procs"
    case $? in
        0) return 0 ;;
        1) return 1 ;;
        *) return 2 ;;
    esac
}

# The two functions below read a command line as a string, where ps gives no
# argument boundaries. An argument is a run between spaces, so a flag is
# found only as " <flag> " in the line padded with a space at each end. A
# path holding "-regtest" is not the flag, and a path holding a space is
# still found, because the datadir is searched as a whole string.
#
# Core reads "-flag" and "--flag" alike, a boolean flag as bare or "=1", and
# the network as one of those flags or as "-chain=<name>".

# _line_has_arg <padded line> <argument>: 0 where the line holds <argument>
# as a whole argument, in either dash form.
_line_has_arg() {
    [[ $1 == *" -$2 "* || $1 == *" --$2 "* ]]
}

# _line_selects_network <padded line> <network>: 0 where the line selects
# <network>, given as the flag's name (regtest, testnet, testnet4, signet).
_line_selects_network() {
    _line_has_arg "$1" "$2" || _line_has_arg "$1" "$2=1" \
        || _line_has_arg "$1" "chain=$2"
}

# regtest_node_running_on <datadir>: 0 where a running process was started
# with -datadir=<datadir> and selects regtest, in either order and either
# form; 1 where none was; 2 where the process list could not be read, which a
# caller about to delete something treats as 0. The datadir is compared
# ignoring case and a trailing slash, and as a whole argument, so a node on a
# directory inside <datadir> does not answer for it.
#
# Any process counts, not only a bitcoin-qt or bitcoind: a guard that errs
# toward "running" costs a refusal, the other way a deleted datadir.
regtest_node_running_on() {
    local dir procs line pad
    dir="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    dir="${dir%/}"
    procs="$(_process_args)" || return 2
    procs="$(printf '%s\n' "$procs" | tr '[:upper:]' '[:lower:]')" || return 2
    while IFS= read -r line; do
        pad=" $line "
        if { _line_has_arg "$pad" "datadir=$dir" \
                || _line_has_arg "$pad" "datadir=$dir/"; } \
            && _line_selects_network "$pad" regtest; then
            return 0
        fi
    done <<<"$procs"
    return 1
}

# mainnet_node_running: 0 where a running bitcoin-qt or bitcoind selects no
# network other than mainnet; 1 where none does; 2 where the process list
# could not be read. A line is a node when it holds "bitcoin-qt" or
# "bitcoind" anywhere, ignoring case, as the launchers read it.
# The network flags are read as whole arguments, so a node whose path holds
# "-testnet" is still a mainnet node.
mainnet_node_running() {
    local procs line pad net
    procs="$(_process_args)" || return 2
    procs="$(printf '%s\n' "$procs" | tr '[:upper:]' '[:lower:]')" || return 2
    while IFS= read -r line; do
        case $line in
            *bitcoin-qt* | *bitcoind*) ;;
            *) continue ;;
        esac
        pad=" $line "
        for net in testnet testnet3 testnet4 signet regtest; do
            if _line_selects_network "$pad" "$net"; then
                continue 2
            fi
        done
        return 0
    done <<<"$procs"
    return 1
}
