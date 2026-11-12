#!/bin/bash
# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

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
#
# The fraction is cut, not rounded, to the four decimals the percentage
# shows: 100.00 is a fraction of 1 to twelve decimals, and anything less
# reads at most 99.99. Bitcoin Core reports exactly 1 where its tip is its
# best header and that block is at most two hours from the node's clock.
# Every release README.md's *Version Compatibility* supports does so, from
# Core commit fa76b378e4.
sync_percent() (
    export LC_ALL=C
    fraction="$(printf '%.12f' "$1" 2>/dev/null)" || exit 1
    case "$fraction" in
        0.* | 1.000000000000) ;;
        *) exit 1 ;;
    esac
    fraction="${fraction%????????}"
    percent="$(echo "$fraction * 100" | bc -l 2>/dev/null)" || exit 1
    case "$percent" in
        '' | *[!0-9.]*) exit 1 ;;
    esac
    printf '%.2f' "$percent" 2>/dev/null
)

# escape_controls: copies standard input to standard output with each control
# character written as text, so that a terminal shows it rather than acts on
# it. A C0 byte other than the newline, and DEL, become \xHH, as Bitcoin
# Core's own log escaping writes them. A C1 character, U+0080 to U+009F in
# UTF-8, becomes \u00HH, and a byte 0x80 to 0x9F that is not part of a UTF-8
# character becomes \xHH. A carriage return that ends a line is dropped,
# even on a last line that no newline follows. The Windows monitor reads a
# byte that is not part of a UTF-8 character as U+FFFD, and its line split
# drops a carriage return only before a newline.
#
# sed reads bytes under the C locale; under UTF-8, macOS sed refuses a byte
# that is not UTF-8. An argument cannot hold a NUL, so the first sed escapes
# every 0x01, tr then turns each NUL into 0x01, and the second sed escapes
# those as \x00.
#
# A byte 0x80 to 0x9F is also a later byte of a character such as "€". So
# the first sed, once it has escaped the C0 bytes, 0x02 and 0x03 among
# them, puts a 0x02 before each later byte of a well-formed UTF-8 sequence,
# in the forms Unicode's Table 3-7 lists. No first byte is a later byte,
# so each form is matched on its own. It then parks each marked byte 0x80
# to 0x9F as 0x03 and its two hex digits, drops the other marks, escapes
# each byte 0x80 to 0x9F left, and puts the parked bytes back.
escape_controls() {
    local i j n oct hex c cr c2 soh mark park cont form first second pat rep
    printf -v cr '\r'
    printf -v c2 '\302'
    printf -v soh '\001'
    printf -v mark '\002'
    printf -v park '\003'
    printf -v cont '[\200-\277]'
    local -a sed_args=(-e "s/$cr\$//") park_args escape_args restore_args
    for ((i = 1; i < 160; i++)); do
        printf -v oct '%03o' "$i"
        printf -v hex '%02x' "$i"
        printf -v c %b "\\0$oct"
        if (((i < 32 && i != 10) || i == 127)); then
            sed_args+=(-e "s/$c/\\\\x$hex/g")
        elif ((i >= 128)); then
            sed_args+=(-e "s/$c2$c/\\\\u00$hex/g")
            park_args+=(-e "s/$mark$c/$park$hex/g")
            escape_args+=(-e "s/$c/\\\\x$hex/g")
            restore_args+=(-e "s/$park$hex/$c/g")
        fi
    done
    # Each form: its first byte, its second, and how many bytes follow.
    for form in \
        '[\302-\337] [\200-\277] 0' \
        '\340 [\240-\277] 1' \
        '[\341-\354\356\357] [\200-\277] 1' \
        '\355 [\200-\237] 1' \
        '\360 [\220-\277] 2' \
        '[\361-\363] [\200-\277] 2' \
        '\364 [\200-\217] 2'; do
        first="${form%% *}"
        n="${form##* }"
        second="${form#* }"
        second="${second%% *}"
        # shellcheck disable=SC2059 # the octal escapes are the bytes
        printf -v pat "\\\\($first\\\\)\\\\($second\\\\)"
        rep="\\1$mark\\2"
        for ((j = 3; j < n + 3; j++)); do
            pat+="\\($cont\\)"
            rep+="$mark\\$j"
        done
        sed_args+=(-e "s/$pat/$rep/g")
    done
    sed_args+=("${park_args[@]}" -e "s/$mark//g" "${escape_args[@]}"
        "${restore_args[@]}")
    LC_ALL=C sed "${sed_args[@]}" | LC_ALL=C tr '\000' '\001' \
        | LC_ALL=C sed "s/$soh/\\\\x00/g"
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

# _printable_ascii <string>: 0 where every character of <string> is printable
# ASCII; 1 otherwise.
_printable_ascii() {
    (
        LC_ALL=C
        case $1 in (*[![:print:]]*) exit 1 ;; esac
    )
}

# _ps_shows <string>: 0 where _process_args prints <string> as itself; 1
# where it may print it otherwise. Printable ASCII it prints as itself. Any
# other character it prints as itself only under a UTF-8 locale that calls
# it printable: macOS ps prints a tab as "\011" even under C.UTF-8.
#
# A byte that is not UTF-8 is refused by grep, not by the case below:
# bash 3.2 calls such a byte printable under a UTF-8 locale. Under that
# locale "." matches no such byte, so grep -v -x '.*' finds it.
_ps_shows() {
    local loc
    _printable_ascii "$1" && return 0
    loc="$(_utf8_locale)" || return 1
    LC_ALL="$loc" grep -q -v -x -e '.*' <<<"$1"
    [ $? -eq 1 ] || return 1
    (
        LC_ALL=$loc
        case $1 in (*[![:print:]]*) exit 1 ;; esac
    )
}

# process_running_with <string>: 0 where the command line of a running
# process holds <string>, ignoring case; 1 where none does; 2 where the
# process list could not be read or searched, ps may not print <string> as
# itself (_ps_shows), or both searches below may miss it, which a caller
# about to delete something treats as 0.
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
#
# Both searches can miss a string outside ASCII on a line that is not
# UTF-8, for the reasons above. Where the list holds such a line, found
# as in _ps_shows, the answer is 2, not 1.
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
        1) [ "$first" -eq 1 ] || return 2 ;;
        *) return 2 ;;
    esac
    _printable_ascii "$1" && return 1
    LC_ALL="$loc" grep -q -v -x -e '.*' <<<"$procs"
    [ $? -eq 1 ] && return 1
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
#
# Core reads no argument after a lone "-", and mainnet_node_running reads no
# flag there either. A program path holding " - ", as /Volumes/My - Drive,
# then reads as a node with no network flag. regtest_node_running_on reads
# past a lone "-", so that such a path cannot hide a node from it, and reads
# a node's configuration files both with the switches up to it and with all
# of them (_regtest_by_conf). Both readings err toward "running".

# _line_has_arg <padded line> <argument>: 0 where the line holds <argument>
# as a whole argument, in either dash form.
_line_has_arg() {
    [[ $1 == *" -$2 "* || $1 == *" --$2 "* ]]
}

# _value_reads_false <value>: 0 where Core reads the boolean value as false:
# a value that is not empty and whose leading integer, after white space and
# one sign, is zero or absent. The white space is Core's: space, tab, line
# feed, carriage return, vertical tab and form feed (TrimStringView in
# src/util/string.h).
_value_reads_false() {
    local re='^0*($|[^0-9])' ws=$' \t\n\r\v\f' v=$1
    v=${v#"${v%%[!"$ws"]*}"}
    [ -n "$1" ] && [[ ${v#[+-]} =~ $re ]]
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

# _conf_entries <file>: the settings of a configuration file, in order, as
# Core reads them (GetConfigOptions in src/common/config.cpp), one
# "<section>.<name>=<value>" per line, the section empty above the file's
# first section. A line ends at "#", and white space is space, tab, carriage
# return and line feed. "[name]" starts a section, and a name holding "."
# names its own, as "regtest.port". 1 where the file cannot be read or holds
# a line Core does not parse: one that starts with "-", holds no "=" and is
# no section, or sets rpcpassword and holds a "#"; 1 also where it holds a
# NUL byte, which bash drops and Core keeps. Any other byte is read as
# itself, whatever the caller's locale: the local LC_ALL reaches a command
# only where the caller exported LC_ALL, so each command is given LC_ALL=C,
# as the functions below do.
_conf_entries() {
    local LC_ALL=C line prefix="" key value hash ws=$' \t\r\n'
    [ -r "$1" ] || return 1
    [ "$(LC_ALL=C tr -d '\000' <"$1" | LC_ALL=C wc -c)" \
        -eq "$(LC_ALL=C wc -c <"$1")" ] || return 1
    while IFS= read -r line || [ -n "$line" ]; do
        hash=0
        case $line in *"#"*) hash=1 ;; esac
        line=${line%%"#"*}
        line=${line#"${line%%[!"$ws"]*}"}
        line=${line%"${line##*[!"$ws"]}"}
        case $line in
            "") continue ;;
            "["*"]") prefix="${line:1:${#line}-2}."; continue ;;
            -*) return 1 ;;
            *=*) ;;
            *) return 1 ;;
        esac
        key=${line%%=*}
        key=$prefix${key%"${key##*[!"$ws"]}"}
        case $hash$key in 1*rpcpassword*) return 1 ;; esac
        value=${line#*=}
        value=${value#"${value%%[!"$ws"]*}"}
        case $key in *.*) ;; *) key=".$key" ;; esac
        printf '%s=%s\n' "$key" "$value"
    done <"$1"
}

# _section_settings <entries> <section>: the entries of <section>, as
# _conf_entries prints them, without their section: "<name>=<value>".
_section_settings() {
    local e
    while IFS= read -r e; do
        case $e in "$2."*) printf '%s\n' "${e#"$2."}" ;; esac
    done <<<"$1"
}

# _setting_values <settings> <name>: the values Core keeps for the setting
# <name>, one per line in order, from <settings>, one "<name>=<value>" per
# line: "=<value>" for a value, "F" for a negation, as "noregtest=1", "T"
# for a double one, as "noregtest=0".
_setting_values() {
    local s
    while IFS= read -r s; do
        case $s in
            "$2="*) printf '=%s\n' "${s#*=}" ;;
            "no$2="*) if _value_reads_false "${s#*=}"; then echo T; else echo F; fi ;;
        esac
    done <<<"$1"
}

# _after_negation: the lines of its input after its last "F".
_after_negation() {
    LC_ALL=C awk '$0 == "F" { n = 0; next } { v[n++] = $0 } END { for (i = 0; i < n; i++) print v[i] }'
}

# _network_selected <switches> <entries> <network>: 0 where Core sets the
# network switch <network> from the command line's switches and the
# entries above the files' first section, both as _setting_values reads
# them: its last value on the command line, unless that value is a
# negation, which Core skips; then its last value in the files.
_network_selected() {
    local v
    v="$(_setting_values "$1" "$3" | LC_ALL=C tail -n 1)"
    case $v in "" | F) v="$(_setting_values "$2" "$3" | LC_ALL=C tail -n 1)" ;; esac
    case $v in
        T) return 0 ;;
        =*) ! _value_reads_false "${v#=}" ;;
        *) return 1 ;;
    esac
}

# _chain_setting <switches> <entries>: "=<name>" where Core takes "-chain"
# as <name>, read as _network_selected reads its switches, and nothing
# where it is not set: its last value on the command line, else its first
# value in the files after their last negation of it. Core reads a negated
# "-chain" as "0" and a double one as "1", neither of them a network.
_chain_setting() {
    local v
    v="$(_setting_values "$1" chain | LC_ALL=C tail -n 1)"
    if [ -z "$v" ]; then
        v="$(_setting_values "$2" chain)"
        [ -n "$v" ] || return 0
        v="$(printf '%s\n' "$v" | _after_negation | LC_ALL=C head -n 1)"
        v=${v:-F}
    fi
    case $v in
        T) echo "=1" ;;
        F) echo "=0" ;;
        *) printf '%s\n' "$v" ;;
    esac
}

# _networks_conflict <switches> <entries>: 0 where "-chain" and the network
# switches, read as _network_selected and _chain_setting read them, select
# more than one network, which GetChainArg in src/common/args.cpp refuses.
_networks_conflict() {
    local n=0 net
    [ -n "$(_chain_setting "$1" "$2")" ] && n=1
    for net in regtest signet testnet testnet4; do
        _network_selected "$1" "$2" "$net" && n=$((n + 1))
    done
    [ "$n" -gt 1 ]
}

# _regtest_by_conf <datadir> <line>: 0 where Core selects regtest from the
# line's switches and the configuration files it reads for a node on
# <datadir> (ReadConfigFiles in src/common/config.cpp); 1 where it does not;
# 2 where a file is missing that has to exist, or cannot be read or parsed
# (_conf_entries), or where Core fails on a double negation of
# "includeconf". The switches are read as _line_selects_network reads them,
# their names ignoring case. The files are read as they are now, not as they
# were when the node started.
#
# The file is "-conf", or bitcoin.conf where it is absent or empty, and a
# relative one is under <datadir>; "-noconf" reads none. A file that "-conf"
# names has to exist, as Core requires. ps prints no argument boundaries, so
# the value of "-conf" is read up to the first space followed by "-", or
# to the end of the line. Unless the command line holds "-includeconf" in
# any form, each "includeconf" of that file's section named after the
# network it selects, then of its top, after the last negation of it, names
# a file read after it; each of these has to exist. The answer is 0 where
# the switches and the files select more than one network, before the
# included files are read or after: Core refuses that node, and
# Test-NodeOnDatadir in win/scripts/bitcoin/node-args.ps1 counts it too.
#
# Not read: a "chain" in the section of the network selected, which Core
# refuses on a later read as a second network. The answer is 0 where the
# rest selects regtest, as regtest=1 with "chain=main" under [regtest] does,
# and 1 where it selects another, as testnet=1 with "chain=regtest" under
# [test] does; Test-NodeOnDatadir answers the same, and Core runs neither.
#
# Core reads no switch after a lone "-", where the line may hold the rest of
# a program path (above). So where the line holds one, it is read both whole
# and up to that "-": 0 where either reading answers 0, else 2 where either
# answers 2.
_regtest_by_conf() {
    local whole cut pad=" $2 "
    case $pad in *" - "*) ;; *) _regtest_by_conf_read "$1" "$2"; return ;; esac
    _regtest_by_conf_read "$1" "$2"
    whole=$?
    [ "$whole" -eq 0 ] && return 0
    _regtest_by_conf_read "$1" "${pad%%" - "*}"
    cut=$?
    [ "$cut" -eq 0 ] && return 0
    [ "$whole" -eq 2 ] || [ "$cut" -eq 2 ] && return 2
    return 1
}

# _regtest_by_conf_read <datadir> <line>: _regtest_by_conf's reading of the
# whole line.
_regtest_by_conf_read() {
    local LC_ALL=C pad low word switches="" v path explicit=1 off a b entries=""
    local top chain section file files more
    local -a words
    pad=" $2 "
    low="$(_fold "$pad")"
    read -r -a words <<<"$low"
    for word in "${words[@]}"; do
        case $word in
            --*) word=${word#--} ;;
            -*) word=${word#-} ;;
            *) continue ;;
        esac
        case $word in *=*) ;; *) word="$word=" ;; esac
        switches="$switches$word"$'\n'
    done
    v="$(_setting_values "$switches" conf | LC_ALL=C tail -n 1)"
    case $v in
        "") path=bitcoin.conf; explicit=0 ;;
        F) path="" ;;
        T) path=1 ;;
        =) path=bitcoin.conf ;;
        *)
            a=${low%" -conf="*}
            b=${low%" --conf="*}
            off=$((${#a} + 7))
            [ "$a" = "$low" ] && off=0
            [ "$b" != "$low" ] && [ "$((${#b} + 8))" -gt "$off" ] && off=$((${#b} + 8))
            path=${pad:off}
            path=${path%%" -"*}
            path=${path%"${path##*[! ]}"}
            ;;
    esac
    if [ -n "$path" ]; then
        case $path in /*) ;; *) path="$1/$path" ;; esac
        if [ -f "$path" ]; then
            entries="$(_conf_entries "$path")" || return 2
        elif [ "$explicit" -eq 1 ] || ! _absent "$path"; then
            return 2
        fi
    fi
    if [ -n "$entries" ] && [ -z "$(_setting_values "$switches" includeconf)" ]; then
        top="$(_section_settings "$entries" "")"
        _networks_conflict "$switches" "$top" && return 0
        chain="$(_chain_setting "$switches" "$top")"
        if [ -z "$chain" ]; then
            chain="=main"
            for v in regtest:regtest signet:signet testnet:test testnet4:testnet4; do
                if _network_selected "$switches" "$top" "${v%%:*}"; then
                    chain="=${v##*:}"
                    break
                fi
            done
        fi
        files=""
        for section in "${chain#=}" ""; do
            v="$(_section_settings "$entries" "$section")"
            v="$(_setting_values "$v" includeconf | _after_negation)"
            case $'\n'$v$'\n' in *$'\nT\n'*) return 2 ;; esac
            [ -n "$v" ] && files="$files$v"$'\n'
        done
        while IFS= read -r file; do
            [ -n "$file" ] || continue
            file=${file#=}
            case $file in /*) ;; *) file="$1/$file" ;; esac
            [ -f "$file" ] || return 2
            more="$(_conf_entries "$file")" || return 2
            entries="$entries"$'\n'"$more"
        done <<<"$files"
    fi
    top="$(_section_settings "$entries" "")"
    _network_selected "$switches" "$top" regtest && return 0
    [ "$(_chain_setting "$switches" "$top")" = "=regtest" ] && return 0
    _networks_conflict "$switches" "$top" && return 0
    return 1
}

# _regtest_selected <datadir> <line>: 0 where the line selects regtest, on
# its command line (_line_selects_network) or through its configuration
# files (_regtest_by_conf); 1 where it does neither; 2 where
# _regtest_by_conf cannot tell.
_regtest_selected() {
    _line_selects_network "$(_fold " $2 ")" regtest regtest && return 0
    _regtest_by_conf "$1" "$2"
}

# _regtest_node_in <locale> <datadir> <process list>: regtest_node_running_on's
# search of one list, its letters folded to lower case by tr under <locale>:
# 0 where a line holds the datadir and selects regtest (_regtest_selected,
# for a node on the datadir), 1 where none does, 2 where tr failed, as BSD tr
# does under a UTF-8 locale on a byte that is not UTF-8, or where
# _regtest_selected cannot tell for a line that holds the datadir.
_regtest_node_in() {
    local dir procs line orig pad answer=1
    dir="$(printf '%s' "$2" | LC_ALL="$1" tr '[:upper:]' '[:lower:]' 2>/dev/null)" || return 2
    dir="${dir%/}"
    procs="$(printf '%s\n' "$3" | LC_ALL="$1" tr '[:upper:]' '[:lower:]' 2>/dev/null)" || return 2
    while IFS= read -r line && IFS= read -r orig <&3; do
        pad=" $line "
        if _line_has_arg "$pad" "datadir=$dir" || _line_has_arg "$pad" "datadir=$dir/"; then
            _regtest_selected "$2" "$orig"
            case $? in
                0) return 0 ;;
                1) ;;
                *) answer=2 ;;
            esac
        fi
    done <<<"$procs" 3<<<"$3"
    return "$answer"
}

# _regtest_node_by_grep <locale> <datadir> <process list>: the same search
# for a datadir holding a letter outside ASCII, with grep finding the
# datadir whatever its case, under <locale>. GNU tr does not fold "È" to
# "è" there, so _regtest_node_in misses an "è" node. Each line grep finds is
# folded under C, with the text grep matched, and read as _regtest_node_in
# reads it.
_regtest_node_by_grep() {
    local dir="${2%/}" line found pad answer=1
    while IFS= read -r line; do
        pad=" $(printf '%s' "$line" | LC_ALL=C tr '[:upper:]' '[:lower:]') "
        while IFS= read -r found; do
            found="$(printf '%s' "$found" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
            if _line_has_arg "$pad" "$found" || _line_has_arg "$pad" "$found/"; then
                _regtest_selected "$2" "$line"
                case $? in
                    0) return 0 ;;
                    1) ;;
                    *) answer=2 ;;
                esac
            fi
        done < <(LC_ALL="$1" grep -a -o -i -F -e "datadir=$dir" <<<"$line" 2>/dev/null)
    done < <(LC_ALL="$1" grep -a -i -F -e "datadir=$dir" <<<"$3" 2>/dev/null)
    return "$answer"
}

# _real_dir <dir>: the directory <dir> names, with every symbolic link, "."
# and ".." resolved and every run of "/" read as one; 1 where <dir> is not
# absolute or cannot be entered. The letters keep the case given, as macOS
# pwd -P prints them on a volume that ignores case. cd and pwd are bash's
# own, so no realpath(1) is needed. bash's pwd -P keeps exactly two leading
# slashes, and this keeps one.
_real_dir() {
    local real
    case $1 in /*) ;; *) return 1 ;; esac
    real="$(CDPATH='' cd -P -- "$1" 2>/dev/null && pwd -P)" || return 1
    case $real in //*) real=${real#/} ;; esac
    printf '%s\n' "$real"
}

# _absent <path>: 0 where <path> is absolute and is known not to exist: the
# nearest of its ancestors that exists is a directory _real_dir can enter,
# and nothing below it, not even a symbolic link leading nowhere, stands on
# the way to <path>. 1 otherwise, as where an ancestor cannot be entered and
# <path> may exist under it.
_absent() {
    local dir=$1
    case $dir in /*) ;; *) return 1 ;; esac
    [ -e "$dir" ] || [ -L "$dir" ] && return 1
    until [ -e "$dir" ] || [ -L "$dir" ]; do
        dir=${dir%/*}
        dir=${dir:-/}
    done
    _real_dir "$dir" >/dev/null
}

# _fold <string>: <string> with its ASCII letters in lower case.
_fold() {
    printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]'
}

# _regtest_node_resolved <real datadir> <process list>: regtest_node_running_on's
# search by resolved path. 0 where a line that selects regtest
# (_regtest_selected, for a node on <real datadir>) has a reading of a
# -datadir, below, that _real_dir resolves, and the result is the same file
# as <real datadir> or _regtest_node_named counts it as <real datadir>; 2
# where a line that selects regtest, or for which _regtest_selected cannot
# tell, has a -datadir that is not absolute or not known, or a reading on
# which _regtest_node_named answers 2, or where _regtest_selected cannot
# tell for a line that would otherwise answer 0; 1 otherwise. The same file
# is found by device and inode, which match where macOS pwd -P keeps the NFC or
# NFD form of a name as given and the node used the other form.
#
# ps prints no argument boundaries, so a value is read up to each space after
# it in turn, the last reading ending with the line. One of those readings is
# the argument the node was given, and each is tried. A shorter reading can
# resolve to another directory, so the -datadir is known only where a reading
# that ends before a word starting with "-", or with the line, resolves. A
# -datadir holding " -" that does not resolve, where its part before " -"
# does, still reads as known, as that other directory.
_regtest_node_resolved() (
    LC_ALL=C
    answer=1
    while IFS= read -r line; do
        case $line in *[Dd][Aa][Tt][Aa][Dd][Ii][Rr]=*) ;; *) continue ;; esac
        _regtest_selected "$1" "$line"
        selected=$?
        [ "$selected" -eq 1 ] && continue
        pad=" $line "
        low="$(_fold "$pad")"
        off=0
        while :; do
            rest=${low:off}
            case $rest in *-datadir=*) ;; *) break ;; esac
            head=${rest%%-datadir=*}
            start=$((off + ${#head}))
            off=$((start + 9))
            case ${low:0:start} in *" " | *" -") ;; *) continue ;; esac
            value=${pad:off}
            case $value in /*) ;; *) answer=2; continue ;; esac
            reading=""
            known=1
            while [ -n "$value" ]; do
                reading="$reading${value%%" "*}"
                value=${value#*" "}
                if real="$(_real_dir "$reading")"; then
                    if [ "$real" -ef "$1" ]; then
                        [ "$selected" -eq 0 ] && exit 0
                        answer=2
                    else
                        _regtest_node_named "$1" " -regtest -datadir=$real"
                        case $? in
                            0) [ "$selected" -eq 0 ] && exit 0; answer=2 ;;
                            1) ;;
                            *) answer=2 ;;
                        esac
                    fi
                    case $value in "" | -*) known=0 ;; esac
                fi
                reading="$reading "
            done
            [ "$known" -eq 0 ] || answer=2
        done
    done <<<"$2"
    exit "$answer"
)

# _regtest_datadir_given <process list> <datadir>: 0 where a line that
# selects regtest, or where _regtest_selected cannot tell, for a node on
# <datadir>, holds a -datadir, as _regtest_node_resolved reads one; 1
# otherwise.
_regtest_datadir_given() (
    LC_ALL=C
    while IFS= read -r line; do
        case $line in *[Dd][Aa][Tt][Aa][Dd][Ii][Rr]=*) ;; *) continue ;; esac
        low="$(_fold " $line ")"
        case $low in *" -datadir="* | *" --datadir="*) ;; *) continue ;; esac
        _regtest_selected "$2" "$line"
        [ $? -eq 1 ] || exit 0
    done <<<"$1"
    exit 1
)

# _regtest_node_named <datadir> <process list>: regtest_node_running_on's
# search by the datadir's spelling, with the same answers.
#
# A datadir in printable ASCII is searched under C, where tr folds case
# and fails on no byte. Any other datadir is searched under the UTF-8
# locale as well, whatever the caller's locale, for the reasons
# process_running_with gives. BSD tr folds a letter outside ASCII there and
# GNU tr does not, so grep under that locale searches too: GNU grep folds
# it. A miss is 1 only where the process list is valid UTF-8, because BSD
# tr fails on a byte that is not, and GNU tr and BSD grep pass over a line
# holding one without the letter folded or found; otherwise it is 2.
_regtest_node_named() {
    local loc first
    if (LC_ALL=C; case $1 in *[!\ -~]*) exit 1 ;; esac); then
        _regtest_node_in C "$1" "$2"
        return $?
    fi
    loc="$(_utf8_locale)" || return 2
    _regtest_node_in "$loc" "$1" "$2"
    first=$?
    [ "$first" -eq 0 ] && return 0
    _regtest_node_in C "$1" "$2"
    case $? in
        0) return 0 ;;
        1) ;;
        *) first=2 ;;
    esac
    _regtest_node_by_grep "$loc" "$1" "$2" && return 0
    [ "$first" -eq 1 ] || return 2
    LC_ALL="$loc" grep -q -v -x -e '.*' <<<"$2"
    [ $? -eq 1 ] && return 1
    return 2
}

# regtest_node_running_on <datadir>: 0 where a running process was started
# with a -datadir naming <datadir> and selects regtest, in either order and
# in any form Core reads as regtest, on its command line or in its
# configuration files (_regtest_selected); 1 where none was; 2 where the
# process list could not be read or searched, ps may not print <datadir> as
# itself (_ps_shows), _regtest_selected cannot tell for a process with such
# a -datadir, or a process that selects regtest, or for which
# _regtest_selected cannot tell, has a -datadir that is not known to name
# another directory, which a caller about to delete something treats as 0.
# That last is a -datadir whose directory is not known
# (_regtest_node_resolved) where <datadir> resolves, and any -datadir that
# does not spell <datadir> (_regtest_datadir_given) where <datadir> neither
# resolves nor is known not to exist (_absent).
#
# Where <datadir> resolves (_real_dir), a -datadir names it where it
# resolves to the same directory, or to a path that spells <datadir>'s
# resolved path ignoring case, whatever its own spelling. Either way a
# -datadir names it where it spells it, ignoring case and a trailing slash,
# as a whole argument, so a node on a directory inside <datadir> does not
# answer for it. Core refuses a -datadir that is not a directory, so where
# <datadir> does not exist, no node uses it under another name.
#
# Any process counts, not only a bitcoin-qt or bitcoind: a guard that errs
# toward "running" costs a refusal, the other way a deleted datadir.
regtest_node_running_on() {
    local procs real by_path=1 by_name
    _ps_shows "$1" || return 2
    procs="$(_process_args)" || return 2
    if real="$(_real_dir "$1")"; then
        _regtest_node_resolved "$real" "$procs"
        by_path=$?
        [ "$by_path" -eq 0 ] && return 0
    elif ! _absent "$1"; then
        _regtest_datadir_given "$procs" "$1" && by_path=2
    fi
    _regtest_node_named "$1" "$procs"
    by_name=$?
    [ "$by_name" -eq 1 ] && return "$by_path"
    return "$by_name"
}

# mainnet_node_running: 0 where a running bitcoin-qt or bitcoind selects no
# network other than mainnet; 1 where none does; 2 where the process list
# could not be read. A line is a node when "bitcoin-qt" or "bitcoind",
# ignoring case, is the last part of a path: the bare name at the start of the
# line, or "/bitcoin-qt" or "/bitcoind" followed by a space or the end of the
# line. A process whose path holds either word in a directory name, such as a
# launcher under /Volumes/bitcoind-disk, is not a node, unless a "/", the word
# and a space begin the name, as in /Volumes/Bitcoin-Qt Drive.
# The network flags are read as whole arguments, so a node whose path holds
# "-testnet" is still a mainnet node.
#
# A network flag read as true before a lone "-" selects that network, though
# Core reads only the last one, so a repeated flag can hide a mainnet node.
mainnet_node_running() {
    local procs line pad net
    local nets=(testnet:test testnet4:testnet4 signet:signet regtest:regtest)
    procs="$(_process_args)" || return 2
    procs="$(printf '%s\n' "$procs" | tr '[:upper:]' '[:lower:]')" || return 2
    while IFS= read -r line; do
        case $line in
            bitcoin-qt | "bitcoin-qt "* | */bitcoin-qt | *"/bitcoin-qt "*) ;;
            bitcoind | "bitcoind "* | */bitcoind | *"/bitcoind "*) ;;
            *) continue ;;
        esac
        pad=" $line "
        pad="${pad%%" - "*} "
        for net in "${nets[@]}"; do
            if _line_selects_network "$pad" "${net%%:*}" "${net##*:}"; then
                continue 2
            fi
        done
        return 0
    done <<<"$procs"
    return 1
}

# _pids_outside_own_line SELF PIDS TABLE
#
# Prints each of PIDS, which are separated by spaces, that is neither SELF
# nor an ancestor of SELF. TABLE holds a "pid ppid" line for each process,
# as "ps -A -o pid= -o ppid=" prints it. A child of SELF is printed.
_pids_outside_own_line() {
    printf '%s\n' "$3" | awk -v self="$1" -v pids="$2" '
        { parent[$1] = $2 }
        END {
            mine[self] = 1
            for (p = self; p in parent && !(parent[p] in mine); p = parent[p])
                mine[parent[p]] = 1
            n = split(pids, list, " ")
            for (i = 1; i <= n; i++) {
                if (!(list[i] in mine)) print list[i]
            }
        }'
}

# pgrep_outside_own_line <pattern>: prints the pid of each process whose
# command line matches <pattern>, as pgrep -f -i reads it, other than this
# shell and its ancestors (_pids_outside_own_line). Returns 0 where it
# prints a pid, or where pgrep exits 0 and prints none; 1 where no other
# process matches; 2 or more where pgrep or ps is missing or failed.
#
# pgrep exits 1 both where nothing matches and, as busybox pgrep does,
# where it refuses an option such as -i, which it then reports on stderr
# only (ISS 810). So an exit 1 counts as "no match" only where the same
# pgrep, given the same options and the pattern ".", finds a process, and
# the answer is 2 otherwise. A working pgrep always finds one: the next
# paragraph says which processes each leaves out.
#
# GNU procps pgrep leaves out only itself, so where the folder's path
# matches <pattern>, the shell running the script matches, and so does a
# launcher that started it (ISS 808, ISS 836). macOS pgrep leaves out its
# ancestors. A node that is an ancestor of this shell is left out on both.
#
# This shell is BASHPID, read before any command substitution, inside
# which it is the substitution's own pid. bash 3.2, which macOS ships, has
# no BASHPID, and $$ stands in: a subshell between the two is an ancestor
# of pgrep, which macOS pgrep leaves out. pgrep runs under exec, so that
# the command substitution's subshell, a copy of this shell, is pgrep
# itself and not a child of this shell left in the answer.
pgrep_outside_own_line() {
    local rc=0 found table self="${BASHPID:-$$}"
    found="$(exec pgrep -f -i "$1")" || rc=$?
    if [ "$rc" -eq 1 ]; then
        pgrep -f -i . > /dev/null 2>&1 || return 2
        return 1
    fi
    [ "$rc" -eq 0 ] && [ -n "$found" ] || return "$rc"
    table="$(ps -A -o pid= -o ppid=)" || return 2
    found="$(_pids_outside_own_line "$self" "${found//$'\n'/ }" "$table")" \
        || return 2
    [ -n "$found" ] || return 1
    printf '%s\n' "$found"
}
