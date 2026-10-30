# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# shellcheck disable=SC2329 # check calls these functions by name
# The running-node guard of the macOS and Linux updaters and rollbacks: where
# pgrep is missing or fails, each refuses. tests/win/running-guard.ps1 has the
# Windows half.
#
# Each script runs against an empty folder named by PORTANODE_ROOT, with curl
# and uname replaced by stubs, OSTYPE set to its platform, and a PATH of
# symlinks to /bin and /usr/bin without pgrep. Needs no network.

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/portanode-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

NO_PGREP="$WORK/no-pgrep"
STUBS="$WORK/stubs"
ROOT="$WORK/root"
mkdir -p "$NO_PGREP" "$STUBS" "$ROOT/linux" "$ROOT/macos"
: > "$ROOT/VERSION"
ln -sf /bin/* /usr/bin/* "$NO_PGREP/"
rm -f "$NO_PGREP/pgrep"

# A HEAD request succeeds and any other fails, so no script downloads anything.
cat > "$STUBS/curl" <<'EOF'
#!/bin/sh
for a in "$@"; do [ "$a" = "-fsIL" ] && exit 0; done
exit 22
EOF
cat > "$STUBS/uname" <<'EOF'
#!/bin/sh
echo "$STUB_ARCH"
EOF
chmod +x "$STUBS/curl" "$STUBS/uname"

# pgrep_answering <status>: prints a directory whose pgrep exits <status>.
pgrep_answering() {
    mkdir -p "$WORK/pgrep-$1"
    printf '#!/bin/sh\nexit %s\n' "$1" > "$WORK/pgrep-$1/pgrep"
    chmod +x "$WORK/pgrep-$1/pgrep"
    printf '%s\n' "$WORK/pgrep-$1"
}

# run_script <PATH prefix> <ostype> <arch> <script> [argument...]: the script's
# output, then a last line holding its status.
run_script() {
    local prefix="$1" ostype="$2" arch="$3" script="$4"
    shift 4
    env PATH="$STUBS:$prefix$NO_PGREP" PORTANODE_ROOT="$ROOT" OSTYPE="$ostype" \
        STUB_ARCH="$arch" TMPDIR="$WORK" "$BASH" "$REPO/$script" "$@" 2>&1
    echo "status=$?"
}

# refused <text> <name> <doing>: 0 where the script could not tell, said so and
# exited 1.
refused() {
    contains "$1" "Error: cannot tell whether $2 is running" &&
        contains "$1" "Not $3." && contains "$1" "status=1"
}

# stops_for_a_node <text> <name> <doing>
stops_for_a_node() {
    contains "$1" "Error: $2 is running. Stop it before $3." &&
        contains "$1" "status=1"
}

# passes <text> <past>: 0 where the script went past the guard, which <past>,
# printed after it, shows.
passes() {
    contains "$1" "$2" || return 1
    case "$1" in
        *"is running"* | *"cannot tell"*) return 1 ;;
    esac
}

check "the PATH of these cases holds no pgrep" \
    same "" "$(PATH="$NO_PGREP" command -v pgrep)"

while read -r script ostype arch name doing past; do
    [ -n "$script" ] || continue
    name="${name//_/ }"
    doing="${doing//_/ }"
    past="${past//_/ }"
    args=(--dry-run)
    case "$script" in */update-*) args+=(--version 99.0) ;; esac

    out="$(run_script "" "$ostype" "$arch" "$script" "${args[@]}")"
    check "$script refuses without pgrep" refused "$out" "$name" "$doing"
    for status in 2 3 127; do
        out="$(run_script "$(pgrep_answering "$status"):" "$ostype" "$arch" \
            "$script" "${args[@]}")"
        check "$script refuses where pgrep exits $status" \
            refused "$out" "$name" "$doing"
    done
    out="$(run_script "$(pgrep_answering 0):" "$ostype" "$arch" "$script" "${args[@]}")"
    check "$script stops where pgrep finds a process" \
        stops_for_a_node "$out" "$name" "$doing"
    out="$(run_script "$(pgrep_answering 1):" "$ostype" "$arch" "$script" "${args[@]}")"
    check "$script goes on where pgrep finds no process" passes "$out" "$past"
done <<'EOF'
linux/scripts/utilities/update-bitcoin.sh linux-gnu x86_64 Bitcoin_Core updating --dry-run:
linux/scripts/utilities/update-electrum.sh linux-gnu x86_64 Electrum updating --dry-run:
linux/scripts/utilities/rollback-bitcoin.sh linux-gnu x86_64 Bitcoin_Core rolling_back No_backup_found
linux/scripts/utilities/rollback-electrum.sh linux-gnu x86_64 Electrum rolling_back No_backup_found
macos/scripts/utilities/update-bitcoin.sh darwin24 arm64 Bitcoin_Core updating --dry-run:
macos/scripts/utilities/update-electrum.sh darwin24 arm64 Electrum updating --dry-run:
macos/scripts/utilities/rollback-bitcoin.sh darwin24 arm64 Bitcoin_Core rolling_back No_backup_found
macos/scripts/utilities/rollback-electrum.sh darwin24 arm64 Electrum rolling_back No_backup_found
EOF

# What the refusal protects: a rollback that passes its guard replaces the
# binary, and one without pgrep leaves it.
sha() {
    if command -v shasum > /dev/null; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        sha256sum "$1" | awk '{print $1}'
    fi
}
BIN="$ROOT/linux/bin"
ROLLBACK=linux/scripts/utilities/rollback-bitcoin.sh
prepare_rollback() {
    mkdir -p "$BIN/backup/bitcoin"
    echo installed > "$BIN/bitcoin-qt"
    echo backup > "$BIN/backup/bitcoin/bitcoin-qt"
    echo "$(sha "$BIN/backup/bitcoin/bitcoin-qt")  linux/bin/bitcoin-qt  version=28.1" \
        > "$ROOT/linux/checksums.sha256"
}
prepare_rollback
run_script "" linux-gnu x86_64 "$ROLLBACK" > /dev/null
check "a rollback without pgrep leaves the installed binary" \
    same installed "$(cat "$BIN/bitcoin-qt")"
prepare_rollback
run_script "$(pgrep_answering 1):" linux-gnu x86_64 "$ROLLBACK" > /dev/null
check "a rollback where pgrep finds no process replaces it" \
    same backup "$(cat "$BIN/bitcoin-qt")"

finish
