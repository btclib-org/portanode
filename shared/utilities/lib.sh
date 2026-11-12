#!/bin/bash
# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# Shared helpers for download, PGP verification and checksum bookkeeping.
# Platform-nameless like shared/lib.sh beside it: macos/scripts/utilities/
# lib.sh and linux/scripts/utilities/lib.sh each forward to it rather than
# holding the implementation, so the path arithmetic into shared/ lives in
# one forwarder per platform instead of in every utility script.
# Nearly all of it reads no platform-specific path -- curl, gpg, a
# checksum command chosen at run time, and a retry loop that exists
# because the install target may be exFAT. Which helpers those are is
# not listed here: such a list is wrong the moment a helper is added or
# stops reading a path, with nothing to catch it.
# The platform path that is written into the code is the checksum_file
# default on update_checksum, verify_checksum_entry and
# installed_version, each falling back to macos/checksums.sha256. The
# fallback is silent, so a caller on any other platform passes
# checksum_file explicitly -- see the comment on each default.
# verify_binaries takes every platform-specific value as a required
# argument and defaults none of them, rather than inheriting the
# macos/checksums.sha256 default above: its callers differ in checksum
# file and path prefix on every call, so a default would be wrong for one
# of them on every single invocation rather than merely on an omitted
# one. Each caller's own comment names its counterpart.

_UTILS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=shared/lib.sh
. "$_UTILS_LIB_DIR/../lib.sh"
unset _UTILS_LIB_DIR

# The good signatures from distinct keys of keys/ that an update needs, as
# #783 decided. win/scripts/utilities/update-bitcoin.bat and
# update-electrum.bat pass the same numbers.
# shellcheck disable=SC2034 # read by the updaters that source this file
BITCOIN_CORE_MIN_SIGNATURES=3
# shellcheck disable=SC2034 # read by the updaters that source this file
ELECTRUM_MIN_SIGNATURES=1

debug_list_dir() {
    local dir="$1"
    local entries
    # find exits 1 when $dir does not exist, and pipefail (set by every
    # caller) carries that through the pipeline into the assignment; "||
    # true" keeps a missing directory a listing (of nothing) rather than a
    # death of the caller, which is the case this helper exists for.
    entries="$(find "$dir" -mindepth 1 -maxdepth 1 -exec basename {} \; \
        2> /dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')" || true
    # The ROOTDIR prefix is stripped because the folder is mounted at a
    # different point on every machine it is plugged into, so a message
    # quoting the mount point tells the reader where this run happened
    # rather than which file in the folder is meant. The strip is applied
    # where a message would otherwise print an absolute path, which is
    # not every message here that names one: verify_binaries prints
    # locals that are relative already, and install_verified's source is
    # a temporary extraction directory outside the folder, so neither is
    # stripped.
    echo "Debug: ${dir#"$ROOTDIR"/} contents: $entries"
}

# tree_hash PATH — deterministic content hash of a file, or of a directory:
# each regular file under it by path and content, and each symlink by path
# and target string. A symlink is never followed, so one that changes or
# goes missing changes the hash. AppleDouble sidecars (._*) are ignored so a
# source on APFS and a copy on exFAT (which materialises ._* files) compare
# equal. For a directory it prints nothing and returns 1 where a file or
# link under it cannot be read.
#
# The macOS updaters record a bundle's tree_hash in macos/checksums.sha256,
# and no updater rewrites an entry, so a change to what this hashes leaves
# every bundle entry already recorded unmatched.
#
# The checksum command is picked at run time rather than fixed to shasum:
# macOS always has shasum, but a bare Linux install is not guaranteed to
# (it ships from Perl's Digest::SHA, not from coreutils), where sha256sum
# always is. tree_hash makes that pick itself rather than taking a checksum
# command as an argument, so a caller hands it a path and repeats nothing.
tree_hash() {
    local path="$1"
    local -a sha_cmd
    if command -v shasum > /dev/null 2>&1; then
        sha_cmd=(shasum -a 256)
    elif command -v sha256sum > /dev/null 2>&1; then
        sha_cmd=(sha256sum)
    else
        echo "Error: neither shasum nor sha256sum found." >&2
        return 1
    fi
    if [ -d "$path" ]; then
        # What is hashed is a stream of records, each a type letter, a path
        # and a value, every field ended by a NUL: "f", the path and the
        # content hash for a file, "l", the path and the target for a
        # symlink. No path or target can hold a NUL, so no two trees give
        # one stream; a separator a name can hold, such as " -> " or a
        # newline, would let two trees collide.
        #
        # The files are hashed in one batch for speed, and their hashes are
        # paired with the NUL-separated paths by position. shasum and GNU
        # sha256sum print a name holding a newline or a backslash on one
        # line behind a leading backslash, which is dropped; a tool that
        # does not escape prints more lines than there are files, and the
        # count check refuses. xargs -r: GNU xargs otherwise runs the
        # command once on empty input; BSD xargs accepts the flag.
        (
            cd "$path" || exit 1
            set -o pipefail
            # No "local": the subshell already scopes tmp and out, and on
            # macOS's bash 3.2 a local is gone by the time the EXIT trap
            # runs on "exit 1", which leaves the directory behind.
            # A template, because macOS's mktemp -d without one ignores
            # TMPDIR.
            tmp="$(mktemp -d "${TMPDIR:-/tmp}/portanode-tree-hash.XXXXXX")" \
                || exit 1
            trap 'rm -rf "$tmp"' EXIT
            find . -type f ! -name '._*' -print0 | LC_ALL=C sort -z \
                > "$tmp/files" || exit 1
            find . -type l ! -name '._*' -print0 | LC_ALL=C sort -z \
                > "$tmp/links" || exit 1
            xargs -0 -r "${sha_cmd[@]}" < "$tmp/files" \
                | sed 's/^\\//' | cut -c 1-64 > "$tmp/hashes" || exit 1
            [ "$(LC_ALL=C tr -cd '\000' < "$tmp/files" | wc -c)" -eq \
                "$(wc -l < "$tmp/hashes")" ] || exit 1
            ! grep -qvE '^[0-9a-f]{64}$' "$tmp/hashes" || exit 1
            # In the symlink loop, readlink -n prints the target with no line
            # end added (without -n, macOS's readlink adds one only where the
            # target does not already end in a newline), and the x keeps the
            # target's trailing newlines, which command substitution would strip.
            out="$(
                {
                    while IFS= read -r -d '' p && IFS= read -r h <&3; do
                        printf 'f\0%s\0%s\0' "$p" "$h"
                    done < "$tmp/files" 3< "$tmp/hashes"
                    while IFS= read -r -d '' p; do
                        t="$(readlink -n "$p" && printf x)" || exit 1
                        printf 'l\0%s\0%s\0' "$p" "${t%x}"
                    done < "$tmp/links"
                } | "${sha_cmd[@]}" | awk '{print $1}'
            )" || exit 1
            printf '%s\n' "$out"
        )
    else
        "${sha_cmd[@]}" "$path" 2> /dev/null | awk '{print $1}'
    fi
}

# install_verified SRC DEST — replace DEST with a copy of SRC, then verify the
# copy is byte-identical (content) and retry on mismatch. Defends against
# removable filesystems (notably macOS's fskit exFAT) that can silently corrupt
# files on write. Returns non-zero if still corrupt after several attempts.
install_verified() {
    local src="$1" dest="$2" want got i
    want="$(tree_hash "$src")" || want=""
    if [ -z "$want" ]; then
        echo "Error: cannot hash source $src"
        return 1
    fi
    for i in 1 2 3 4 5; do
        rm -rf "$dest"
        cp -R "$src" "$dest"
        sync 2> /dev/null || true
        got="$(tree_hash "$dest")" || got=""
        if [ "$got" = "$want" ]; then
            return 0
        fi
        echo "Warning: $(basename "$dest") corrupted on write" \
            "(attempt $i/5); retrying..."
    done
    echo "Error: $(basename "$dest") still corrupt after 5 attempts."
    echo "The destination filesystem may be unreliable (e.g. exFAT/fskit)."
    return 1
}

# verify_sha256sums TMP_DIR SUMS_FILE ARCHIVE...
#
# Filters SUMS_FILE, already downloaded into TMP_DIR, down to the named
# ARCHIVE entries and checks them with whichever of shasum or sha256sum is
# on PATH, the run-time pick tree_hash's comment above explains. The
# sha256sum branch is not dead: a Linux install without shasum runs it.
#
# A line is an ARCHIVE's entry where it is 64 hex digits, a space, a space
# or "*", and a file-name field equal to ARCHIVE as a whole string. Each
# ARCHIVE needs exactly one entry, or the call refuses before hashing
# anything: the check passes on the entries it finds, so a name matched as
# a substring, or a name left without an entry, would let one listed
# archive pass for another that SUMS_FILE does not list.
verify_sha256sums() {
    local tmp_dir="$1"
    local sums_file="$2"
    shift 2
    local filtered="${sums_file}.filtered"
    local name count
    : > "$tmp_dir/$filtered" || return 1
    for name in "$@"; do
        # ENVIRON rather than -v: awk reads escape sequences in a -v value.
        count="$(_vs_name="$name" _vs_out="$tmp_dir/$filtered" awk '
            length($0) > 66 && substr($0, 1, 64) !~ /[^0-9A-Fa-f]/ &&
            substr($0, 65, 1) == " " && substr($0, 66, 1) ~ /^[ *]$/ &&
            substr($0, 67) == ENVIRON["_vs_name"] {
                n++
                print >> ENVIRON["_vs_out"]
            }
            END { print n + 0 }' "$tmp_dir/$sums_file")" || count=""
        if [ "$count" != 1 ]; then
            echo "Error: ${sums_file} holds ${count:-an unreadable number of}" \
                "entries for ${name}; exactly 1 is required."
            return 1
        fi
    done
    if command -v shasum > /dev/null 2>&1; then
        (cd "$tmp_dir" && shasum -a 256 -c "$filtered")
    elif command -v sha256sum > /dev/null 2>&1; then
        (cd "$tmp_dir" && sha256sum -c "$filtered")
    else
        echo "Error: Neither shasum nor sha256sum found."
        return 1
    fi
}

# keyring_is_readable KEYRING
#
# Returns 0 where KEYRING is a readable file holding at least one byte.
# pgp_verify_or_fail and the updaters' --dry-run previews both ask it, so a
# preview reports the refusal the verification makes.
keyring_is_readable() {
    [ -n "$1" ] && [ -f "$1" ] && [ -r "$1" ] && [ -s "$1" ]
}

# pgp_verify_or_fail SIG_FILE DATA_FILE LABEL KEYRING MIN
#
# Verifies DATA_FILE against the detached SIG_FILE with the keys in KEYRING
# alone. FAILS CLOSED: returns non-zero (so the caller aborts the install)
# unless SIG_FILE carries good signatures from MIN distinct keys of KEYRING.
# gpg runs in a home of its own, made empty for the call in SIG_FILE's folder,
# with KEYRING copied in as its only keyring: it reads no option, key or trust
# setting of the user's, so a key the user imported does not count. The
# updaters download into a folder of their own whose EXIT trap removes it, so
# that trap removes the home too where the run is interrupted. The copy is
# named without a slash, which gpg reads as a file of that home, so the call
# is the one win/scripts/utilities/lib.bat's :verify_pgp_signature makes.
# --batch is not passed: measured in #783 with gpg 2.5.24, it stops this
# command at the first signature whose key is absent.
pgp_verify_or_fail() {
    local sig_file="$1"
    local data_file="$2"
    local label="$3"
    local keyring="${4:-}"
    local min_sigs="${5:-}"
    local keyring_name gpg_home rc

    if ! command -v gpg > /dev/null 2>&1; then
        echo "Error: gpg not found; cannot verify ${label}."
        echo "Install gpg (e.g. 'brew install gnupg')."
        return 1
    fi
    keyring_name="$(basename "${keyring:-keyring}")"
    if ! keyring_is_readable "$keyring"; then
        echo "Error: ${keyring_name} is missing, empty or unreadable," \
            "so ${label} is refused."
        return 1
    fi
    # The length test keeps a MIN too large for bash's integers away from
    # -lt, which errors on it rather than answering.
    if ! [[ "$min_sigs" =~ ^[123456789][0123456789]{0,8}$ ]]; then
        echo "Error: ${min_sigs:-no number} is not a number of signatures" \
            "to ask for, so ${label} is refused."
        return 1
    fi

    echo "Verifying ${label} signature..."
    # mktemp fails where the folder is missing or not writable; gpg then
    # never runs.
    gpg_home="$(mktemp -d "$(dirname "$sig_file")/gpg-home.XXXXXX")" \
        || gpg_home=""
    if [ -z "$gpg_home" ] || ! cp "$keyring" "$gpg_home/keys.gpg"; then
        echo "Error: no folder could be made for gpg to verify ${label} in;" \
            "whether the signature is good is unknown."
        [ -z "$gpg_home" ] || rm -rf "$gpg_home"
        return 1
    fi
    gpg --homedir "$gpg_home" --no-default-keyring --keyring keys.gpg \
        --status-fd 1 --verify "$sig_file" "$data_file" \
        1> "$gpg_home/status" 2> /dev/null || true
    rc=0
    pgp_read_status "$gpg_home/status" "$label" "$keyring_name" "$min_sigs" \
        || rc=$?
    rm -rf "$gpg_home"
    return "$rc"
}

# pgp_read_status STATUS_FILE LABEL KEYRING_NAME MIN
#
# Reads the status lines gpg wrote for pgp_verify_or_fail, and returns 0
# where they hold good signatures from MIN distinct keys.
pgp_read_status() {
    local status_file="$1"
    local label="$2"
    local keyring_name="$3"
    local min_sigs="$4"
    local n_good n_weak counts

    # A status file that is absent or empty is gpg's answer lost rather
    # than a signature refused, and the greps below cannot separate the
    # two: on a name no file answers to, grep exits non-zero exactly as
    # it does on a file holding no GOODSIG. Where gpg does run it writes a
    # status line for a signature it refuses as much as for one it
    # accepts, which is why its exit status is not what is read here, and
    # the tests below are what read that. -s rather than -e, an empty file
    # answering no more than a missing one; no case measured here
    # separates the two.
    if [ ! -s "$status_file" ]; then
        echo "Error: gpg's status output for ${label} was not read;" \
            "whether the signature is good is unknown."
        return 1
    fi

    if grep -q '^\[GNUPG:\] BADSIG' "$status_file"; then
        echo "Error: BAD PGP signature on ${label}."
        return 1
    fi

    # gpg's own doc/DETAILS gives NEWSIG as issued right before a
    # signature verification starts, so a status file holding none is gpg
    # reporting that it never reached one. The GOODSIG test below cannot
    # separate that from a signature gpg read and could not validate, and
    # names the keyring for both. DETAILS says under GOODSIG that the
    # per-signature codes "were used as a marker for a new signature; new
    # code should use the NEWSIG status instead", so the dependence is the
    # one upstream asks for; nothing in this tree states a minimum gpg,
    # and the oldest measured against it is 2.4.4.
    # gpg's own exit status does not separate them either: a key that is
    # not in the keyring and a signature file that cannot be opened both
    # leave 2. Nor does the FAILURE line, which reads "verify" for a
    # signature file that is missing, empty or unreadable and "gpg-exit"
    # for one holding something that is not a signature and for a file to
    # check that cannot be opened; a test on it would leave those last two
    # on the keyring message.
    # Measured with gpg 2.5.21 on macOS and gpg 2.4.4 on ubuntu-latest:
    # NEWSIG is present for a good signature, for a tampered one and for
    # a key that is not in the keyring, and absent where the signature
    # file is missing, empty, unreadable or not a signature and where the
    # file it signs is missing or unreadable.
    # The advice below names no cause, several reaching it alike. A
    # signature file that is present and readable and merely not a
    # signature is one of them -- the shape a download answering 200 with
    # an error page leaves -- so advice to check presence and readability
    # would send that reader to confirm two things already true.
    if ! grep -q '^\[GNUPG:\] NEWSIG' "$status_file"; then
        echo "Error: gpg found no PGP signature to check on ${label}."
        echo "Check the signature file and the file it signs."
        return 1
    fi

    # gpg's doc/DETAILS starts each signature's status lines with NEWSIG,
    # and the lines up to the next NEWSIG are that signature's. One counts
    # where it has exactly one GOODSIG and one VALIDSIG, the GOODSIG's key
    # ID ends the VALIDSIG's signing-key fingerprint, the VALIDSIG's
    # primary-key fingerprint, its tenth argument, is 40 or 64 hex digits,
    # and its hash algorithm, its eighth, is a number above 3: 1, 2 and 3
    # are MD5, SHA-1 and RIPEMD-160, which RFC 9580, section 9.5, says an
    # implementation must not validate a recent signature depending on. It
    # is counted by that fingerprint, so a key signing twice counts once.
    # Read apart, a GOODSIG from one key and a VALIDSIG from another would
    # add up to a signature neither made. KEYREVOKED or REVKEYSIG in the
    # same block keeps it out: measured with gpg 2.5.24, a revoked key's
    # signature carries REVKEYSIG, VALIDSIG and KEYREVOKED, and an expired
    # key's carries EXPKEYSIG in place of GOODSIG.
    # A signature that passes every test but its hash is counted apart, so
    # that the refusal can name the hash. So is one gpg could not check
    # where its ERRSIG gives hash 1, 2 or 3 and a code other than 9, which
    # doc/DETAILS gives as a missing key: measured with gpg 2.5.24, a key's
    # signature over MD5 gives ERRSIG with code 5 where the keyring holds
    # the key and 9 where it does not, while one over SHA-1 or RIPEMD-160
    # gives GOODSIG and VALIDSIG.
    counts="$(awk '
        function flush() {
            if (open && errs == 1 && goods == 0 && valids == 0 &&
                errhash ~ /^[0123456789]+$/ && errhash + 0 >= 1 &&
                errhash + 0 <= 3 && errrc != "9") {
                weak++
                return
            }
            if (!(open && goods == 1 && valids == 1 && !revoked &&
                length(gid) >= 16 && length(sfpr) >= length(gid) &&
                substr(sfpr, length(sfpr) - length(gid) + 1) == gid &&
                (length(primary) == 40 || length(primary) == 64) &&
                primary !~ /[^0123456789ABCDEF]/ &&
                hash ~ /^[0123456789]+$/))
                return
            if (hash + 0 > 3 && !(primary in counted)) {
                counted[primary] = 1
                n++
            } else if (hash + 0 >= 1 && hash + 0 <= 3)
                weak++
        }
        $1 != "[GNUPG:]" { next }
        $2 == "NEWSIG" {
            flush()
            open = 1; goods = 0; valids = 0; revoked = 0; errs = 0
            gid = ""; sfpr = ""; primary = ""; hash = ""
            errhash = ""; errrc = ""
            next
        }
        $2 == "ERRSIG" { errs++; errhash = $5; errrc = $8 }
        $2 == "GOODSIG" { goods++; gid = toupper($3) }
        $2 == "VALIDSIG" {
            valids++; sfpr = toupper($3); hash = $10; primary = toupper($12)
        }
        $2 == "REVKEYSIG" || $2 == "KEYREVOKED" { revoked = 1 }
        END { flush(); print n + 0, weak + 0 }
    ' "$status_file")" || counts=""
    read -r n_good n_weak <<< "$counts"
    case "$n_good" in
        '' | *[!0123456789]*) n_good=0 ;;
        *) ;;
    esac
    case "$n_weak" in
        '' | *[!0123456789]*) n_weak=0 ;;
        *) ;;
    esac
    if ! grep -q '^\[GNUPG:\] GOODSIG' "$status_file"; then
        echo "Error: no PGP signature on ${label} verifies against a key in" \
            "${keyring_name}."
        pgp_weak_line "$n_weak" "$label"
        return 1
    fi
    if [ "$n_good" -lt "$min_sigs" ]; then
        echo "Error: ${label} carries good signatures from ${n_good} key(s)" \
            "in ${keyring_name}; it asks for ${min_sigs}."
        pgp_weak_line "$n_weak" "$label"
        echo "A key counts once, and not at all where it is expired or" \
            "revoked."
        return 1
    fi
    echo "${label}: good signatures from ${n_good} key(s) in" \
        "${keyring_name}; ${min_sigs} required."
    return 0
}

# pgp_weak_line N LABEL: where N is above 0, says that N signatures on
# LABEL were refused for their hash.
pgp_weak_line() {
    if [ "$1" -gt 0 ]; then
        echo "$1 signature(s) on $2 use MD5, SHA-1 or RIPEMD-160, a weak" \
            "hash, and do not count."
    fi
}

update_checksum() {
    local file="$1"
    local entry_path="$2"
    local version="$3"
    # This default is macOS's own path, and omitting the argument is not
    # an error: a caller that omits it appends to macos/checksums.sha256
    # whatever platform it is running on. A non-macOS caller passes
    # checksum_file explicitly -- linux/scripts/utilities/'s updaters
    # pass linux/checksums.sha256.
    local checksum_file="${4:-$ROOTDIR/macos/checksums.sha256}"
    local hash=""

    # A directory is an app bundle, recorded by tree_hash as a whole.
    if [ ! -f "$file" ] && [ ! -d "$file" ]; then
        echo "Error: checksum source not found at ${file#"$ROOTDIR"/}"
        debug_list_dir "$(dirname "$file")"
        exit 1
    fi

    hash="$(tree_hash "$file")" || hash=""

    # tree_hash prints nothing for a file or bundle it cannot read, and
    # nothing where neither shasum nor sha256sum is on PATH, so hash is
    # empty. The entry built below would then carry an empty hash field
    # into checksums.sha256, where no updater rewrites it and it can
    # never match a binary: verify_checksum_entry's awk reads such a
    # line's path as $1, and no real hash equals a path. A chmod 000
    # file and one carrying a "deny read" ACL both produce that empty
    # capture, and so does a bundle hashed while the volume holding
    # TMPDIR is full, where tree_hash keeps its lists. For a file a full
    # volume does not, a read needing no free space.
    #
    # What is tested is the result rather than the status, because for a
    # file, without pipefail, the assignment's status is awk's, which is
    # 0. And "|| hash=''" above is what lets the test run at all: under
    # errexit the command substitution carries tree_hash's non-zero
    # status (for a file only with pipefail too; a directory's subshell
    # sets pipefail itself) and the caller dies at the assignment, with
    # no message of its own, where a "||" list suppresses errexit for it
    # and leaves the refusal here, named and returned.
    # Which callers set which options is not listed here -- `git grep -n
    # '^set ' -- '*/scripts/utilities/update-*.sh'` answers it live.
    if [ -z "$hash" ]; then
        echo "Error: could not hash ${file#"$ROOTDIR"/};"
        echo "nothing appended to ${checksum_file#"$ROOTDIR"/}."
        return 1
    fi

    if [ ! -f "$checksum_file" ]; then
        echo "Warning: ${checksum_file#"$ROOTDIR"/} not found;"
        debug_list_dir "$(dirname "$checksum_file")"
        echo "checksums not updated."
        return 0
    fi

    # This function only appends to */checksums.sha256: a rollback
    # verifies its backup binary against an entry a previous install
    # recorded for this same entry_path, so rewriting that entry to the
    # current hash would leave the backup unrecognized and the rollback
    # refusing it. An earlier entry stays findable by the binary it
    # describes: verify_checksum_entry and installed_version select on
    # hash and path together.
    local entry="$hash  $entry_path  version=$version"
    if ! grep -Fxq "$entry" "$checksum_file"; then
        echo "$entry" >> "$checksum_file"
    fi
}

verify_checksum_entry() {
    local file="$1"
    local entry_path="$2"
    # macOS's own path, as update_checksum's default above explains; a
    # non-macOS caller must pass checksum_file explicitly.
    local checksum_file="${3:-$ROOTDIR/macos/checksums.sha256}"
    local label="${4:-backup binary}"
    local hash=""

    # A directory is an app bundle, hashed by tree_hash as a whole.
    if [ ! -f "$file" ] && [ ! -d "$file" ]; then
        echo "Error: ${label} not found at ${file#"$ROOTDIR"/}"
        debug_list_dir "$(dirname "$file")"
        return 2
    fi
    if [ ! -f "$checksum_file" ]; then
        echo "Error: ${checksum_file#"$ROOTDIR"/} not found."
        debug_list_dir "$(dirname "$checksum_file")"
        return 2
    fi

    hash="$(tree_hash "$file")" || hash=""
    if [ -z "$hash" ]; then
        echo "Error: could not hash ${label} at ${file#"$ROOTDIR"/}."
        return 2
    fi

    # $2 (the entry's own path field) is matched exactly rather than with
    # index($0, p): a substring match reads a line as matching any path it
    # is a prefix of, e.g. "macos/bin/bitcoin" would also match a
    # "macos/bin/bitcoin-cli" line.
    if ! awk -v h="$hash" \
        -v p="$entry_path" \
        '$1 == h && $2 == p { found=1 } END { exit found ? 0 : 1 }' \
        "$checksum_file"; then
        return 1
    fi
    return 0
}

# installed_version FILE ENTRY_PATH [CHECKSUM_FILE] — the "version=" label of
# the checksums.sha256 entry matching FILE's current hash. Its answer is a
# --dry-run plan's "currently installed" line, a rollback's version lines,
# and what refuse_downgrade compares before an update. Echoes "unknown"
# rather than failing where the file is missing or its hash unrecorded, and
# refuse_downgrade refuses no well-formed version as older on "unknown".
installed_version() {
    local file="$1"
    local entry_path="$2"
    # macOS's own path, as update_checksum's default above explains; a
    # non-macOS caller must pass checksum_file explicitly.
    local checksum_file="${3:-$ROOTDIR/macos/checksums.sha256}"
    local hash=""

    if [ ! -f "$file" ] || [ ! -f "$checksum_file" ]; then
        echo "unknown"
        return 0
    fi

    if command -v shasum > /dev/null 2>&1; then
        hash="$(shasum -a 256 "$file" | awk '{print $1}')"
    elif command -v sha256sum > /dev/null 2>&1; then
        hash="$(sha256sum "$file" | awk '{print $1}')"
    else
        echo "unknown"
        return 0
    fi

    # $2 == p, not index($0, p): see verify_checksum_entry's own comment.
    awk -v h="$hash" -v p="$entry_path" '
        $1 == h && $2 == p {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^version=/) {
                    sub(/^version=/, "", $i)
                    print $i
                    found = 1
                    exit
                }
            }
        }
        END { if (!found) print "unknown" }
    ' "$checksum_file"
}

# preview_keyring KEYRING NAME WHAT MIN
#
# For an updater's --dry-run, with gpg found: prints what pgp_verify_or_fail
# would make of KEYRING before any signature is read. A keyring that
# keyring_is_readable refuses would refuse WHAT (the download); otherwise
# it prints the MIN good signatures verification asks for. NAME is the
# keyring as the reader knows it (keys/electrum.gpg). Always returns 0: a
# preview reports and does not end the run.
preview_keyring() {
    if ! keyring_is_readable "$1"; then
        echo "gpg: found, but ${2} is missing, empty or unreadable --" \
            "verification would refuse ${3}."
        return 0
    fi
    echo "gpg: found. Verification asks for ${4} good signature(s) from" \
        "distinct keys in ${2}."
    return 0
}

# _verify_binaries_trim STRING — strip leading and trailing whitespace,
# printed rather than echoed so a value starting with "-" is not read as
# an option.
_verify_binaries_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf "%s" "$s"
}

# verify_binaries ROOTDIR CHECKSUM_FILE PREFIX
#
# Parses CHECKSUM_FILE (ROOTDIR-relative) for lines of the form
# "<sha256>  <path>[  version=<label>]", keeps only the entries whose
# path is under "PREFIX/", then hashes each such path under ROOTDIR with
# tree_hash, a directory (an app bundle) as a whole, and prints one
# OK/FAILED/MISSING line per unique path.
#
# Returns 1 and prints "Error: ..." on a malformed line, an unreadable
# checksum file, a hash of the wrong length, or a missing shasum/
# sha256sum; returns 1 and prints "Verification failed: N file(s)."
# where at least one entry is MISSING or FAILED; returns 0 and prints
# "Binaries verified." where every entry matches. Where PREFIX/* has no
# entry at all after filtering, returns 0 and prints "Nothing to
# verify" instead of "Binaries verified.": a fresh clone's
# linux/checksums.sha256 ships with no entries, and no binary is installed
# until the updaters run, so this is expected rather than a failure --
# which keeps an empty checksum file from reading as success over nothing
# checked.
#
# Indexed arrays, not an associative one: macOS ships bash 3.2, and this
# function serves linux/scripts/utilities/verify-binaries.sh through the
# same shared/utilities/lib.sh, so one shape covers both rather than one
# platform getting a nicer one the other cannot use.
verify_binaries() {
    local rootdir="$1"
    local checksum_file="$2"
    local prefix="$3"

    echo "Verifying binaries against $checksum_file"

    if [ ! -f "$rootdir/$checksum_file" ]; then
        echo "Error: $checksum_file not found."
        return 1
    fi

    # Parallel indexed arrays hold one record per checksum entry:
    #   rec_path[i] / rec_hash[i] / rec_ver[i]
    local -a rec_path=() rec_hash=() rec_ver=()
    # Ordered list of unique PREFIX/* paths, in first-seen order.
    local -a upaths=()

    local line hash rest version path seen p
    while IFS= read -r line; do
        case "$line" in
            "" | \#*) continue ;;
            *) ;;
        esac
        hash="${line%%[[:space:]]*}"
        rest="${line#"$hash"}"
        rest="$(_verify_binaries_trim "$rest")"
        if [ -z "$hash" ] || [ -z "$rest" ] || [ "$rest" = "$line" ]; then
            echo "Error: Malformed checksum line: $line"
            return 1
        fi
        if [ "${#hash}" -ne 64 ]; then
            echo "Error: Invalid SHA-256 hash length: $line"
            return 1
        fi
        version="unknown"
        path="$rest"
        if [[ "$rest" == *"version="* ]]; then
            version="${rest##*version=}"
            path="${rest%version=*}"
            path="$(_verify_binaries_trim "$path")"
            version="$(_verify_binaries_trim "$version")"
        fi
        case "$path" in
            "$prefix"/*) ;;
            *) continue ;;
        esac
        rec_path+=("$path")
        rec_hash+=("$hash")
        rec_ver+=("$version")
        seen=0
        for p in ${upaths[@]+"${upaths[@]}"}; do
            if [ "$p" = "$path" ]; then
                seen=1
                break
            fi
        done
        [ "$seen" -eq 0 ] && upaths+=("$path")
    done < "$rootdir/$checksum_file"

    if [ "${#upaths[@]}" -eq 0 ]; then
        echo "Nothing to verify: no $prefix/* entries in $checksum_file."
        return 0
    fi

    local fail=0 file expected_versions expected_versions_str i
    local computed_hash matches versions
    for path in "${upaths[@]}"; do
        file="$rootdir/$path"
        expected_versions=()
        for i in "${!rec_path[@]}"; do
            [ "${rec_path[$i]}" = "$path" ] && expected_versions+=("${rec_ver[$i]}")
        done
        if [ "${#expected_versions[@]}" -gt 0 ]; then
            expected_versions_str=$(printf "%s, " "${expected_versions[@]}")
            expected_versions_str="${expected_versions_str%, }"
        else
            expected_versions_str=""
        fi
        if [ ! -f "$file" ] && [ ! -d "$file" ]; then
            if [ -n "$expected_versions_str" ]; then
                echo "$path: MISSING (expected versions: $expected_versions_str)"
            else
                echo "$path: MISSING"
            fi
            fail=$((fail + 1))
            continue
        fi
        if ! command -v shasum > /dev/null 2>&1 \
            && ! command -v sha256sum > /dev/null 2>&1; then
            echo "Error: Neither shasum nor sha256sum found."
            echo "Install coreutils or similar."
            return 1
        fi
        # A path tree_hash cannot read hashes to nothing, which matches no
        # entry and so reads FAILED.
        computed_hash="$(tree_hash "$file")" || computed_hash=""
        matches=()
        for i in "${!rec_path[@]}"; do
            if [ "${rec_path[$i]}" = "$path" ] && [ "${rec_hash[$i]}" = "$computed_hash" ]; then
                matches+=("${rec_ver[$i]}")
            fi
        done
        if [ "${#matches[@]}" -gt 0 ]; then
            versions=$(printf "%s, " "${matches[@]}")
            versions="${versions%, }"
            echo "$path: OK (version: $versions)"
        else
            if [ -n "$expected_versions_str" ]; then
                echo "$path: FAILED (expected versions: $expected_versions_str)"
            else
                echo "$path: FAILED"
            fi
            fail=$((fail + 1))
        fi
    done

    if [ "$fail" -ne 0 ]; then
        echo "Verification failed: $fail file(s)."
        return 1
    fi

    echo "Binaries verified."
}

# curl_https ARGS... -- curl, refusing every protocol but HTTPS on the
# request and on every redirect -L follows. The updaters call it in place
# of curl: the files they fetch are checked by PGP, but the index that
# picks the version, and the probes that test it, are not.
curl_https() {
    curl --proto '=https' --proto-redir '=https' "$@"
}

# refuse_while_running NAME DOING PATTERN
#
# Returns 0 where pgrep_outside_own_line, in shared/lib.sh, finds no process
# matching PATTERN, an extended regular expression. Otherwise returns 1 with
# a message: a process matches, or pgrep or ps is missing or failed, and
# then nothing says that NAME is stopped. DOING is what the caller is about
# to do, as "updating". A guard written "if pgrep" reads both failures as
# "not running". PATTERN is why this is not process_running_with, which
# compares a string.
refuse_while_running() {
    local rc=0
    pgrep_outside_own_line "$3" > /dev/null || rc=$?
    case "$rc" in
        0) echo "Error: $1 is running. Stop it before $2." ;;
        1) return 0 ;;
        *) echo "Error: cannot tell whether $1 is running: pgrep or ps is missing or failed. Not $2." ;;
    esac
    return 1
}

# refuse_downgrade INSTALLED REQUESTED ALLOW NAME
#
# Returns 1, with a message, where REQUESTED is older than INSTALLED. An
# old release still carries valid signatures, so without this an index
# listing only old releases rolls an install back to one with known
# vulnerabilities. INSTALLED is installed_version's answer, whose
# "unknown" leaves nothing to compare with. Equal versions pass:
# reinstalling a release is not a downgrade. ALLOW is 1 where the user
# passed --allow-downgrade, which skips the comparison.
# A REQUESTED that is not digits and dots is refused before any of that,
# whatever INSTALLED and ALLOW are: it is built into a URL and a file name,
# and a path separator or a space in it would reach both.
# win/scripts/utilities/compare-versions.ps1 holds the same rule for
# Windows.
refuse_downgrade() {
    local installed="$1"
    local requested="$2"
    local allow="$3"
    local name="$4"
    local re='^[0-9]+(\.[0-9]+)*$'
    local why="" i n x y
    local -a a=() b=()

    if ! [[ "$requested" =~ $re ]]; then
        echo "Refusing to install $name $requested: a version is digits" \
            "and dots."
        return 1
    fi
    if [ "$allow" = "1" ] || [ "$installed" = "unknown" ]; then
        return 0
    fi
    if ! [[ "$installed" =~ $re ]]; then
        why="it cannot be compared with the installed $installed"
    else
        IFS=. read -r -a a <<< "$installed"
        IFS=. read -r -a b <<< "$requested"
        n="${#a[@]}"
        if [ "${#b[@]}" -gt "$n" ]; then
            n="${#b[@]}"
        fi
        for ((i = 0; i < n; i++)); do
            # Compared as strings, leading zeros stripped, the longer being
            # the larger: no component overflows, where $((...)) wraps past
            # 64 bits.
            x="${a[i]:-0}"
            x="${x#"${x%%[!0]*}"}"
            y="${b[i]:-0}"
            y="${y#"${y%%[!0]*}"}"
            if [ "${#y}" -gt "${#x}" ] \
                || { [ "${#y}" -eq "${#x}" ] && [[ "$y" > "$x" ]]; }; then
                return 0
            fi
            if [ "${#y}" -lt "${#x}" ] || [[ "$y" < "$x" ]]; then
                why="it is older than the installed $installed"
                break
            fi
        done
    fi
    if [ -z "$why" ]; then
        return 0
    fi
    echo "Refusing to install $name $requested: $why."
    echo "Run again with --allow-downgrade to install it anyway."
    return 1
}
