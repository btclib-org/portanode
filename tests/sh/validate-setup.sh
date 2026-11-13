# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# shellcheck disable=SC2329 # check calls these functions by name
# What the macOS and Linux validate-setup report, through verify-binaries.sh
# beside them or its absence, by the checksums, the data directories, the free
# space and bitcoin.conf's prune=. Each runs from the checkout, or through
# links to it, against a folder of its own named by PORTANODE_ROOT, with a
# PATH of links to /bin and /usr/bin in which df is a stand-in answering the
# free space DF_KB gives.

case "$0" in */*) ;; *) [ -f "$0" ] || {
    echo "$0: run this script by its path, not by a name found through PATH" >&2
    exit 1
} ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"
# shellcheck source=shared/utilities/lib.sh
. "$REPO/shared/utilities/lib.sh"

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

ROOT="$TMP/root"
BASE="$TMP/base"
STANDINS="$TMP/stand-ins"
mkdir -p "$BASE" "$STANDINS"
ln -sf /bin/* /usr/bin/* "$BASE/"
rm -f "$BASE/df"

# df -Pk <root> answers DF_KB kilobytes free, and df -h <root> "DF_KB K". It
# records any other call in UNEXPECTED and exits 2, and validate then prints
# the refusal alone.
# shellcheck disable=SC2016 # the stand-in expands it
printf '%s\n' '#!/bin/sh' \
    'case "$#:$1 $2" in' \
    '    "2:-Pk $PORTANODE_ROOT") free="$DF_KB" ;;' \
    '    "2:-h $PORTANODE_ROOT") free="${DF_KB}K" ;;' \
    '    *) echo "df $*" >> "$UNEXPECTED" && exit 2 ;;' \
    'esac' \
    'echo "Filesystem 1024-blocks Used Available Capacity Mounted on"' \
    'echo "/dev/disk9 1 1 $free 1% /Volumes/PortaNode"' > "$STANDINS/df"
chmod +x "$STANDINS/df"

GB=$((1024 * 1024))

# fresh <platform>: a folder with both data directories, an empty checksum
# file for <platform>, and 800 GB free.
fresh() {
    rm -rf "$ROOT"
    mkdir -p "$ROOT/linux" "$ROOT/macos" "$ROOT/bitcoin-datadir" \
        "$ROOT/electrum-datadir"
    touch "$ROOT/VERSION"
    : > "$ROOT/$1/checksums.sha256"
    DF_KB=$((800 * GB))
}

# validate <platform> [<tree>]: runs that platform's validate-setup from
# <tree>, this checkout where none is given, stdout and stderr together, then
# "exit <status>", or what df refused alone.
validate() {
    local status=0 out
    rm -f "$TMP/unexpected"
    out="$(env PATH="$STANDINS:$BASE" PORTANODE_ROOT="$ROOT" DF_KB="$DF_KB" \
        UNEXPECTED="$TMP/unexpected" \
        "$BASH" "${2:-$REPO}/$1/scripts/utilities/validate-setup.sh" 2>&1)" \
        || status=$?
    if [ -f "$TMP/unexpected" ]; then
        echo "df refused: $(cat "$TMP/unexpected")"
        return
    fi
    printf '%s\nexit %s\n' "$out" "$status"
}

for platform in linux macos; do
    clean() {
        fresh "$platform"
        same "Validating setup at $ROOT
Verifying binaries against $platform/checksums.sha256
Nothing to verify: no $platform/* entries in $platform/checksums.sha256.
OK: Data directories exist
Disk free space: ${DF_KB}K
Setup validation completed.
exit 0" "$(validate "$platform")"
    }
    check "$platform: a fresh folder with 800 GB free validates" clean

    verified() {
        fresh "$platform"
        mkdir -p "$ROOT/$platform/bin"
        echo binary > "$ROOT/$platform/bin/bitcoind"
        printf '%s  %s  version=28.0\n' \
            "$(tree_hash "$ROOT/$platform/bin/bitcoind")" \
            "$platform/bin/bitcoind" > "$ROOT/$platform/checksums.sha256"
        local out
        out="$(validate "$platform")"
        contains "$out" "$platform/bin/bitcoind: OK (version: 28.0)"$'\n''Binaries verified.' \
            && contains "$out" 'exit 0'
    }
    check "$platform: a binary its checksum names verifies" verified

    mismatch() {
        fresh "$platform"
        mkdir -p "$ROOT/$platform/bin"
        echo changed > "$ROOT/$platform/bin/bitcoind"
        printf '%064d  %s  version=28.0\n' 0 "$platform/bin/bitcoind" \
            > "$ROOT/$platform/checksums.sha256"
        same "Validating setup at $ROOT
Verifying binaries against $platform/checksums.sha256
$platform/bin/bitcoind: FAILED (expected versions: 28.0)
Verification failed: 1 file(s).
exit 1" "$(validate "$platform")"
    }
    check "$platform: a binary that differs from its checksum stops the validation" \
        mismatch

    fresh "$platform"
    rm "$ROOT/$platform/checksums.sha256"
    check "$platform: without its checksum file the validation stops" same \
        "Validating setup at $ROOT
Verifying binaries against $platform/checksums.sha256
Error: $platform/checksums.sha256 not found.
exit 1" "$(validate "$platform")"

    # A tree of links to this checkout's validate-setup.sh and the libraries
    # it sources, with no verify-binaries.sh.
    tree="$TMP/no-verify-$platform"
    mkdir -p "$tree/$platform/scripts/utilities"
    ln -s "$REPO/shared" "$tree/shared"
    ln -s "$REPO/$platform/scripts/lib.sh" "$tree/$platform/scripts/lib.sh"
    ln -s "$REPO/$platform/scripts/utilities/validate-setup.sh" \
        "$tree/$platform/scripts/utilities/validate-setup.sh"
    fresh "$platform"
    check "$platform: without verify-binaries.sh beside it, the checksums are skipped with a warning" \
        same "Validating setup at $ROOT
WARNING: verify-binaries.sh not found, skipping checksum check
OK: Data directories exist
Disk free space: ${DF_KB}K
Setup validation completed.
exit 0" "$(validate "$platform" "$tree")"

    fresh "$platform"
    rm -r "$ROOT/electrum-datadir"
    check "$platform: a missing data directory is a warning" \
        contains "$(validate "$platform")" \
        'WARNING: Data directories not found'$'\n''Disk free space: '

    fresh "$platform"
    DF_KB=$((100 * GB - 1))
    check "$platform: under 100 GB free is an error" \
        contains "$(validate "$platform")" \
        'ERROR: Less than 100GB free.'$'\n''exit 1'

    # 100 GB is enough for a pruned node, and a node without prune= is
    # warned that a mainnet sync needs 700 GB.
    WARNING='WARNING: Less than 700GB free, and bitcoin-datadir/bitcoin.conf has no active prune=. An unpruned mainnet full sync needs 700GB; enable pruning, or use testnet/regtest, if this is not one.'
    fresh "$platform"
    DF_KB=$((100 * GB))
    check "$platform: 100 GB free without bitcoin.conf is warned about 700 GB" \
        contains "$(validate "$platform")" \
        "$WARNING"$'\n''Setup validation completed.'$'\n''exit 0'

    fresh "$platform"
    DF_KB=$((700 * GB - 1))
    printf 'server=1\n#prune=550\nprune=0\n' > "$ROOT/bitcoin-datadir/bitcoin.conf"
    check "$platform: prune=0 and a commented prune= are not pruning" \
        contains "$(validate "$platform")" "$WARNING"

    for conf in 'prune=550' '  prune = 1' 'prune=1'; do
        pruned() {
            fresh "$platform"
            DF_KB=$((300 * GB))
            printf '%s\n' "$conf" > "$ROOT/bitcoin-datadir/bitcoin.conf"
            local out
            out="$(validate "$platform")"
            contains "$out" 'Setup validation completed.'$'\n''exit 0' \
                && case "$out" in
                    *WARNING*)
                        printf '  a warning in: %s\n' "$out"
                        return 1
                        ;;
                    *) ;;
                esac
        }
        check "$platform: \"$conf\" with 300 GB free is not warned" pruned
    done

    fresh "$platform"
    DF_KB=$((700 * GB))
    check "$platform: 700 GB free without prune= is not warned" \
        same "Validating setup at $ROOT
Verifying binaries against $platform/checksums.sha256
Nothing to verify: no $platform/* entries in $platform/checksums.sha256.
OK: Data directories exist
Disk free space: ${DF_KB}K
Setup validation completed.
exit 0" "$(validate "$platform")"
done

finish
