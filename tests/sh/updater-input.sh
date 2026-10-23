# shellcheck shell=bash
# shellcheck disable=SC2329 # the cases are functions that check calls by name
# shellcheck disable=SC2016 # the stubs are written with their $ unexpanded
# What the updaters download and what they are told, fed to them malformed:
# SHA256SUMS, gpg's status output and a version string. Each is refused and
# nothing is installed. It stands in for a fuzzer (ISS 646): the updaters are
# shell, which none that OpenSSF Scorecard recognises runs.
#
# The updaters run in a copy of the tree with curl, pgrep, uname and hdiutil
# replaced by stubs on PATH. curl serves files from a directory, and the
# signatures are real: gpg signs with a key made for the run, whose
# fingerprint is the only one the copy's keys/*.fingerprints pin.
# win/scripts/utilities holds the Windows halves, tested in
# tests/win/updater-input.ps1.

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"

if ! command -v gpg > /dev/null; then
    echo "ok - skipped: gpg not found"
    exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/portanode-input.XXXXXX")"
WORK="$(cd "$WORK" && pwd -P)"
# gpg-agent's socket path is bounded, so the homes are short.
HOME_A="$(mktemp -d "${TMPDIR:-/tmp}/key-a.XXXXXX")"
HOME_B="$(mktemp -d "${TMPDIR:-/tmp}/key-b.XXXXXX")"
HOME_C="$(mktemp -d "${TMPDIR:-/tmp}/key-c.XXXXXX")"
cleanup() {
    gpgconf --homedir "$HOME_A" --kill gpg-agent > /dev/null 2>&1
    gpgconf --homedir "$HOME_B" --kill gpg-agent > /dev/null 2>&1
    gpgconf --homedir "$HOME_C" --kill gpg-agent > /dev/null 2>&1
    rm -rf "$WORK" "$HOME_A" "$HOME_B" "$HOME_C"
}
trap cleanup EXIT

unset PORTANODE_ROOT

# --- keys: A is pinned; B signs as an outsider ----------------------------
for h in "$HOME_A" "$HOME_B" "$HOME_C"; do
    chmod 700 "$h"
    gpg --homedir "$h" --batch --passphrase '' --quick-gen-key \
      "portanode test <t@example.invalid>" ed25519 sign never > /dev/null 2>&1
done
fpr_of() {
    gpg --homedir "$1" --with-colons --list-keys 2> /dev/null \
      | awk -F: '$1 == "fpr" { print $10; exit }'
}
FPR_A="$(fpr_of "$HOME_A")"
FPR_B="$(fpr_of "$HOME_B")"
FPR_C="$(fpr_of "$HOME_C")"
if [ "${#FPR_A}" -ne 40 ] || [ "${#FPR_B}" -ne 40 ] || [ "${#FPR_C}" -ne 40 ]; then
    echo "not ok - gpg made no test key"
    exit 1
fi
# B's public key, for the cases where an unpinned key is in the keyring.
gpg --homedir "$HOME_B" --export 2> /dev/null \
  | gpg --homedir "$HOME_A" --batch --import > /dev/null 2>&1
sign() { # sign FILE HOMEDIR [KEY...]: writes FILE.asc
    local file="$1" home="$2" key args=()
    shift 2
    for key in "$@"; do args+=(--local-user "$key"); done
    rm -f "$file.asc"
    gpg --homedir "$home" --batch --yes --armor --detach-sign \
      ${args[@]+"${args[@]}"} --output "$file.asc" "$file" > /dev/null 2>&1
}

# --- the copy of the tree, made fresh for every case ----------------------
TREE="$WORK/tree"
git -C "$REPO" ls-files -z | tar -C "$REPO" --null -T - -cf "$WORK/tree.tar" 2> /dev/null
fresh_tree() {
    rm -rf "$TREE"
    mkdir -p "$TREE"
    tar -C "$TREE" -xf "$WORK/tree.tar"
    printf '%s\nmin-signatures=1\n' "$FPR_A" > "$TREE/keys/bitcoin-core.fingerprints"
    printf '%s\n' "$FPR_A" > "$TREE/keys/electrum.fingerprints"
}

STUBS="$WORK/stubs"
SERVE="$WORK/serve"
mkdir -p "$STUBS"
# curl serves $SERVE/<last path component of the URL>, the index of a
# publisher from index-bitcoin or index-electrum, answers any HEAD with
# success, and logs its arguments.
cat > "$STUBS/curl" <<'EOF'
#!/bin/bash
echo "$*" >> "$CURL_LOG"
out=""
prev=""
for a in "$@"; do
    [ "$prev" = "-o" ] && out="$a"
    prev="$a"
    url="$a"
    [ "$a" = "-fsIL" ] && exit 0
done
case "$url" in
    https://bitcoincore.org/bin/) src="$SERVE/index-bitcoin" ;;
    https://download.electrum.org/) src="$SERVE/index-electrum" ;;
    *) src="$SERVE/${url##*/}" ;;
esac
[ -f "$src" ] || exit 22
if [ -n "$out" ]; then cp "$src" "$out"; else cat "$src"; fi
EOF
printf '#!/bin/sh\nexit 1\n' > "$STUBS/pgrep"
printf '#!/bin/sh\necho "$STUB_ARCH"\n' > "$STUBS/uname"
printf '#!/bin/sh\necho "$*" >> "$CURL_LOG.hdiutil"\nexit 1\n' > "$STUBS/hdiutil"
chmod +x "$STUBS/curl" "$STUBS/pgrep" "$STUBS/uname" "$STUBS/hdiutil"

# run_updater OSTYPE ARCH SCRIPT ARGS...: status in $RC, output in $OUT.
run_updater() {
    local ostype="$1" arch="$2" script="$3"
    shift 3
    : > "$WORK/curl.log"
    : > "$WORK/curl.log.hdiutil"
    RC=0
    OUT="$(env -u PORTANODE_ROOT PATH="$STUBS:$PATH" OSTYPE="$ostype" \
      STUB_ARCH="$arch" CURL_LOG="$WORK/curl.log" SERVE="$SERVE" TMPDIR="$WORK" \
      GNUPGHOME="$HOME_A" bash "$TREE/$script" "$@" 2>&1)" || RC=$?
}

# Every path under the platform directories and the two checksum files: a
# directory made or a binary written changes it.
snapshot() {
    ( cd "$TREE" && { find linux macos win | LC_ALL=C sort
                      cat linux/checksums.sha256 macos/checksums.sha256 \
                          win/checksums.sha256; } | cksum )
}

# refused <want>: the last run exited non-zero with <want> in its output, and
# the tree is as snapshot left it.
refused() {
    local after
    after="$(snapshot)"
    if [ "$RC" -eq 0 ]; then
        printf '  exit 0, wanted a refusal\n%s\n' "$OUT"
        return 1
    fi
    contains "$OUT" "$1" || return 1
    if [ "$after" != "$BEFORE" ]; then
        echo "  the tree changed"
        return 1
    fi
    if grep -q '^attach' "$WORK/curl.log.hdiutil"; then
        echo "  hdiutil attached an image"
        return 1
    fi
}

UPDATERS="
macos/scripts/utilities/update-bitcoin.sh darwin24 arm64
linux/scripts/utilities/update-bitcoin.sh linux-gnu x86_64
"

# --- a release served as the publisher would ------------------------------
# serve_release SCRIPT VERSION: the archives and a correctly signed
# SHA256SUMS, in $SERVE; sets FILE, CLI and the hashes.
hash_of() {
    if command -v shasum > /dev/null; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        sha256sum "$1" | awk '{print $1}'
    fi
}
serve_release() {
    local script="$1" v="$2" d="$WORK/build" b
    rm -rf "$SERVE" "$d"
    mkdir -p "$SERVE" "$d/bitcoin-$v/bin"
    for b in bitcoind bitcoin-cli bitcoin-qt bitcoin-tx bitcoin-util bitcoin-wallet bitcoin; do
        printf '#!/bin/sh\necho %s\n' "$b" > "$d/bitcoin-$v/bin/$b"
        chmod +x "$d/bitcoin-$v/bin/$b"
    done
    case "$script" in
        macos/*)
            FILE="bitcoin-$v-arm64-apple-darwin.zip"
            CLI="bitcoin-$v-arm64-apple-darwin.tar.gz"
            mkdir -p "$d/Bitcoin-Qt.app/Contents/MacOS"
            cp "$d/bitcoin-$v/bin/bitcoin-qt" "$d/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt"
            ( cd "$d" && zip -qr "$SERVE/$FILE" Bitcoin-Qt.app )
            tar -C "$d" -czf "$SERVE/$CLI" "bitcoin-$v"
            HASH_CLI="$(hash_of "$SERVE/$CLI")"
            ;;
        *)
            FILE="bitcoin-$v-x86_64-linux-gnu.tar.gz"
            CLI=""
            HASH_CLI=""
            tar -C "$d" -czf "$SERVE/$FILE" "bitcoin-$v"
            ;;
    esac
    HASH="$(hash_of "$SERVE/$FILE")"
    OTHER="$(printf 'another file' | { shasum -a 256 2> /dev/null || sha256sum; } | awk '{print $1}')"
}
# publish_sums: signs $SERVE/SHA256SUMS with the pinned key.
publish_sums() { sign "$SERVE/SHA256SUMS" "$HOME_A"; }
# the lines a correct SHA256SUMS holds
good_sums() {
    printf '%s  %s\n' "$HASH" "$FILE"
    [ -z "$CLI" ] || printf '%s  %s\n' "$HASH_CLI" "$CLI"
}

# bitcoin_run SCRIPT OSTYPE ARCH: the bitcoin updater for a release 29.0, with
# whatever is in $SERVE.
bitcoin_run() {
    BEFORE="$(snapshot)"
    run_updater "$2" "$3" "$1" --version 29.0
}

# --- SHA256SUMS ------------------------------------------------------------
# sums_case SCRIPT OSTYPE ARCH BODY: SHA256SUMS holds what the
# function BODY prints, correctly signed, so that only its content is wrong.
sums_case() {
    local script="$1" ostype="$2" arch="$3" body="$4"
    fresh_tree
    serve_release "$script" 29.0
    "$body" > "$SERVE/SHA256SUMS"
    publish_sums
    bitcoin_run "$script" "$ostype" "$arch"
    refused "Checksum failed" || return 1
    contains "$OUT" "good signatures from 1 key(s)"
}
sums_empty() { :; }
sums_hash_cut() { printf '%s  %s\n' "${HASH%???????????????????????}" "$FILE"
    [ -z "$CLI" ] || printf '%s  %s\n' "$HASH_CLI" "$CLI"; }
sums_name_cut() { printf '%s  %s\n' "$HASH" "${FILE%?}"
    [ -z "$CLI" ] || printf '%s  %s\n' "$HASH_CLI" "$CLI"; }
sums_line_cut() { good_sums | head -c 100; }
sums_no_name() { printf '%s\n' "$HASH"
    [ -z "$CLI" ] || printf '%s  %s\n' "$HASH_CLI" "$CLI"; }
sums_two_hashes() { printf '%s  %s  %s\n' "$HASH" "$OTHER" "$FILE"
    [ -z "$CLI" ] || printf '%s  %s\n' "$HASH_CLI" "$CLI"; }
sums_two_hashes_swapped() { printf '%s  %s  %s\n' "$OTHER" "$HASH" "$FILE"
    [ -z "$CLI" ] || printf '%s  %s\n' "$HASH_CLI" "$CLI"; }
sums_bad_then_good() { printf '%s  %s\n' "$OTHER" "$FILE"; good_sums; }
sums_good_then_bad() { good_sums; printf '%s  %s\n' "$OTHER" "$FILE"; }
sums_other_name() { printf '%s  %s\n' "$HASH" "other-$FILE"
    [ -z "$CLI" ] || printf '%s  %s\n' "$HASH_CLI" "$CLI"; }
sums_other_hash() { printf '%s  %s\n' "$OTHER" "$FILE"
    [ -z "$CLI" ] || printf '%s  %s\n' "$HASH_CLI" "$CLI"; }
sums_dot_slash() { printf '%s  ./%s\n' "$HASH" "$FILE"
    [ -z "$CLI" ] || printf '%s  %s\n' "$HASH_CLI" "$CLI"; }
sums_dir_prefix() { printf '%s  ../%s\n' "$HASH" "$FILE"
    [ -z "$CLI" ] || printf '%s  %s\n' "$HASH_CLI" "$CLI"; }
sums_no_cli() { printf '%s  %s\n' "$HASH" "$FILE"; }
sums_cli_for_other() { printf '%s  %s\n' "$HASH" "$FILE"
    printf '%s  other-%s\n' "$HASH_CLI" "$CLI"; }

# the control: a correct SHA256SUMS installs, so that every refusal below is
# the check refusing and not the harness.
install_case() {
    local script="$1" ostype="$2" arch="$3" bin
    fresh_tree
    serve_release "$script" 29.0
    good_sums > "$SERVE/SHA256SUMS"
    publish_sums
    bitcoin_run "$script" "$ostype" "$arch"
    [ "$RC" -eq 0 ] || { printf '  exit %s\n%s\n' "$RC" "$OUT"; return 1; }
    contains "$OUT" "Bitcoin Core updated to 29.0" || return 1
    case "$script" in
        macos/*) bin="macos/bin/bitcoind" ;;
        *) bin="linux/bin/bitcoind" ;;
    esac
    [ -x "$TREE/$bin" ] || { echo "  $bin not installed"; return 1; }
}

while read -r script ostype arch; do
    [ -n "$script" ] || continue
    plat="${script%%/*}"
    if [ "$plat" = macos ] && ! { command -v zip > /dev/null \
        && command -v unzip > /dev/null; }; then
        echo "ok - skipped: $plat bitcoin needs zip and unzip"
        continue
    fi
    check "$plat update-bitcoin installs a correct SHA256SUMS" \
        install_case "$script" "$ostype" "$arch"
    check "$plat update-bitcoin refuses an empty SHA256SUMS" \
        sums_case "$script" "$ostype" "$arch" sums_empty
    check "$plat update-bitcoin refuses a hash cut short" \
        sums_case "$script" "$ostype" "$arch" sums_hash_cut
    check "$plat update-bitcoin refuses a file name cut short" \
        sums_case "$script" "$ostype" "$arch" sums_name_cut
    check "$plat update-bitcoin refuses SHA256SUMS cut mid-line" \
        sums_case "$script" "$ostype" "$arch" sums_line_cut
    check "$plat update-bitcoin refuses a line with a hash and no name" \
        sums_case "$script" "$ostype" "$arch" sums_no_name
    check "$plat update-bitcoin refuses a line with two hashes" \
        sums_case "$script" "$ostype" "$arch" sums_two_hashes
    check "$plat update-bitcoin refuses a line with two hashes, the good one second" \
        sums_case "$script" "$ostype" "$arch" sums_two_hashes_swapped
    check "$plat update-bitcoin refuses a wrong hash before the right one" \
        sums_case "$script" "$ostype" "$arch" sums_bad_then_good
    check "$plat update-bitcoin refuses a wrong hash after the right one" \
        sums_case "$script" "$ostype" "$arch" sums_good_then_bad
    check "$plat update-bitcoin refuses the hash under another file name" \
        sums_case "$script" "$ostype" "$arch" sums_other_name
    check "$plat update-bitcoin refuses another file's hash under its name" \
        sums_case "$script" "$ostype" "$arch" sums_other_hash
    check "$plat update-bitcoin refuses its name behind ./" \
        sums_case "$script" "$ostype" "$arch" sums_dot_slash
    check "$plat update-bitcoin refuses its name behind ../" \
        sums_case "$script" "$ostype" "$arch" sums_dir_prefix
    if [ "$plat" = macos ]; then
        check "$plat update-bitcoin refuses SHA256SUMS with no entry for the CLI archive" \
            sums_case "$script" "$ostype" "$arch" sums_no_cli
        check "$plat update-bitcoin refuses the CLI archive's hash under another name" \
            sums_case "$script" "$ostype" "$arch" sums_cli_for_other
    fi
done <<< "$UPDATERS"


# --- the signature on what is downloaded -----------------------------------
# serve_electrum SCRIPT VERSION: the installer and its signature, in $SERVE;
# sets EFILE.
serve_electrum() {
    case "$1" in
        macos/*) EFILE="electrum-$2.dmg" ;;
        *) EFILE="electrum-$2-x86_64.AppImage" ;;
    esac
    rm -rf "$SERVE"
    mkdir -p "$SERVE"
    printf 'installer of %s\n' "$2" > "$SERVE/$EFILE"
    sign "$SERVE/$EFILE" "$HOME_A"
}
# sig_case SCRIPT OSTYPE ARCH KIND PRODUCT WANT: what the updater is served
# (the file the signature covers, then the signature, spoiled as KIND says)
# is refused with WANT in its output.
sig_case() {
    local script="$1" ostype="$2" arch="$3" kind="$4" want="$5" file
    fresh_tree
    case "$script" in
        *bitcoin*)
            serve_release "$script" 29.0
            good_sums > "$SERVE/SHA256SUMS"
            file="$SERVE/SHA256SUMS"
            ;;
        *)
            serve_electrum "$script" 4.6.0
            file="$SERVE/$EFILE"
            ;;
    esac
    case "$kind" in
        unimported) sign "$file" "$HOME_C" ;;
        unpinned) sign "$file" "$HOME_B" ;;
        pinned) sign "$file" "$HOME_A" ;;
        tampered) sign "$file" "$HOME_A"; printf 'x' >> "$file" ;;
        garbage) printf '<html>404</html>\n' > "$file.asc" ;;
        empty) : > "$file.asc" ;;
        other) printf 'something else\n' > "$WORK/other"
               sign "$WORK/other" "$HOME_A"
               cp "$WORK/other.asc" "$file.asc" ;;
        missing) rm -f "$file.asc" ;;
    esac
    BEFORE="$(snapshot)"
    case "$script" in
        *bitcoin*) run_updater "$ostype" "$arch" "$script" --version 29.0 ;;
        *) run_updater "$ostype" "$arch" "$script" --version 4.6.0 ;;
    esac
    if [ "$kind" = pinned ]; then
        [ "$RC" -eq 0 ] || { printf '  exit %s\n%s\n' "$RC" "$OUT"; return 1; }
        contains "$OUT" "$want"
    else
        refused "$want"
    fi
}

SIGNED="
macos/scripts/utilities/update-bitcoin.sh darwin24 arm64
linux/scripts/utilities/update-bitcoin.sh linux-gnu x86_64
macos/scripts/utilities/update-electrum.sh darwin24 arm64
linux/scripts/utilities/update-electrum.sh linux-gnu x86_64
"
while read -r script ostype arch; do
    [ -n "$script" ] || continue
    plat="${script%%/*}"
    name="$plat $(basename "$script" .sh)"
    case "$script" in
        macos/*bitcoin*) command -v zip > /dev/null || continue ;;
    esac
    case "$script" in
        linux/*electrum*)
            check "$name installs what a pinned key signed" \
                sig_case "$script" "$ostype" "$arch" pinned "Electrum updated to 4.6.0" ;;
    esac
    check "$name refuses a signature by a key nobody imported" \
        sig_case "$script" "$ostype" "$arch" unimported "no valid PGP signature"
    check "$name refuses a good signature by an imported key that is not pinned" \
        sig_case "$script" "$ostype" "$arch" unpinned "good signatures from 0 key(s)"
    check "$name refuses a file changed after it was signed" \
        sig_case "$script" "$ostype" "$arch" tampered "BAD PGP signature"
    check "$name refuses an error page for a signature" \
        sig_case "$script" "$ostype" "$arch" garbage "found no PGP signature"
    check "$name refuses an empty signature" \
        sig_case "$script" "$ostype" "$arch" empty "found no PGP signature"
    check "$name refuses a good signature of another file" \
        sig_case "$script" "$ostype" "$arch" other "BAD PGP signature"
    check "$name refuses a missing signature" \
        sig_case "$script" "$ostype" "$arch" missing "Downloading"
done <<< "$SIGNED"

# pgp_verify_or_fail on the status lines gpg is made to print. A stub gpg
# prints $STATUS, so each case is one status output and one pin file.
mkdir -p "$WORK/gpgstub"
printf '#!/bin/sh\ncat "$STATUS"\n' > "$WORK/gpgstub/gpg"
chmod +x "$WORK/gpgstub/gpg"
P1=1111111111111111111111111111111111111111
P2=2222222222222222222222222222222222222222
OUTSIDER=3333333333333333333333333333333333333333
SUB1=4444444444444444444444444444444444444444
# status_good SIGNING_FPR PRIMARY_FPR: one signature gpg accepts
status_good() {
    printf '[GNUPG:] NEWSIG\n'
    printf '[GNUPG:] GOODSIG %s portanode test <t@example.invalid>\n' "${1#"${1%????????????????}"}"
    printf '[GNUPG:] VALIDSIG %s 2026-10-22 1792000000 0 4 0 22 10 00 %s\n' "$1" "$2"
}
# pgp_case WANT MIN: the status on stdin; WANT is accept or refuse. The pin
# file holds P1 and P2, and min-signatures MIN.
pgp_case() {
    local verdict="$1" min="$2" got=accept
    printf '%s\n%s\nmin-signatures=%s\n' "$P1" "$P2" "$min" > "$WORK/pins"
    cat > "$WORK/status"
    : > "$WORK/data"
    # shellcheck source=shared/utilities/lib.sh
    ( . "$REPO/shared/utilities/lib.sh"
      PATH="$WORK/gpgstub:$PATH" STATUS="$WORK/status" \
        pgp_verify_or_fail "$WORK/data" "$WORK/data" "test" "$WORK/pins" \
        > "$WORK/pgp.out" 2>&1 ) || got=refuse
    if [ "$got" != "$verdict" ]; then
        printf '  %s, wanted %s\n' "$got" "$verdict"
        sed 's/^/    /' "$WORK/pgp.out"
        return 1
    fi
}
check "a signature by a pinned key is accepted" \
    pgp_case accept 1 < <(status_good "$P1" "$P1")
check "a signature by a pinned key's subkey is accepted" \
    pgp_case accept 1 < <(status_good "$SUB1" "$P1")
check "empty gpg output is refused" pgp_case refuse 1 < /dev/null
check "a NEWSIG alone is refused" pgp_case refuse 1 < <(echo '[GNUPG:] NEWSIG')
check "a good signature by a key that is not pinned is refused" \
    pgp_case refuse 1 < <(status_good "$OUTSIDER" "$OUTSIDER")
check "a GOODSIG with no VALIDSIG is refused" \
    pgp_case refuse 1 < <(status_good "$P1" "$P1" | grep -v VALIDSIG)
check "a VALIDSIG with no GOODSIG is refused" \
    pgp_case refuse 1 < <(status_good "$P1" "$P1" | grep -v GOODSIG)
check "a GOODSIG and a VALIDSIG of two keys are refused" \
    pgp_case refuse 1 < <(
        printf '[GNUPG:] NEWSIG\n'
        status_good "$OUTSIDER" "$OUTSIDER" | sed -n 2p
        status_good "$P1" "$P1" | sed -n 3p)
check "a GOODSIG and a VALIDSIG in two signatures are refused" \
    pgp_case refuse 1 < <(
        status_good "$OUTSIDER" "$OUTSIDER" | sed -n 1,2p
        status_good "$P1" "$P1" | sed -n -e 1p -e 3p)
check "a pinned fingerprint as the signing key of an unpinned primary is refused" \
    pgp_case refuse 1 < <(status_good "$P1" "$OUTSIDER")
check "two GOODSIG lines in one signature are refused" \
    pgp_case refuse 1 < <(status_good "$P1" "$P1"
        status_good "$OUTSIDER" "$OUTSIDER" | sed -n 2p)
check "a BADSIG beside a good signature is refused" \
    pgp_case refuse 1 < <(status_good "$P1" "$P1"
        echo "[GNUPG:] BADSIG ${OUTSIDER#????????????????????????} x")
check "a revoked key's signature is refused" \
    pgp_case refuse 1 < <(status_good "$P1" "$P1"; echo "[GNUPG:] KEYREVOKED")
check "a REVKEYSIG is refused" \
    pgp_case refuse 1 < <(status_good "$P1" "$P1" | sed 's/GOODSIG/REVKEYSIG/')
check "an expired key's signature is refused" \
    pgp_case refuse 1 < <(status_good "$P1" "$P1" | sed 's/GOODSIG/EXPKEYSIG/')
check "a status line that does not start the line is refused" \
    pgp_case refuse 1 < <(status_good "$P1" "$P1" | sed 's/^/ /')
check "a key ID shorter than 16 digits is refused" \
    pgp_case refuse 1 < <(status_good "$P1" "$P1" \
        | sed 's/GOODSIG [0-9A-F]* /GOODSIG 4111111111 /')
check "one of two required signatures is refused" \
    pgp_case refuse 2 < <(status_good "$P1" "$P1")
check "one key signing twice is one of two required signatures" \
    pgp_case refuse 2 < <(status_good "$P1" "$P1"; status_good "$SUB1" "$P1")
check "two pinned keys meet two required signatures" \
    pgp_case accept 2 < <(status_good "$P1" "$P1"; status_good "$P2" "$P2")
check "one pinned and one unpinned key do not meet two required signatures" \
    pgp_case refuse 2 < <(status_good "$P1" "$P1"; status_good "$OUTSIDER" "$OUTSIDER")

# --- a version string ------------------------------------------------------
# A version reaches a URL, a file name and a directory name, so only digits
# and dots are let through. The bad ones are given to every updater, as the
# only argument, with --allow-downgrade and with --dry-run, where the
# installed version is unknown.
BAD_VERSIONS=(
    '27.0/../28.0' '../../etc' '27.0;touch x' '27.0 && id' ' 27.0' '27.0 '
    $'27.0\n28.0' $'27.0\r' '27.0rc1' 'v27.0' '27..0' '.27' '27.' '27.0\x'
    '27.0%2f..' '$(id)' '`id`' '-1' '27.0?x=1' '27.0#frag' '27.0:80'
    '27.0@evil.example' 'unknown' '١٢.٠' '２７.０' '2 7.0' 'x'
)
version_case() {
    local script="$1" ostype="$2" arch="$3" version="$4" flag="$5"
    BEFORE="$(snapshot)"
    run_updater "$ostype" "$arch" "$script" --version "$version" ${flag:+"$flag"}
    refused "Refusing to install" || return 1
    if [ -s "$WORK/curl.log" ]; then
        printf '  curl ran:\n'
        sed 's/^/    /' "$WORK/curl.log"
        return 1
    fi
}
while read -r script ostype arch; do
    [ -n "$script" ] || continue
    name="$(echo "$script" | cut -d/ -f1) $(basename "$script" .sh)"
    fresh_tree
    run_updater "$ostype" "$arch" "$script" --version 29.0 --dry-run
    check "$name --version 29.0 --dry-run proceeds" \
        contains "$OUT" "Would install"
    for v in "${BAD_VERSIONS[@]}"; do
        shown="$(printf '%s' "$v" | tr '\n\r' '||')"
        check "$name refuses --version '$shown'" \
            version_case "$script" "$ostype" "$arch" "$v" ""
        check "$name refuses --version '$shown' --allow-downgrade" \
            version_case "$script" "$ostype" "$arch" "$v" "--allow-downgrade"
        check "$name refuses --version '$shown' --dry-run" \
            version_case "$script" "$ostype" "$arch" "$v" "--dry-run"
    done
done <<< "$SIGNED"

# --- the release index ------------------------------------------------------
# A version read from the index is the same kind of string: only the
# well-formed one is taken.
index_case() {
    local script="$1" ostype="$2" arch="$3" index="$4" want="$5"
    fresh_tree
    rm -rf "$SERVE"
    mkdir -p "$SERVE"
    case "$script" in
        *bitcoin*) printf '%s\n' "$index" > "$SERVE/index-bitcoin" ;;
        *) printf '%s\n' "$index" > "$SERVE/index-electrum" ;;
    esac
    BEFORE="$(snapshot)"
    run_updater "$ostype" "$arch" "$script" --dry-run
    contains "$OUT" "$want" || return 1
    [ "$(snapshot)" = "$BEFORE" ] || { echo "  the tree changed"; return 1; }
    ! grep -E "$INDEX_BAD" "$WORK/curl.log" || { echo "  curl was given a malformed version"; return 1; }
}
INDEX_BAD='99\.0|98\.0|97\.|96\.|9\.9|8\.8|7\.7|6\.6|5\.5|\.\./'
BITCOIN_INDEX_BAD='<a href="bitcoin-core-99.0/../">x</a>
<a href="bitcoin-core-98.0;x/">x</a>
<a href="bitcoin-core-97.0.0.0/">x</a>
<a href="../bitcoin-core-96.0/">x</a>
<a href="bitcoin-core-0.21.0/">x</a>'
ELECTRUM_INDEX_BAD='<a href="9.9.9/../">x</a>
<a href="8.8.8.8/">x</a>
<a href="7.7/">x</a>
<a href="v6.6.6/">x</a>
<a href="5.5.5;x/">x</a>'
check "linux update-bitcoin takes the one well-formed version of its index" \
    index_case linux/scripts/utilities/update-bitcoin.sh linux-gnu x86_64 \
    "$BITCOIN_INDEX_BAD
<a href=\"bitcoin-core-29.0/\">x</a>" "Latest Bitcoin Core with a x86_64-linux-gnu build: 29.0"
check "macos update-bitcoin takes the one well-formed version of its index" \
    index_case macos/scripts/utilities/update-bitcoin.sh darwin24 arm64 \
    "$BITCOIN_INDEX_BAD
<a href=\"bitcoin-core-29.0/\">x</a>" "Latest Bitcoin Core with a macOS build: 29.0"
check "linux update-bitcoin finds no version in an index of malformed ones" \
    index_case linux/scripts/utilities/update-bitcoin.sh linux-gnu x86_64 \
    "$BITCOIN_INDEX_BAD" "Failed to find a Bitcoin Core release"
check "macos update-bitcoin finds no version in an index of malformed ones" \
    index_case macos/scripts/utilities/update-bitcoin.sh darwin24 arm64 \
    "$BITCOIN_INDEX_BAD" "Failed to find a Bitcoin Core release"
for plat in linux macos; do
    if [ "$plat" = linux ]; then os=linux-gnu arch=x86_64; else os=darwin24 arch=arm64; fi
    check "$plat update-electrum takes the one well-formed version of its index" \
        index_case "$plat/scripts/utilities/update-electrum.sh" $os $arch \
        "$ELECTRUM_INDEX_BAD
<a href=\"4.6.0/\">x</a>" "Would install Electrum 4.6.0"
    check "$plat update-electrum finds no version in an index of malformed ones" \
        index_case "$plat/scripts/utilities/update-electrum.sh" $os $arch \
        "$ELECTRUM_INDEX_BAD" "Failed to determine latest Electrum version"
done

finish
