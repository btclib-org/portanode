# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# The macOS/Linux regtest -cli launchers start an interactive bash on an
# rcfile defining btc. The rcfile must delete itself once bash has read it,
# so a session leaves no portanode-*-cli-rc* file in the temporary directory.

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

ROOT="$TMP/root"
STUBS="$TMP/stubs"
MKTEMP_STUB="$TMP/mktemp-stub"
mkdir -p "$ROOT/linux/bin" "$ROOT/macos/bin" "$ROOT/win" "$ROOT/bitcoin-datadir" \
    "$STUBS" "$MKTEMP_STUB" "$TMP/home"
touch "$ROOT/VERSION"

# bitcoind returns at once, as -daemon does; bitcoin-cli records its arguments.
cat > "$TMP/bitcoin-binary" <<'EOF'
#!/bin/sh
printf '%s %s\n' "${0##*/}" "$*" >> "$PORTANODE_TEST_CALLS"
EOF
chmod +x "$TMP/bitcoin-binary"
for platform in linux macos; do
    cp "$TMP/bitcoin-binary" "$ROOT/$platform/bin/bitcoind"
    cp "$TMP/bitcoin-binary" "$ROOT/$platform/bin/bitcoin-cli"
done

# The clean launchers look for a node on their datadir before wiping it.
cat > "$STUBS/ps" <<'EOF'
#!/bin/sh
printf 'unrelated-process\n'
EOF
chmod +x "$STUBS/ps"

# The .command launchers pass mktemp -t a template with no XXXXXX, which
# macOS's mktemp takes as a prefix and GNU's refuses. Where the mktemp here
# refuses it, the .command launchers get one that adds the suffix.
real_mktemp="$(command -v mktemp)"
if probe="$(TMPDIR="$TMP" mktemp -t portanode-probe 2> /dev/null)"; then
    rm -f -- "$probe"
    MKTEMP_STUB=""
else
    # The stub's own parameters expand when it runs, not here.
    # shellcheck disable=SC2016
    {
        echo '#!/bin/sh'
        echo 'if [ "$1" = -t ]; then'
        echo '    case "$2" in *XXX*) ;; *) set -- -t "$2.XXXXXX" ;; esac'
        echo 'fi'
        printf 'exec "%s" "$@"\n' "$real_mktemp"
    } > "$MKTEMP_STUB/mktemp"
    chmod +x "$MKTEMP_STUB/mktemp"
fi

launchers=(
    linux/scripts/bitcoin/regtest-18444-Alice-cli.sh
    linux/scripts/bitcoin/regtest-18444-Alice-cli-clean.sh
    linux/scripts/bitcoin/regtest-18555-Bob-cli.sh
    linux/scripts/bitcoin/regtest-18555-Bob-cli-clean.sh
    linux/scripts/bitcoin/regtest-18666-Carol-cli.sh
    linux/scripts/bitcoin/regtest-18666-Carol-cli-clean.sh
    macos/scripts/bitcoin/regtest-18444-Alice-cli.command
    macos/scripts/bitcoin/regtest-18444-Alice-cli-clean.command
    macos/scripts/bitcoin/regtest-18555-Bob-cli.command
    macos/scripts/bitcoin/regtest-18555-Bob-cli-clean.command
    macos/scripts/bitcoin/regtest-18666-Carol-cli.command
    macos/scripts/bitcoin/regtest-18666-Carol-cli-clean.command
)

# The session reads its commands from stdin and ends at its EOF. A clean
# launcher reads the line confirming the wipe first.
for launcher in "${launchers[@]}"; do
    name="${launcher##*/}"
    calls="$TMP/$name.calls"
    tmpdir="$TMP/$name.tmp"
    mkdir -p "$tmpdir"
    path="$STUBS:$PATH"
    case "$launcher" in
        *.command) [ -z "$MKTEMP_STUB" ] || path="$MKTEMP_STUB:$path" ;;
    esac
    # RCFILE expands in the session, not here.
    # shellcheck disable=SC2016
    input='btc getblockcount\necho "rcfile=${RCFILE-unset}"\n'
    case "$launcher" in *-clean*) input="\\n$input" ;; esac
    output="$(printf '%b' "$input" | \
        HOME="$TMP/home" \
        TMPDIR="$tmpdir" \
        PORTANODE_ROOT="$ROOT" \
        PORTANODE_TEST_CALLS="$calls" \
        PATH="$path" \
        "$BASH" "$REPO/$launcher" 2>&1)"

    left=none
    for file in "$tmpdir"/portanode-*-cli-rc*; do
        [ -e "$file" ] && left="${file##*/}"
    done
    check "$name leaves no rcfile in the temporary directory" \
        same none "$left"
    check "$name defines btc in the session" \
        contains "$(cat "$calls" 2> /dev/null)" "bitcoin-cli -regtest -datadir=$ROOT/bitcoin-datadir"
    check "$name leaves no RCFILE in the session" \
        contains "$output" "rcfile=unset"
done

finish
