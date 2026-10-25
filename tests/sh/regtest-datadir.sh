# shellcheck shell=bash
# The Bob and Carol macOS/Linux regtest launchers must stop when their
# datadir cannot be created, before any Bitcoin Core binary is started.

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
mkdir -p "$ROOT/linux/bin" "$ROOT/macos/bin/Bitcoin-Qt.app/Contents/MacOS" "$ROOT/win" "$STUBS"
touch "$ROOT/VERSION"
: > "$ROOT/bitcoin-datadir"

cat > "$TMP/bitcoin-binary" <<'EOF'
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

# Clean launchers delete their datadir before recreating it. Keep the blocker
# in place while letting that earlier step pass, so the test reaches mkdir.
cat > "$STUBS/rm" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$STUBS/ps" <<'EOF'
#!/bin/sh
printf 'unrelated-process\n'
EOF
cat > "$STUBS/grep" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$STUBS/rm" "$STUBS/ps" "$STUBS/grep"

launchers=(
    linux/scripts/bitcoin/regtest-18555-Bob-cli.sh
    linux/scripts/bitcoin/regtest-18555-Bob-qt.sh
    linux/scripts/bitcoin/regtest-18555-Bob-cli-clean.sh
    linux/scripts/bitcoin/regtest-18555-Bob-qt-clean.sh
    linux/scripts/bitcoin/regtest-18666-Carol-cli.sh
    linux/scripts/bitcoin/regtest-18666-Carol-qt.sh
    linux/scripts/bitcoin/regtest-18666-Carol-cli-clean.sh
    linux/scripts/bitcoin/regtest-18666-Carol-qt-clean.sh
    macos/scripts/bitcoin/regtest-18555-Bob-cli.command
    macos/scripts/bitcoin/regtest-18555-Bob-qt.command
    macos/scripts/bitcoin/regtest-18555-Bob-cli-clean.command
    macos/scripts/bitcoin/regtest-18555-Bob-qt-clean.command
    macos/scripts/bitcoin/regtest-18666-Carol-cli.command
    macos/scripts/bitcoin/regtest-18666-Carol-qt.command
    macos/scripts/bitcoin/regtest-18666-Carol-cli-clean.command
    macos/scripts/bitcoin/regtest-18666-Carol-qt-clean.command
)

run_launcher() {
    local input="$1" launcher="$2" started="$3" path="$PATH" output status
    case "$launcher" in *-clean*) path="$STUBS:$PATH" ;; esac
    output="$(printf '%b' "$input" | \
        PORTANODE_ROOT="$ROOT" \
        PORTANODE_TEST_STARTS="$started" \
        PATH="$path" \
        "$BASH" "$REPO/$launcher" 2>&1)"
    status=$?
    printf '%s\nexit %s\n' "$output" "$status"
}

for launcher in "${launchers[@]}"; do
    name="${launcher##*/}"
    started="$TMP/$name.started"
    case "$launcher" in
        *Bob*) datadir=bitcoin-datadir/regtest_bob ;;
        *Carol*) datadir=bitcoin-datadir/regtest_carol ;;
    esac
    case "$launcher" in *-clean*) input='\n' ;; *) input='' ;; esac
    output="$(run_launcher "$input" "$launcher" "$started")"

    check "$name reports a datadir creation error" \
        contains "$output" "Error: could not create $datadir"
    check "$name exits 1 when the datadir cannot be created" \
        same "exit 1" "$(tail -n 1 <<<"$output")"
    if [ -e "$started" ]; then
        check "$name does not start Bitcoin Core after the creation error" \
            same absent present
    else
        check "$name does not start Bitcoin Core after the creation error" \
            same absent absent
    fi
done

finish
