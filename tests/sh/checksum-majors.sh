# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# Each */checksums.sha256 against README.md's Version Compatibility: the
# Bitcoin Core entries, where a file has any, are those of the supported
# majors only.
# shellcheck disable=SC2329 # check calls these functions by name

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# supported_count <readme>: how many Core majors Version Compatibility
# supports. It knows one wording; another prints nothing, so the case
# below fails until this function learns it.
supported_count() {
    awk '
        /^## / { in_section = ($0 == "## Version Compatibility"); next }
        in_section && /^- \*\*Bitcoin Core\*\*:/ { bullet = 1; text = $0; next }
        bullet && /^  / { text = text " " substr($0, 3); next }
        bullet { bullet = 0 }
        END {
            gsub(/[[:space:]]+/, " ", text)
            if (index(text, "the latest major release and the one before it are supported")) print 2
        }
    ' "$1"
}

# core_majors <checksums>: the major of each Bitcoin Core entry, one per
# line, sorted, and "unparsed" for one whose version has no digit major.
# It reads an entry as loosely as the verifiers do:
# shared/utilities/lib.sh's verify_binaries takes any 64-character first
# field, and win/scripts/utilities/verify-binaries.ps1 a hash in either
# case and a path with backslashes, compared lowercased, and both take an
# entry with no version=. A Core entry is one whose path, so read, is
# under bin/ and starts bitcoin.
core_majors() {
    awk '
        length($1) == 64 {
            p = tolower($2)
            gsub(/\\/, "/", p)
            if (p !~ /\/bin\/bitcoin/) next
            v = $0
            if (sub(/.*version=/, "", v) == 0) { print "unparsed"; next }
            split(v, part, ".")
            print (part[1] ~ /^[0-9]+$/ ? part[1] : "unparsed")
        }
    ' "$1" | LC_ALL=C sort -u
}

# latest_major <checksums>...: the highest Core major the files record.
# The tree states the bundled version nowhere else, so it is the
# reference each file is held to: an entry of major latest - count or
# lower fails, even in a file whose own newest major would pass it.
latest_major() {
    local f
    for f in "$@"; do core_majors "$f"; done | grep -E '^[0-9]+$' | LC_ALL=C sort -n | tail -n 1
}

# supported_only <checksums> <count> <latest>: 0 where every Core major
# parses and lies within <count> of <latest>, otherwise 1 with the majors
# printed.
supported_only() {
    local majors m
    majors="$(core_majors "$1")"
    for m in $majors; do
        case "$m" in
            *[!0-9]*) ;;
            *) [ "$m" -gt "$(($3 - $2))" ] && [ "$m" -le "$3" ] && continue ;;
        esac
        echo "  majors in ${1#"$REPO"/}: $(printf '%s\n' "$majors" | paste -sd " " -)"
        return 1
    done
    return 0
}

count="$(supported_count "$REPO/README.md")"
check "README.md's Version Compatibility says how many Core majors are supported" \
    [ -n "$count" ]
: "${count:=0}"

latest="$(latest_major "$REPO"/*/checksums.sha256)"
check "the checksum files hold Core entries the cases read" [ -n "$latest" ]
: "${latest:=0}"

for f in "$REPO"/*/checksums.sha256; do
    check "${f#"$REPO"/} holds Core entries of the supported majors only" \
        supported_only "$f" "$count" "$latest"
done

# refused <case> <line>: a copy of win/checksums.sha256 with <line> added
# fails supported_only.
refused() {
    cp "$REPO/win/checksums.sha256" "$TMP/$1.sha256"
    printf '%s\n' "$2" >>"$TMP/$1.sha256"
    ! supported_only "$TMP/$1.sha256" "$count" "$latest" >/dev/null
}

zeros="$(printf '0%.0s' $(seq 64))"
old="$((latest - count))"
check "an entry of a major below the supported ones is refused" \
    refused below "$zeros  win/bin/bitcoind.exe  version=$old.2"
check "such an entry with an uppercase hash and a backslash path is refused" \
    refused upper "$(printf 'A%.0s' $(seq 64))  win\\bin\\bitcoind.exe  version=$old.2"
check "a Core entry with no version is refused" \
    refused unversioned "$zeros  win/bin/bitcoind.exe"
check "a Core entry whose major is not digits is refused" \
    refused nondigit "$zeros  win/bin/bitcoind.exe  version=x.1"

# A file of two entries, one of the oldest supported major and one a major
# below it: the file's own newest major would pass both, and the other
# files' refuses the second.
printf '%s  win/bin/bitcoind.exe  version=%s.0\n' \
    "$zeros" "$((old + 1))" "$zeros" "$old" >"$TMP/stale.sha256"
if supported_only "$TMP/stale.sha256" "$count" "$latest" >/dev/null; then stale=passes; else stale=refused; fi
check "an entry below the window the other files set is refused" same refused "$stale"

finish
