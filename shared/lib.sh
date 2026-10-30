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

# sync_percent <fraction>: prints the fraction as a percentage with two
# decimals. It exits 1 where the fraction is not a number from 0 to 1, or
# where bc is missing, fails or prints something other than digits and a
# point; what it prints then is not a reading. The range check also refuses
# what printf accepts and bc cannot read, such as nan, inf and 0x10.
#
# The C locale is there because printf reads a number by the locale's
# decimal separator, so that under a comma it refuses bc's "99.99" and
# prints a wrong number: 0,00 under bash 3.2, 99,00 under bash 5. A prefix
# on the command is not enough: "LC_ALL=C printf" still prints 0,00 under
# bash 3.2.
#
# The first printf writes out an exponent, which jq can print for a small
# fraction and which bc misreads or refuses.
sync_percent() (
    export LC_ALL=C
    fraction="$(printf '%.12f' "$1" 2>/dev/null)" || exit 1
    case "$fraction" in
        0.* | 1.000000000000) ;;
        *) exit 1 ;;
    esac
    percent="$(echo "$fraction * 100" | bc -l 2>/dev/null)" || exit 1
    case "$percent" in
        '' | *[!0-9.]*) exit 1 ;;
    esac
    printf '%.2f' "$percent" 2>/dev/null
)

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
# The list is searched twice, whatever the caller's locale. The first
# search runs under the UTF-8 locale, where there is one, because under C
# grep folds the case of ASCII letters only, so "È" does not match "è"
# there. The second runs under C, because under a UTF-8 locale macOS grep
# finds nothing after a byte that is not UTF-8 on the same line, and macOS
# ps prints such a byte as itself under C.UTF-8.
process_running_with() {
    local procs loc first
    _ps_shows "$1" || return 2
    procs="$(_process_args)" || return 2
    loc="$(_utf8_locale)" || loc=C
    LC_ALL="$loc" grep -q -i -F -e "$1" <<<"$procs"
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

# _regtest_node_in <locale> <datadir> <process list>: regtest_node_running_on's
# search of one list, its letters folded to lower case by tr under <locale>:
# 0 where a line holds a regtest node on the datadir, 1 where none does, 2
# where tr failed, as BSD tr does under a UTF-8 locale on a byte that is not
# UTF-8.
_regtest_node_in() {
    local dir procs line pad
    dir="$(printf '%s' "$2" | LC_ALL="$1" tr '[:upper:]' '[:lower:]' 2>/dev/null)" || return 2
    dir="${dir%/}"
    procs="$(printf '%s\n' "$3" | LC_ALL="$1" tr '[:upper:]' '[:lower:]' 2>/dev/null)" || return 2
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

# _regtest_node_by_grep <locale> <datadir> <process list>: the same search
# for a datadir holding a letter outside ASCII, with grep finding the
# datadir whatever its case, under <locale>. GNU tr does not fold "È" to
# "è" there, so _regtest_node_in misses an "è" node. Each line grep finds is
# folded under C, with the text grep matched, and read as _regtest_node_in
# reads it.
_regtest_node_by_grep() {
    local dir="${2%/}" line found pad
    while IFS= read -r line; do
        pad=" $(printf '%s' "$line" | LC_ALL=C tr '[:upper:]' '[:lower:]') "
        while IFS= read -r found; do
            found="$(printf '%s' "$found" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
            if { _line_has_arg "$pad" "$found" || _line_has_arg "$pad" "$found/"; } \
                && _line_selects_network "$pad" regtest regtest; then
                return 0
            fi
        done < <(LC_ALL="$1" grep -a -o -i -F -e "datadir=$dir" <<<"$line" 2>/dev/null)
    done < <(LC_ALL="$1" grep -a -i -F -e "datadir=$dir" <<<"$3" 2>/dev/null)
    return 1
}

# regtest_node_running_on <datadir>: 0 where a running process was started
# with -datadir=<datadir> and selects regtest, in either order and in any
# form Core reads as regtest; 1 where none was; 2 where the process list
# could not be read or searched, or ps may not print <datadir> as itself
# (_ps_shows), which a caller about to delete something treats as 0.
# The datadir is compared ignoring case and a trailing slash, and as a whole
# argument, so a node on a directory inside <datadir> does not answer for it.
#
# A datadir in printable ASCII is searched under C, where tr folds case
# and fails on no byte. Any other datadir is searched under the UTF-8
# locale as well, whatever the caller's locale, for the reasons
# process_running_with gives. BSD tr folds a letter outside ASCII there and
# GNU tr does not, so grep under that locale searches too: GNU grep folds
# it. A miss is 1 only where the process list is valid UTF-8, because BSD
# tr fails on a byte that is not, and GNU tr and BSD grep pass over a line
# holding one without the letter folded or found; otherwise it is 2.
#
# Any process counts, not only a bitcoin-qt or bitcoind: a guard that errs
# toward "running" costs a refusal, the other way a deleted datadir.
regtest_node_running_on() {
    local procs loc first
    _ps_shows "$1" || return 2
    procs="$(_process_args)" || return 2
    if (LC_ALL=C; case $1 in *[!\ -~]*) exit 1 ;; esac); then
        _regtest_node_in C "$1" "$procs"
        return $?
    fi
    loc="$(_utf8_locale)" || return 2
    _regtest_node_in "$loc" "$1" "$procs"
    first=$?
    [ "$first" -eq 0 ] && return 0
    _regtest_node_in C "$1" "$procs"
    case $? in
        0) return 0 ;;
        1) ;;
        *) first=2 ;;
    esac
    _regtest_node_by_grep "$loc" "$1" "$procs" && return 0
    [ "$first" -eq 1 ] || return 2
    LC_ALL="$loc" grep -q -v -x -e '.*' <<<"$procs"
    [ $? -eq 1 ] && return 1
    return 2
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
