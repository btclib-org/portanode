# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# Each */checksums.sha256 against README.md's Version Compatibility: the
# Bitcoin Core entries are those of the supported majors only.
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

# core_majors <checksums>: the majors of the Bitcoin Core entries, one per
# line, sorted. It reads an entry as loosely as the verifiers do:
# shared/utilities/lib.sh's verify_binaries takes any 64-character first
# field, and win/scripts/utilities/verify-binaries.ps1 a hash in either
# case and a path with backslashes, compared lowercased. A Core entry is
# one whose path, so read, is under bin/ and starts bitcoin.
core_majors() {
    awk '
        length($1) == 64 {
            p = tolower($2)
            gsub(/\\/, "/", p)
            if (p !~ /\/bin\/bitcoin/ || index($0, "version=") == 0) next
            v = $0
            sub(/.*version=/, "", v)
            split(v, part, ".")
            if (part[1] ~ /^[0-9]+$/) print part[1]
        }
    ' "$1" | LC_ALL=C sort -n -u
}

# supported_only <checksums> <count>: 0 where every Core major lies within
# <count> of the highest one, otherwise 1 with the majors printed.
supported_only() {
    local majors highest m
    majors="$(core_majors "$1")"
    [ -n "$majors" ] || return 0
    highest="$(printf '%s\n' "$majors" | tail -n 1)"
    for m in $majors; do
        if [ "$m" -le "$((highest - $2))" ]; then
            echo "  majors in ${1#"$REPO"/}: $(printf '%s\n' "$majors" | paste -sd " " -)"
            return 1
        fi
    done
    return 0
}

count="$(supported_count "$REPO/README.md")"
check "README.md's Version Compatibility says how many Core majors are supported" \
    [ -n "$count" ]
: "${count:=0}"

for f in "$REPO"/*/checksums.sha256; do
    check "${f#"$REPO"/} holds Core entries of the supported majors only" \
        supported_only "$f" "$count"
done

check "macos/checksums.sha256 holds Core entries the case reads" \
    [ -n "$(core_majors "$REPO/macos/checksums.sha256")" ]

cp "$REPO/win/checksums.sha256" "$TMP/planted.sha256"
printf '%s  win/bin/bitcoind.exe  version=%s.2\n' \
    "$(printf '0%.0s' $(seq 64))" "$(($(core_majors "$TMP/planted.sha256" | tail -n 1) - count))" \
    >>"$TMP/planted.sha256"
if supported_only "$TMP/planted.sha256" "$count" >/dev/null; then planted=passes; else planted=refused; fi
check "an entry of a major below the supported ones is refused" same refused "$planted"

cp "$REPO/win/checksums.sha256" "$TMP/upper.sha256"
printf '%s  win\\bin\\bitcoind.exe  version=%s.2\n' \
    "$(printf 'A%.0s' $(seq 64))" "$(($(core_majors "$TMP/upper.sha256" | tail -n 1) - count))" \
    >>"$TMP/upper.sha256"
if supported_only "$TMP/upper.sha256" "$count" >/dev/null; then upper=passes; else upper=refused; fi
check "such an entry with an uppercase hash and a backslash path is refused" same refused "$upper"

finish
