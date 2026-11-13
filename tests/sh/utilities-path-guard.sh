# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# The Linux and macOS utilities, each started by a bare name that bash finds
# through PATH, which each refuses. Every utility but lib.sh, a library
# sourced rather than run, carries the guard. Past it, a utility takes the
# current directory for its own and sources lib.sh from there or from its
# parent, so a stand-in lib.sh in each records that the utility went past its
# guard, and exits 2.

case "$0" in */*) ;; *) [ -f "$0" ] || {
    echo "$0: run this script by its path, not by a name found through PATH" >&2
    exit 1
} ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "${SCRIPT_DIR}/../lib.sh"

set -u
TMP="$(mktemp -d)" || exit 1
TMP="$(cd "${TMP}" && pwd -P)"
trap 'rm -rf "${TMP}"' EXIT

REFUSAL="run this script by its path, not by a name found through PATH"
RECORD="${TMP}/lib-sourced"
mkdir "${TMP}/cwd"
for lib in "${TMP}/lib.sh" "${TMP}/cwd/lib.sh"; do
    printf ': >> "%s"\nexit 2\n' "${RECORD}" > "${lib}"
done

for platform in linux macos; do
    dir="${REPO}/${platform}/scripts/utilities"
    for script in "${dir}"/*.sh; do
        name="$(basename "${script}")"
        [ "${name}" != lib.sh ] || continue
        what="${platform}/scripts/utilities/${name}"
        rm -f "${RECORD}"
        # bash looks for a script given by a bare name in the current
        # directory, then in PATH.
        out="$(
            cd "${TMP}/cwd" && env PATH="${dir}:${PATH}" \
                "${BASH}" "${name}" 2>&1
            echo "exit $?"
        )"
        check "${what}: found through PATH, it refuses to run" \
            same "${name}: ${REFUSAL}" "$(sed '$d' <<< "${out}")"
        check "${what}: found through PATH, it exits 1" \
            same "exit 1" "$(tail -n 1 <<< "${out}")"
        check "${what}: found through PATH, it sources no lib.sh" \
            test ! -e "${RECORD}"
    done
done

finish
