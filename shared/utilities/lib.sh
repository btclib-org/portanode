#!/bin/bash
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

debug_list_dir() {
    local dir="$1"
    local entries
    # find exits 1 when $dir does not exist, and pipefail (set by every
    # caller) carries that through the pipeline into the assignment; "||
    # true" keeps a missing directory a listing (of nothing) rather than a
    # death of the caller, which is the case this helper exists for.
    entries="$(find "$dir" -mindepth 1 -maxdepth 1 -exec basename {} \; \
        2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')" || true
    # The ROOTDIR prefix is stripped because the folder is mounted at a
    # different point on every machine it is plugged into, so a message
    # quoting the mount point tells the reader where this run happened
    # rather than which file in the folder is meant. The strip is applied
    # where a message would otherwise print an absolute path, which is
    # not every message here that names one: verify_binaries prints
    # locals that are relative already, and install_verified's source is
    # a temporary extraction directory outside the folder, a path
    # CLAUDE.md's ROOTDIR convention does not reach -- so neither is
    # stripped.
    echo "Debug: ${dir#"$ROOTDIR"/} contents: $entries"
}

# tree_hash PATH — deterministic content hash of a file or of every regular
# file under a directory. AppleDouble sidecars (._*) are ignored so a source on
# APFS and a copy on exFAT (which materialises ._* files) compare equal.
#
# The checksum command is picked at run time rather than fixed to shasum:
# macOS always has shasum, but a bare Linux install is not guaranteed to
# (it ships from Perl's Digest::SHA, not from coreutils), where sha256sum
# always is. tree_hash makes that pick itself rather than taking a checksum
# command as an argument, so a caller hands it a path and repeats nothing.
tree_hash() {
    local path="$1"
    local -a sha_cmd
    if command -v shasum >/dev/null 2>&1; then
        sha_cmd=(shasum -a 256)
    elif command -v sha256sum >/dev/null 2>&1; then
        sha_cmd=(sha256sum)
    else
        echo "Error: neither shasum nor sha256sum found." >&2
        return 1
    fi
    if [ -d "$path" ]; then
        ( cd "$path" && find . -type f ! -name '._*' -print0 \
            | LC_ALL=C sort -z \
            | xargs -0 "${sha_cmd[@]}" 2>/dev/null \
            | "${sha_cmd[@]}" | awk '{print $1}' )
    else
        "${sha_cmd[@]}" "$path" 2>/dev/null | awk '{print $1}'
    fi
}

# install_verified SRC DEST — replace DEST with a copy of SRC, then verify the
# copy is byte-identical (content) and retry on mismatch. Defends against
# removable filesystems (notably macOS's fskit exFAT) that can silently corrupt
# files on write. Returns non-zero if still corrupt after several attempts.
install_verified() {
    local src="$1" dest="$2" want got i
    want="$(tree_hash "$src")"
    if [ -z "$want" ]; then
        echo "Error: cannot hash source $src"
        return 1
    fi
    for i in 1 2 3 4 5; do
        rm -rf "$dest"
        cp -R "$src" "$dest"
        sync 2>/dev/null || true
        got="$(tree_hash "$dest")"
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
verify_sha256sums() {
    local tmp_dir="$1"
    local sums_file="$2"
    shift 2
    local filtered="${sums_file}.filtered"
    local -a grep_args=()
    local name
    for name in "$@"; do
        grep_args+=(-e "$name")
    done
    grep -F "${grep_args[@]}" "$tmp_dir/$sums_file" > "$tmp_dir/$filtered"
    if command -v shasum >/dev/null 2>&1; then
        (cd "$tmp_dir" && shasum -a 256 -c "$filtered")
    elif command -v sha256sum >/dev/null 2>&1; then
        (cd "$tmp_dir" && sha256sum -c "$filtered")
    else
        echo "Error: Neither shasum nor sha256sum found."
        return 1
    fi
}

# pgp_verify_or_fail SIG_FILE DATA_FILE LABEL OUT_VAR [FPR_FILE]
#
# Verifies DATA_FILE against the detached SIG_FILE. FAILS CLOSED: returns
# non-zero (so the caller aborts the install) unless a good signature is found.
# If FPR_FILE is given and non-empty, additionally requires a VALIDSIG whose
# fingerprint is listed there (key pinning); otherwise any GOODSIG is accepted.
# On success sets OUT_VAR to 1 (the caller uses it to gate checksum recording).
#
# Set PORTANODE_ALLOW_UNVERIFIED=1 to bypass verification entirely (installs
# unauthenticated binaries — NOT recommended, intended only as an escape hatch).
pgp_verify_or_fail() {
    local sig_file="$1"
    local data_file="$2"
    local label="$3"
    local out_var="$4"
    local fpr_file="${5:-}"

    if [ -n "$out_var" ]; then
        printf -v "$out_var" '%s' 0
    fi

    if [ "${PORTANODE_ALLOW_UNVERIFIED:-0}" = "1" ]; then
        echo "Warning: PORTANODE_ALLOW_UNVERIFIED=1 set; skipping PGP" \
             "verification of ${label}. Installing UNAUTHENTICATED binaries."
        return 0
    fi

    if ! command -v gpg >/dev/null 2>&1; then
        echo "Error: gpg not found; cannot verify ${label}."
        echo "Install gpg (e.g. 'brew install gnupg') and import the signing" \
             "key, or set PORTANODE_ALLOW_UNVERIFIED=1 to bypass (NOT" \
             "recommended)."
        return 1
    fi

    echo "Verifying ${label} signature..."
    local status_file
    status_file="$(mktemp)"
    gpg --status-fd 1 --verify "$sig_file" "$data_file" 1> "$status_file" \
        2>/dev/null || true

    # A status file that is absent or empty is gpg's answer lost rather
    # than a signature refused, and the greps below cannot separate the
    # two: on a name no file answers to, grep exits non-zero exactly as
    # it does on a file holding no GOODSIG. Measured on ubuntu-latest,
    # mktemp fails where TMPDIR names a directory that is missing or not
    # writable; status_file is then empty, the redirection above is never
    # opened and gpg does not run at all, which is why its exit status is
    # not what is read here. Where gpg does run it writes a status line
    # for a signature it refuses as much as for one it accepts, and the
    # tests below are what read that. -s rather than -e, an empty file
    # answering no more than a missing one; no case measured here
    # separates the two.
    if [ ! -s "$status_file" ]; then
        echo "Error: gpg's status output for ${label} was not read;" \
             "whether the signature is good is unknown."
        rm -f "$status_file"
        return 1
    fi

    if grep -q '^\[GNUPG:\] BADSIG' "$status_file"; then
        echo "Error: BAD PGP signature on ${label}."
        rm -f "$status_file"
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
    # not imported and a signature file that cannot be opened both leave
    # 2. Nor does the FAILURE line, which reads "verify" for a signature
    # file that is missing, empty or unreadable and "gpg-exit" for one
    # holding something that is not a signature and for a file to check
    # that cannot be opened; a test on it would leave those last two on
    # the keyring message.
    # Measured with gpg 2.5.21 on macOS and gpg 2.4.4 on ubuntu-latest:
    # NEWSIG is present for a good signature, for a tampered one and for
    # a key that is not imported, and absent where the signature file is
    # missing, empty, unreadable or not a signature and where the file it
    # signs is missing or unreadable.
    # The advice below names no cause, several reaching it alike. A
    # signature file that is present and readable and merely not a
    # signature is one of them -- the shape a download answering 200 with
    # an error page leaves -- so advice to check presence and readability
    # would send that reader to confirm two things already true.
    if ! grep -q '^\[GNUPG:\] NEWSIG' "$status_file"; then
        echo "Error: gpg found no PGP signature to check on ${label}."
        echo "Check the signature file and the file it signs."
        rm -f "$status_file"
        return 1
    fi

    if ! grep -q '^\[GNUPG:\] GOODSIG' "$status_file"; then
        echo "Error: no valid PGP signature on ${label}" \
             "(is the signer's key imported?)."
        echo "Import the signing key, or set PORTANODE_ALLOW_UNVERIFIED=1 to" \
             "bypass (NOT recommended)."
        rm -f "$status_file"
        return 1
    fi

    # Optional fingerprint pinning: require a VALIDSIG from a listed key. The
    # VALIDSIG status line carries both the signing-key and primary-key
    # fingerprints, so match a pinned fingerprint anywhere on those lines.
    if [ -n "$fpr_file" ] && [ -s "$fpr_file" ] && \
       grep -qiE '^[[:space:]]*[0-9A-Fa-f]{40}[[:space:]]*$' "$fpr_file"; then
        local validsig_lines fpr matched=0 line
        validsig_lines="$(grep '^\[GNUPG:\] VALIDSIG' "$status_file")"
        while IFS= read -r line; do
            case "$line" in ''|\#*) continue ;; esac
            fpr="$(echo "$line" | tr -d '[:space:]')"
            [ ${#fpr} -eq 40 ] || continue
            if echo "$validsig_lines" | grep -qi -- "$fpr"; then
                matched=1
                break
            fi
        done < "$fpr_file"
        if [ "$matched" -ne 1 ]; then
            echo "Error: ${label} is signed, but not by a pinned key listed" \
                 "in $(basename "$fpr_file")."
            rm -f "$status_file"
            return 1
        fi
    fi

    rm -f "$status_file"
    if [ -n "$out_var" ]; then
        printf -v "$out_var" '%s' 1
    fi
    return 0
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

    if [ ! -f "$file" ]; then
        echo "Error: checksum source not found at ${file#"$ROOTDIR"/}"
        debug_list_dir "$(dirname "$file")"
        exit 1
    fi

    if command -v shasum >/dev/null 2>&1; then
        hash="$(shasum -a 256 "$file" | awk '{print $1}')" || hash=""
    elif command -v sha256sum >/dev/null 2>&1; then
        hash="$(sha256sum "$file" | awk '{print $1}')" || hash=""
    else
        echo "Warning: shasum/sha256sum not found;"
        echo "checksums not updated."
        return 0
    fi

    # shasum and sha256sum write to stderr and print nothing on stdout
    # for a file they cannot read, so awk prints nothing and hash is
    # empty. The entry built below would then carry an empty hash field
    # into the append-only checksums.sha256, where it can neither be
    # rewritten nor ever match: verify_checksum_entry's awk reads such a
    # line's path as $1, and no real hash equals a path. A chmod 000
    # file and one carrying a "deny read" ACL both produce that empty
    # capture; a full volume does not, a read needing no free space.
    #
    # What is tested is the result rather than the status, because
    # without pipefail the assignment's status is awk's, which is 0. And
    # "|| hash=''" above is what lets the test run at all: under errexit
    # and pipefail together the command substitution carries shasum's
    # own non-zero status and the caller dies at the assignment, with
    # only shasum's stderr behind it, where a "||" list suppresses
    # errexit for it and leaves the refusal here, named and returned.
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

    # */checksums.sha256 is append-only: a rollback verifies its backup
    # binary against an entry a previous install recorded for this same
    # entry_path, so rewriting that entry to the current hash would leave
    # the backup unrecognized and the rollback refusing it. An earlier
    # entry stays findable by the binary it describes:
    # verify_checksum_entry and installed_version select on hash and
    # path together.
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

    if [ ! -f "$file" ]; then
        echo "Error: ${label} not found at ${file#"$ROOTDIR"/}"
        debug_list_dir "$(dirname "$file")"
        return 2
    fi
    if [ ! -f "$checksum_file" ]; then
        echo "Error: ${checksum_file#"$ROOTDIR"/} not found."
        debug_list_dir "$(dirname "$checksum_file")"
        return 2
    fi

    if command -v shasum >/dev/null 2>&1; then
        hash="$(shasum -a 256 "$file" | awk '{print $1}')"
    elif command -v sha256sum >/dev/null 2>&1; then
        hash="$(sha256sum "$file" | awk '{print $1}')"
    else
        echo "Error: Neither shasum nor sha256sum found."
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
# the checksums.sha256 entry matching FILE's current hash, for a --dry-run
# plan's "currently installed" line. Echoes "unknown" rather than failing:
# nothing here gates an install, so a missing file or an unrecorded hash is
# reported, not an error.
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

    if command -v shasum >/dev/null 2>&1; then
        hash="$(shasum -a 256 "$file" | awk '{print $1}')"
    elif command -v sha256sum >/dev/null 2>&1; then
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
# path is under "PREFIX/", then hashes each such file under ROOTDIR and
# prints one OK/FAILED/MISSING line per unique path.
#
# Returns 1 and prints "Error: ..." on a malformed line, an unreadable
# checksum file, a hash of the wrong length, or a missing shasum/
# sha256sum; returns 1 and prints "Verification failed: N file(s)."
# where at least one entry is MISSING or FAILED; returns 0 and prints
# "Binaries verified." where every entry matches. Where PREFIX/* has no
# entry at all after filtering, returns 0 and prints "Nothing to
# verify" instead of "Binaries verified.": a fresh clone's
# linux/checksums.sha256 ships with no entries, and CLAUDE.md's own "a
# fresh clone launches nothing until the updaters have run" makes that
# the expected state there, not a failure -- which keeps an empty
# checksum file from reading as success over nothing checked.
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
            ""|\#*) continue ;;
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
        if [ ! -f "$file" ]; then
            if [ -n "$expected_versions_str" ]; then
                echo "$path: MISSING (expected versions: $expected_versions_str)"
            else
                echo "$path: MISSING"
            fi
            fail=$((fail + 1))
            continue
        fi
        if command -v shasum >/dev/null 2>&1; then
            computed_hash="$(shasum -a 256 "$file" | awk '{print $1}')"
        elif command -v sha256sum >/dev/null 2>&1; then
            computed_hash="$(sha256sum "$file" | awk '{print $1}')"
        else
            echo "Error: Neither shasum nor sha256sum found."
            echo "Install coreutils or similar."
            return 1
        fi
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
