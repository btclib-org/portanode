# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# The macOS/Linux regtest clean launchers must delete their datadir only
# after a whole line is read at the Enter prompt: where input ends there,
# with nothing or with a partial line, they exit 1 and delete nothing.

case "$0" in */*) ;; *) [ -f "$0" ] || {
    echo "$0: run this script by its path, not by a name found through PATH" >&2
    exit 1
} ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

TMP="$(mktemp -d)" || exit 1
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

ROOT="$TMP/root"
STUBS="$TMP/stubs"
mkdir -p "$ROOT/linux/bin" "$ROOT/macos/bin/Bitcoin-Qt.app/Contents/MacOS" "$ROOT/win" "$STUBS"
touch "$ROOT/VERSION"

cat > "$TMP/bitcoin-binary" << 'EOF'
#!/bin/sh
printf '%s\n' "$0" >> "$PORTANODE_TEST_STARTS"
EOF
chmod +x "$TMP/bitcoin-binary"
for platform in linux macos; do
    cp "$TMP/bitcoin-binary" "$ROOT/$platform/bin/bitcoind"
    cp "$TMP/bitcoin-binary" "$ROOT/$platform/bin/bitcoin-cli"
done
cp "$TMP/bitcoin-binary" "$ROOT/linux/bin/bitcoin-qt"
cp "$TMP/bitcoin-binary" "$ROOT/macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"

# A process list with no node in it, so the running-node guards let the
# launcher reach the prompt whatever runs on the machine.
cat > "$STUBS/ps" << 'EOF'
#!/bin/sh
printf 'unrelated-process\n'
EOF
chmod +x "$STUBS/ps"

launchers=(
    linux/scripts/bitcoin/regtest-18444-Alice-cli-clean.sh
    linux/scripts/bitcoin/regtest-18444-Alice-qt-clean.sh
    linux/scripts/bitcoin/regtest-18555-Bob-cli-clean.sh
    linux/scripts/bitcoin/regtest-18555-Bob-qt-clean.sh
    linux/scripts/bitcoin/regtest-18666-Carol-cli-clean.sh
    linux/scripts/bitcoin/regtest-18666-Carol-qt-clean.sh
    macos/scripts/bitcoin/regtest-18444-Alice-cli-clean.command
    macos/scripts/bitcoin/regtest-18444-Alice-qt-clean.command
    macos/scripts/bitcoin/regtest-18555-Bob-cli-clean.command
    macos/scripts/bitcoin/regtest-18555-Bob-qt-clean.command
    macos/scripts/bitcoin/regtest-18666-Carol-cli-clean.command
    macos/scripts/bitcoin/regtest-18666-Carol-qt-clean.command
)

# run_launcher <input> <launcher> <started>: runs <launcher> with <input>,
# written without a newline, as all of its stdin; stdin is /dev/null where
# <input> is empty. Prints its output and then "exit <status>".
run_launcher() {
    local input="$1" launcher="$2" started="$3" output status
    if [ -z "$input" ]; then
        output="$(PORTANODE_ROOT="$ROOT" \
            PORTANODE_TEST_STARTS="$started" \
            PATH="$STUBS:$PATH" \
            "$BASH" "$REPO/$launcher" 2>&1 < /dev/null)"
        status=$?
    else
        output="$(printf '%s' "$input" \
            | PORTANODE_ROOT="$ROOT" \
                PORTANODE_TEST_STARTS="$started" \
                PATH="$STUBS:$PATH" \
                "$BASH" "$REPO/$launcher" 2>&1)"
        status=$?
    fi
    printf '%s\nexit %s\n' "$output" "$status"
}

for launcher in "${launchers[@]}"; do
    name="${launcher##*/}"
    case "$launcher" in
        *Alice*) datadir="$ROOT/bitcoin-datadir/regtest" ;;
        *Bob*) datadir="$ROOT/bitcoin-datadir/regtest_bob" ;;
        *Carol*) datadir="$ROOT/bitcoin-datadir/regtest_carol" ;;
        *) ;;
    esac
    for input in '' y; do
        case "$input" in
            '') what="stdin closed" ;;
            *) what="a partial line" ;;
        esac
        started="$TMP/$name.started"
        rm -f "$started"
        mkdir -p "$datadir"
        : > "$datadir/keep"
        output="$(run_launcher "$input" "$launcher" "$started")"

        check "$name reaches the prompt with $what" \
            contains "$output" "Press Enter to continue or Ctrl+C to cancel."
        check "$name says nothing was deleted with $what" \
            contains "$output" "Nothing has been deleted."
        check "$name exits 1 with $what" \
            same "exit 1" "$(tail -n 1 <<< "$output")"
        if [ -e "$datadir/keep" ]; then
            check "$name keeps its datadir with $what" same present present
        else
            check "$name keeps its datadir with $what" same present absent
        fi
        if [ -e "$started" ]; then
            check "$name does not start Bitcoin Core with $what" \
                same absent present
        else
            check "$name does not start Bitcoin Core with $what" \
                same absent absent
        fi
    done
done

finish
