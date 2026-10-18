#!/bin/bash
# Shared helpers for every platform's scripts. This file names no
# platform on purpose. macos/scripts/lib.sh and linux/scripts/lib.sh each
# forward to it rather than holding the implementation, so the path
# arithmetic into shared/ lives in one forwarder per platform instead of
# in every script that would otherwise source it directly.

# is_portanode_root <dir>: 0 where <dir> holds VERSION and at least one of
# macos/, win/ or linux/, which is what marks a root; 1 otherwise.
# Both ways resolve_root arrives at a root apply it.
is_portanode_root() {
    [ -f "$1/VERSION" ] && \
        { [ -d "$1/macos" ] || [ -d "$1/win" ] || [ -d "$1/linux" ]; }
}

# resolve_root <start_dir>: prints the root. A PORTANODE_ROOT that is not
# one (is_portanode_root) is an error: nothing is printed, the message
# names the variable on stderr, and the status is 1. A caller stops on it,
# as in ROOTDIR="$(resolve_root "$SCRIPT_DIR")" || exit 1, because the
# empty ROOTDIR would otherwise be the root of every path built after it.
resolve_root() {
    local start_dir="$1"

    if [ -n "${PORTANODE_ROOT:-}" ]; then
        if is_portanode_root "$PORTANODE_ROOT"; then
            (cd "$PORTANODE_ROOT" && pwd -P)
            return 0
        fi
        printf 'PORTANODE_ROOT is set to "%s", which is not a PortaNode folder: it holds no VERSION beside macos/, win/ or linux/. Unset PORTANODE_ROOT, or set it to the folder.\n' \
            "$PORTANODE_ROOT" >&2
        return 1
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
        if is_portanode_root "$dir"; then
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

# _utf8_locale: prints the name of a UTF-8 locale this machine has; 1 where
# it finds none.
_utf8_locale() {
    local loc
    for loc in C.UTF-8 en_US.UTF-8; do
        if [ "$(LC_ALL=$loc locale charmap 2>/dev/null)" = UTF-8 ]; then
            printf '%s\n' "$loc"
            return 0
        fi
    done
    return 1
}

# _process_args: one line per running process, holding its arguments as
# ps prints them. A test replaces this function to feed the functions below
# a process list of its own.
#
# ps runs under a UTF-8 locale where the machine has one, whatever the
# caller's locale: under C, macOS ps prints "è" as "M-CM-(", and a path
# holding it never matches itself. Without one, ps runs under C, and
# _ps_shows refuses every string that is not printable ASCII.
_process_args() {
    local loc
    loc="$(_utf8_locale)" || loc=C
    LC_ALL="$loc" ps -A -ww -o args=
}

# _ps_shows <string>: 0 where _process_args prints <string> as itself; 1
# where it may print it otherwise. Printable ASCII it prints as itself. Any
# other character it prints as itself only under a UTF-8 locale that calls
# it printable: macOS ps prints a tab as "\011" even under C.UTF-8.
_ps_shows() {
    local loc
    (
        LC_ALL=C
        case $1 in (*[![:print:]]*) exit 1 ;; esac
    ) && return 0
    loc="$(_utf8_locale)" || return 1
    (
        LC_ALL=$loc
        case $1 in (*[![:print:]]*) exit 1 ;; esac
    )
}

# process_running_with <string>: 0 where the command line of a running
# process holds <string>, ignoring case; 1 where none does; 2 where the
# process list could not be read or searched, or ps may not print <string>
# as itself (_ps_shows), which a caller about to delete something treats
# as 0.
#
# The string is compared as a string. pgrep -f reads its pattern as an
# extended regular expression, so a path holding "(", "+" or "[" does not
# match itself there, and a guard built on it reports no process. The
# list is read in full before grep starts, so grep's own command line,
# which carries the string, is not in it.
#
# The list is searched twice. Under a UTF-8 locale, macOS grep finds
# nothing after a byte that is not UTF-8 on the same line, and macOS ps
# prints such a byte as itself under C.UTF-8. Under C, grep compares bytes
# and folds the case of ASCII letters only, so "È" does not match "è" there.
process_running_with() {
    local procs first
    _ps_shows "$1" || return 2
    procs="$(_process_args)" || return 2
    grep -q -i -F -e "$1" <<<"$procs"
    first=$?
    [ "$first" -eq 0 ] && return 0
    LC_ALL=C grep -q -i -F -e "$1" <<<"$procs"
    case $? in
        0) return 0 ;;
        1) [ "$first" -eq 1 ] && return 1 ;;
    esac
    return 2
}

# regtest_node_running_on and mainnet_node_running read a command line as a
# string, where ps gives no argument boundaries. An argument is a run between
# spaces, so a flag is found only as a word of its own. A path holding
# "-regtest" is not the flag, and a path holding a space is still found,
# because the datadir is searched as a whole string.
#
# Bitcoin Core (src/common/args.cpp, src/util/chaintype.cpp) reads "-flag" and
# "--flag" alike. A boolean flag is true bare, with an empty value, or with a
# value whose leading integer is not zero: "-regtest=2" is true, "-regtest=0"
# and "-regtest=abc" are false. "-noflag" is false, and "-noflag=0" is true.
# The network is a flag or "-chain=<name>", testnet3's name there being "test".

# _line_has_arg <padded line> <argument>: 0 where the line holds <argument>
# as a whole argument, in either dash form.
_line_has_arg() {
    [[ $1 == *" -$2 "* || $1 == *" --$2 "* ]]
}

# _value_reads_false <value>: 0 where Core reads the boolean value as false:
# a value that is not empty and whose leading integer is zero or absent.
_value_reads_false() {
    local re='^0*($|[^0-9])'
    [ -n "$1" ] && [[ ${1#[+-]} =~ $re ]]
}

# _line_selects_network <line> <flag> <chain>: 0 where the line selects the
# network named <flag> as a flag and <chain> as a "-chain" value, in any form
# above. The line may be padded.
_line_selects_network() {
    local word
    local -a words
    read -r -a words <<<"$1"
    for word in "${words[@]}"; do
        case $word in
            --*) word=${word#--} ;;
            -*) word=${word#-} ;;
            *) continue ;;
        esac
        case $word in
            "$2") return 0 ;;
            "$2="*) _value_reads_false "${word#*=}" || return 0 ;;
            "no$2="*) _value_reads_false "${word#*=}" && return 0 ;;
            "chain=$3") return 0 ;;
        esac
    done
    return 1
}

# regtest_node_running_on <datadir>: 0 where a running process was started
# with -datadir=<datadir> and selects regtest, in either order and in any
# form Core reads as regtest; 1 where none was; 2 where the process list
# could not be read, which a caller about to delete something treats as 0.
# The datadir is compared ignoring case and a trailing slash, and as a whole
# argument, so a node on a directory inside <datadir> does not answer for it.
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
            && _line_selects_network "$pad" regtest regtest; then
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
#
# A network flag read as true anywhere on the line selects that network, though
# Core reads only the last one, so a repeated flag can hide a mainnet node.
mainnet_node_running() {
    local procs line pad net
    local nets=(testnet:test testnet4:testnet4 signet:signet regtest:regtest)
    procs="$(_process_args)" || return 2
    procs="$(printf '%s\n' "$procs" | tr '[:upper:]' '[:lower:]')" || return 2
    while IFS= read -r line; do
        case $line in
            *bitcoin-qt* | *bitcoind*) ;;
            *) continue ;;
        esac
        pad=" $line "
        for net in "${nets[@]}"; do
            if _line_selects_network "$pad" "${net%%:*}" "${net##*:}"; then
                continue 2
            fi
        done
        return 0
    done <<<"$procs"
    return 1
}
