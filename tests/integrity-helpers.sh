# shellcheck shell=bash
# Tests for shared/utilities/lib.sh's integrity helpers: verify_sha256sums,
# tree_hash, and the whole-bundle entries the macOS updaters record and
# their rollbacks and verify-binaries.sh check. Run it with bash, from any
# directory:
#
#   bash tests/integrity-helpers.sh
#
# It prints one PASS, FAIL or SKIP line per case and exits 1 where a case
# fails. No workflow runs it. The rollback cases run the real macOS scripts
# with --dry-run against a scratch folder, and are skipped off macOS. The
# file has no shebang and no executable bit: CLAUDE.md keeps that bit for
# what a user runs.
set -euo pipefail

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=shared/utilities/lib.sh
. "$REPO/shared/utilities/lib.sh"

T="$(mktemp -d "${TMPDIR:-/tmp}/portanode-integrity-test.XXXXXX")"
trap 'chmod -R u+rwX "${T:?}" 2>/dev/null; rm -rf "${T:?}"' EXIT

fails=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; fails=$((fails + 1)); }
skip() { echo "SKIP: $1"; }

# check WANT DESCRIPTION COMMAND... -- WANT is "ok" for exit status 0 and
# "refused" for any other.
check() {
    local want="$1" what="$2" rc=0
    shift 2
    "$@" > "$T/out" 2>&1 || rc=$?
    if { [ "$want" = ok ] && [ "$rc" -eq 0 ]; } ||
       { [ "$want" = refused ] && [ "$rc" -ne 0 ]; }; then
        pass "$what"
    else
        fail "$what (exit $rc)"
        sed 's/^/    /' "$T/out"
    fi
}

sha() { tree_hash "$1"; }

# --- verify_sha256sums --------------------------------------------------

S="$T/sums"
mkdir -p "$S"
printf 'cli' > "$S/b.tar.gz"
printf 'app' > "$S/a.zip"
printf 'other' > "$S/xa.zip"
line() { printf '%s  %s\n' "$(sha "$S/$1")" "$2"; }

{ line a.zip a.zip; line b.tar.gz b.tar.gz; } > "$S/both"
check ok "verify_sha256sums passes two names each listed once" \
    verify_sha256sums "$S" both a.zip b.tar.gz

line b.tar.gz b.tar.gz > "$S/one"
check refused "verify_sha256sums refuses a name SHA256SUMS does not list" \
    verify_sha256sums "$S" one a.zip b.tar.gz

{ line xa.zip xa.zip; line b.tar.gz b.tar.gz; } > "$S/substring"
check refused "verify_sha256sums refuses a name listed only inside another" \
    verify_sha256sums "$S" substring a.zip b.tar.gz

{ line a.zip a.zip; line a.zip a.zip; line b.tar.gz b.tar.gz; } > "$S/twice"
check refused "verify_sha256sums refuses a name listed twice" \
    verify_sha256sums "$S" twice a.zip b.tar.gz

{ line xa.zip a.zip; line b.tar.gz b.tar.gz; } > "$S/wrong"
check refused "verify_sha256sums refuses a listed name whose hash differs" \
    verify_sha256sums "$S" wrong a.zip b.tar.gz

printf '%s *%s\n' "$(sha "$S/a.zip")" a.zip > "$S/binary"
check ok "verify_sha256sums reads the binary-mode '*' separator" \
    verify_sha256sums "$S" binary a.zip

# --- tree_hash ----------------------------------------------------------

# make_bundle DIR: a small .app-shaped tree with a symlink, as Electrum.app
# holds them in Contents/MacOS.
make_bundle() {
    mkdir -p "$1/Contents/MacOS" "$1/Contents/Resources"
    printf 'exe' > "$1/Contents/MacOS/run_electrum"
    printf 'code' > "$1/Contents/Resources/lib.py"
    printf 'more' > "$1/Contents/Resources/other.py"
    ln -s ../Resources/lib.py "$1/Contents/MacOS/lib.py"
}

differs() { [ "$1" != "$2" ]; }
same() { [ "$1" = "$2" ]; }

B="$T/tree/X.app"
make_bundle "$B"
h0="$(sha "$B")"

ln -sfn ../Resources/other.py "$B/Contents/MacOS/lib.py"
check ok "tree_hash changes when a symlink's target changes" \
    differs "$h0" "$(sha "$B")"

rm "$B/Contents/MacOS/lib.py"
check ok "tree_hash changes when a symlink goes missing" \
    differs "$h0" "$(sha "$B")"

ln -s ../Resources/lib.py "$B/Contents/MacOS/lib.py"
check ok "tree_hash is back where it was once the symlink is" \
    same "$h0" "$(sha "$B")"

# Two trees whose names and targets would read alike joined by " -> ":
# link "a" to "b -> c", and link "a -> b" to "c".
mkdir -p "$T/c1" "$T/c2"
ln -s 'b -> c' "$T/c1/a"
ln -s c "$T/c2/a -> b"
check ok "tree_hash tells a link's name from its target" \
    differs "$(sha "$T/c1")" "$(sha "$T/c2")"

mkdir -p "$T/n1" "$T/n2"
ln -s x "$T/n1/l"
ln -s "x"$'\n' "$T/n2/l"
check ok "tree_hash tells a target from the same target ending in a newline" \
    differs "$(sha "$T/n1")" "$(sha "$T/n2")"

printf 'sidecar' > "$B/Contents/._lib.py"
check ok "tree_hash ignores an AppleDouble sidecar" \
    same "$h0" "$(sha "$B")"

printf 'changed' > "$B/Contents/Resources/lib.py"
check ok "tree_hash changes when a file's content changes" \
    differs "$h0" "$(sha "$B")"

if [ "$(id -u)" -eq 0 ]; then
    skip "tree_hash refuses an unreadable file (root reads it anyway)"
else
    chmod 000 "$B/Contents/Resources/other.py"
    unreadable() { local h rc=0; h="$(tree_hash "$1")" || rc=$?; \
        [ "$rc" -ne 0 ] && [ -z "$h" ]; }
    check ok "tree_hash prints nothing and fails on an unreadable file" \
        unreadable "$B"
    # Under the updaters' set -euo pipefail, with each bash at hand (macOS's
    # /bin/bash is 3.2): the refusal leaves no temporary directory, and
    # stderr holds shasum's or sha256sum's refusal and nothing else.
    cleans_up() {
        local sh="$1" td out rc=0
        td="$(mktemp -d "$T/tmpdir.XXXXXX")"
        # shellcheck disable=SC2016 # $1 and $2 are the child shell's own
        # arguments, so the script is single-quoted on purpose
        out="$(TMPDIR="$td" "$sh" -c \
            'set -euo pipefail; . "$1"; tree_hash "$2"' _ \
            "$REPO/shared/utilities/lib.sh" "$B" 2>&1)" || rc=$?
        [ "$rc" -ne 0 ] && [ -z "$(ls -A "$td")" ] &&
            ! printf '%s\n' "$out" | grep -qv 'Permission denied'
    }
    for sh in $(printf '%s\n' "$BASH" /bin/bash | sort -u); do
        [ -x "$sh" ] || continue
        check ok "a failed tree_hash leaves no temporary directory ($sh)" \
            cleans_up "$sh"
    done
    chmod 644 "$B/Contents/Resources/other.py"
fi

# --- whole-bundle entries -----------------------------------------------

ROOTDIR="$T/root"
mkdir -p "$ROOTDIR/macos/bin"
echo 0.0.0 > "$ROOTDIR/VERSION"
: > "$ROOTDIR/macos/checksums.sha256"
APP="$ROOTDIR/macos/bin/Electrum.app"
make_bundle "$APP"
update_checksum "$APP" "macos/bin/Electrum.app" "1.0" > "$T/out"

check ok "verify_checksum_entry accepts the bundle it recorded" \
    verify_checksum_entry "$APP" "macos/bin/Electrum.app" \
    "$ROOTDIR/macos/checksums.sha256"
check ok "verify-binaries.sh accepts the bundle it recorded" \
    env PORTANODE_ROOT="$ROOTDIR" \
    bash "$REPO/macos/scripts/utilities/verify-binaries.sh"

printf 'tampered' > "$APP/Contents/Resources/lib.py"
check refused "verify_checksum_entry refuses a change outside Contents/MacOS" \
    verify_checksum_entry "$APP" "macos/bin/Electrum.app" \
    "$ROOTDIR/macos/checksums.sha256"
check refused "verify-binaries.sh refuses a change outside Contents/MacOS" \
    env PORTANODE_ROOT="$ROOTDIR" \
    bash "$REPO/macos/scripts/utilities/verify-binaries.sh"

# --- the macOS rollbacks ------------------------------------------------

# rollback NAME APP WANT DESCRIPTION: runs rollback-NAME.sh --dry-run
# against a scratch folder whose backup slot holds APP, after recording
# APP's entry and then changing a file outside Contents/MacOS where WANT is
# "refused". The script refuses while its program runs on this machine,
# which is a SKIP rather than a result.
rollback() {
    local name="$1" app="$2" want="$3" what="$4" root rc=0
    root="$T/rollback-$name-$want"
    mkdir -p "$root/macos/bin/backup/$name"
    echo 0.0.0 > "$root/VERSION"
    : > "$root/macos/checksums.sha256"
    make_bundle "$root/macos/bin/backup/$name/$app"
    ROOTDIR="$root" update_checksum "$root/macos/bin/backup/$name/$app" \
        "macos/bin/$app" "1.0" "$root/macos/checksums.sha256" > "$T/out"
    if [ "$want" = refused ]; then
        printf 'tampered' \
            > "$root/macos/bin/backup/$name/$app/Contents/Resources/lib.py"
    fi
    PORTANODE_ROOT="$root" \
        bash "$REPO/macos/scripts/utilities/rollback-$name.sh" --dry-run \
        > "$T/out" 2>&1 || rc=$?
    if grep -q 'is running\. Stop it' "$T/out"; then
        skip "$what ($name is running here)"
    elif [ "$want" = ok ] && [ "$rc" -eq 0 ] &&
         grep -q 'checksum recognized' "$T/out"; then
        pass "$what"
    elif [ "$want" = refused ] && [ "$rc" -ne 0 ] &&
         grep -q 'checksum is not recognized' "$T/out"; then
        pass "$what"
    else
        fail "$what (exit $rc)"
        sed 's/^/    /' "$T/out"
    fi
}

if [[ "$OSTYPE" == darwin* ]]; then
    rollback electrum Electrum.app ok \
        "rollback-electrum.sh accepts a backup bundle it recorded"
    rollback electrum Electrum.app refused \
        "rollback-electrum.sh refuses a change outside Contents/MacOS"
    rollback bitcoin Bitcoin-Qt.app ok \
        "rollback-bitcoin.sh accepts a backup bundle it recorded"
    rollback bitcoin Bitcoin-Qt.app refused \
        "rollback-bitcoin.sh refuses a change outside Contents/MacOS"
else
    skip "the macOS rollbacks (they run on macOS only)"
fi

if [ "$fails" -ne 0 ]; then
    echo "$fails case(s) failed."
    exit 1
fi
echo "All cases passed."
