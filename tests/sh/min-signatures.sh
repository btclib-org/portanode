# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# The number of signatures each updater asks for: the shell updaters read
# it from shared/utilities/lib.sh, and each Windows updater sets its own
# MIN_SIGNATURES once and passes it to both of its lib.bat calls. The
# cases hold the two platforms to the same number.
# shellcheck disable=SC2329 # check calls these functions by name

case "$0" in */*) ;; *) [ -f "$0" ] || {
    echo "$0: run this script by its path, not by a name found through PATH" >&2
    exit 1
} ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# sh_value <name>: the value lib.sh gives <name>, read by sourcing it in a
# shell of its own.
sh_value() {
    bash -c '. "$1" && eval "printf %s \"\${$2-}\""' _ \
        "$REPO/shared/utilities/lib.sh" "$1"
}

# bat_value <file>: the value each set of MIN_SIGNATURES in <file> gives,
# one per line. A set is read in any case, with or without a switch such
# as /a, quotes or an operator such as +=, at a line's start or after
# white space, "@", "(", "&" or "|", and as a later assignment of a set /a
# after "," or "(", so that a second one prints a second line and the
# cases below fail on it.
bat_value() {
    tr -d '\r' < "$1" | awk '
        {
            line = tolower($0)
            if (!match(line, /(^|[ \t@(&|])set([ \t]+|[ \t]*\/[a-z][ \t]*)("[ \t]*)?(.*[,(][ \t]*)?min_signatures[ \t]*[-+*\/%&|^<>]*=/))
                next
            v = substr($0, RSTART + RLENGTH)
            sub(/".*/, "", v)
            gsub(/[ \t]/, "", v)
            print v
        }
    '
}

# bat_uses <file>: how many lib.bat calls of <file>, with the lines a
# trailing "^" continues them onto, end in %%MIN_SIGNATURES%%.
bat_uses() {
    tr -d '\r' < "$1" | awk '
        cont { line = line " " $0 }
        !cont && /lib\.bat" :(preview_keyring|verify_pgp_signature) / { line = $0; open = 1 }
        { cont = open && /\^$/ }
        open && !cont { if (line ~ /%%MIN_SIGNATURES%%$/) n++; open = 0 }
        END { print n + 0 }
    '
}

# same_number <shell name> <bat file>: 0 where the .bat sets
# MIN_SIGNATURES once, to a number, and lib.sh gives <shell name> the same.
same_number() {
    local sh bat
    sh="$(sh_value "$1")"
    bat="$(bat_value "$REPO/win/scripts/utilities/$2")"
    case "$sh" in
        '' | *[!0-9]*) sh="not a number: '$sh'" ;;
        *) ;;
    esac
    same "$sh" "$bat"
}

# bat_value_of <text>: bat_value of a file holding <text>.
bat_value_of() {
    printf '%s' "$1" > "$TMP/set.bat"
    bat_value "$TMP/set.bat"
}
check "a later unquoted set of MIN_SIGNATURES is read" \
    same "$(printf '3\n1')" \
    "$(bat_value_of "$(printf 'set "MIN_SIGNATURES=3"\r\nset MIN_SIGNATURES=1\r\n')")"
check "a later set /a of MIN_SIGNATURES is read" \
    same "$(printf '3\n1')" \
    "$(bat_value_of "$(printf 'set "MIN_SIGNATURES=3"\r\nSET /A MIN_SIGNATURES=1\r\n')")"

check "a later set /a of MIN_SIGNATURES after a comma is read" \
    same "$(printf '3\n2\n2')" \
    "$(bat_value_of "$(printf 'set "MIN_SIGNATURES=3"\r\nset /a FOO=1, MIN_SIGNATURES=2\r\nset /a "FOO=1,MIN_SIGNATURES=2"\r\n')")"

check "update-bitcoin.bat asks for as many signatures as BITCOIN_CORE_MIN_SIGNATURES" \
    same_number BITCOIN_CORE_MIN_SIGNATURES update-bitcoin.bat
check "update-electrum.bat asks for as many signatures as ELECTRUM_MIN_SIGNATURES" \
    same_number ELECTRUM_MIN_SIGNATURES update-electrum.bat
for f in update-bitcoin.bat update-electrum.bat; do
    check "both lib.bat calls of $f pass MIN_SIGNATURES" \
        same 2 "$(bat_uses "$REPO/win/scripts/utilities/$f")"
done

finish
