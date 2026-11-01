# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# dependencies.yaml against the Prerequisites section of README.md.
# shellcheck disable=SC2329 # check calls these functions by name

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# file_pairs <yaml>: one sorted "<platform>: <name>" line per platform of
# each entry.
file_pairs() {
    awk '
        /^  - name: / { name = substr($0, 11) }
        /^    platforms: \[.*\]$/ {
            list = $0
            sub(/^[^[]*\[/, "", list)
            sub(/\]$/, "", list)
            n = split(list, platforms, /, /)
            for (i = 1; i <= n; i++) print platforms[i] ": " name
        }
    ' "$1" | LC_ALL=C sort
}

# readme_pairs <readme>: the same lines, from the platform sub-bullets of
# Prerequisites. A sub-bullet may wrap.
readme_pairs() {
    awk '
        function flush(    n, i, names) {
            if (platform == "") return
            gsub(/`/, "", text)
            sub(/\.$/, "", text)
            n = split(text, names, /, /)
            for (i = 1; i <= n; i++) print platform ": " names[i]
            platform = ""
        }
        /^## / { in_section = ($0 == "## Prerequisites"); flush(); next }
        !in_section { next }
        /^    - (macOS|Windows|Linux): / {
            flush()
            text = $0
            sub(/^    - /, "", text)
            platform = tolower(substr(text, 1, index(text, ":") - 1))
            text = substr(text, index(text, ":") + 2)
            next
        }
        platform != "" && /^      / { text = text " " substr($0, 7); next }
        { flush() }
    ' "$1" | LC_ALL=C sort
}

# entries_well_formed <yaml>: 0 where every entry has its four fields, in
# order and with the values they allow, and there is at least one entry.
entries_well_formed() {
    awk '
        /^dependencies:$/ { started = 1; next }
        !started { next }
        state == 0 && /^  - name: [^ ]/ { entries++; state = 1; next }
        state == 1 && /^    platforms: \[(macos|windows|linux)(, (macos|windows|linux))*\]$/ { state = 2; next }
        state == 2 && /^    required: (true|false)$/ { state = 3; next }
        state == 3 && /^    used_for: [^ ]/ { state = 0; next }
        { print "  unexpected line " NR ": " $0; bad = 1 }
        END { exit (bad || state != 0 || entries == 0) }
    ' "$1"
}

# agree <yaml> <readme>: 0 where the two name the same programs per platform
# and name some, otherwise 1 with the two lists printed.
agree() {
    local from_file from_readme
    from_file="$(file_pairs "$1")"
    from_readme="$(readme_pairs "$2")"
    [ -n "$from_file" ] || { echo "  no entry read from $1"; return 1; }
    same "$from_file" "$from_readme"
}

disagree() {
    ! agree "$@" >/dev/null
}

check "every entry of dependencies.yaml has its four fields" \
    entries_well_formed "$REPO/dependencies.yaml"

check "README.md's Prerequisites and dependencies.yaml name the same programs" \
    agree "$REPO/dependencies.yaml" "$REPO/README.md"

# shellcheck disable=SC2016 # the backticks are README.md's own
sed 's/`jq`, //' "$REPO/README.md" >"$TMP/README-short.md"
check "a name dependencies.yaml has and README.md lacks is a disagreement" \
    disagree "$REPO/dependencies.yaml" "$TMP/README-short.md"

sed '/^  - name: jq$/,/^    used_for:/d' "$REPO/dependencies.yaml" >"$TMP/short.yaml"
check "a name README.md has and dependencies.yaml lacks is a disagreement" \
    disagree "$TMP/short.yaml" "$REPO/README.md"

sed 's/^    platforms: \[macos, windows, linux\]$/    platforms: [macos, linux]/' \
    "$REPO/dependencies.yaml" >"$TMP/moved.yaml"
check "a name on another platform is a disagreement" \
    disagree "$TMP/moved.yaml" "$REPO/README.md"

sed 's/^    required: false$/    required: maybe/' "$REPO/dependencies.yaml" >"$TMP/bad.yaml"
if entries_well_formed "$TMP/bad.yaml" >/dev/null; then bad_passes=yes; else bad_passes=no; fi
check "a field with a value it does not allow is refused" same no "$bad_passes"

finish
