# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# The macOS/Linux Electrum launchers must stop when electrum-datadir cannot
# be created, before Electrum is started.

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
MACOS_APP="$ROOT/macos/bin/Electrum.app"
mkdir -p "$ROOT/linux/bin" "$MACOS_APP/Contents/MacOS" "$ROOT/win" "$STUBS"
touch "$ROOT/VERSION"
: > "$ROOT/electrum-datadir"

cat > "$TMP/electrum-binary" <<'EOF'
#!/bin/sh
printf '%s\n' "$0" >> "$PORTANODE_TEST_STARTS"
EOF
chmod +x "$TMP/electrum-binary"
cp "$TMP/electrum-binary" "$ROOT/linux/bin/electrum.AppImage"
cp "$TMP/electrum-binary" "$MACOS_APP/Contents/MacOS/run_electrum"
# The macOS launchers start Electrum through open(1), which Linux lacks or
# which is another program there.
cp "$TMP/electrum-binary" "$STUBS/open"

launchers=(
    linux/scripts/electrum/mainnet.sh
    linux/scripts/electrum/mainnet-local-server-only.sh
    linux/scripts/electrum/regtest.sh
    linux/scripts/electrum/testnet3.sh
    linux/scripts/electrum/testnet4.sh
    macos/scripts/electrum/mainnet.command
    macos/scripts/electrum/mainnet-local-server-only.command
    macos/scripts/electrum/regtest.command
    macos/scripts/electrum/testnet3.command
    macos/scripts/electrum/testnet4.command
)

run_launcher() {
    local launcher="$1" started="$2" output status
    output="$(PORTANODE_ROOT="$ROOT" \
        PORTANODE_TEST_STARTS="$started" \
        PATH="$STUBS:$PATH" \
        "$BASH" "$REPO/$launcher" < /dev/null 2>&1)"
    status=$?
    printf '%s\nexit %s\n' "$output" "$status"
}

for launcher in "${launchers[@]}"; do
    name="${launcher#*/scripts/}"
    # The Linux launchers stop at their /dev/fuse check before mkdir.
    case "$launcher" in
        linux/*)
            if [ ! -r /dev/fuse ] || [ ! -w /dev/fuse ]; then
                echo "ok - skipped: $name needs read and write access to /dev/fuse"
                continue
            fi
            ;;
    esac
    started="$TMP/${name//\//-}.started"
    output="$(run_launcher "$launcher" "$started")"

    check "$name reports a datadir creation error" \
        contains "$output" "Error: could not create electrum-datadir"
    check "$name exits 1 when electrum-datadir cannot be created" \
        same "exit 1" "$(tail -n 1 <<<"$output")"
    if [ -e "$started" ]; then
        check "$name does not start Electrum after the creation error" \
            same absent present
    else
        check "$name does not start Electrum after the creation error" \
            same absent absent
    fi
done

finish
