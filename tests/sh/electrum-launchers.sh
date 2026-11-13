# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# shellcheck disable=SC2329 # check calls these functions by name
# The Electrum launchers under linux/scripts/electrum/ and
# macos/scripts/electrum/, each run from this checkout against a stand-in
# root that PORTANODE_ROOT names. Electrum there, and macOS's open(1) on
# PATH, are stand-ins that record their arguments. The socket probe's
# interpreter, python3 on Linux and perl on macOS, is a stand-in on PATH that
# exits with PROBE_STATUS. So every case runs alike on macOS and on Linux.
#
# The Linux launchers test /dev/fuse with `[`. run exports a function of that
# name to the launcher, which hands the builtin FUSE_READ in place of
# /dev/fuse after -r and FUSE_WRITE after -w, so the machine's own device
# decides nothing.

case "$0" in */*) ;; *) [ -f "$0" ] || {
    echo "$0: run this script by its path, not by a name found through PATH" >&2
    exit 1
} ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "${SCRIPT_DIR}/../lib.sh"

set -u
unset PORTANODE_ROOT STANDIN_STATUS PROBE_STATUS
TMP="$(mktemp -d)" || exit 1
TMP="$(cd "${TMP}" && pwd -P)"
trap 'rm -rf "${TMP}"' EXIT

# A space in the root, so that a command a launcher prints shows its quoting.
ROOT="${TMP}/a root"
STUBS="${TMP}/stubs"
BARE="${TMP}/bare"
RECORD="${TMP}/started"
PROBE_RECORD="${TMP}/probe"
FUSE_READ="${TMP}/fuse-read"
FUSE_WRITE="${TMP}/fuse-write"
DATADIR="${ROOT}/electrum-datadir"
APPIMAGE="${ROOT}/linux/bin/electrum.AppImage"
APP="${ROOT}/macos/bin/Electrum.app"

# stub <dir> <name> <line...>: an executable <dir>/<name> running the lines.
stub() {
    local dir="$1" name="$2"
    shift 2
    mkdir -p "${dir}"
    printf '%s\n' '#!/bin/sh' "$@" > "${dir}/${name}"
    chmod +x "${dir}/${name}"
}

# Electrum and open(1): each writes its arguments to RECORD, one per line,
# and exits with STANDIN_STATUS.
# shellcheck disable=SC2016 # expanded by the stand-in, not here
STARTS=('printf "%s\n" "$@" > "${STANDIN_RECORD}"' 'exit "${STANDIN_STATUS:-0}"')
stub "${STUBS}" open "${STARTS[@]}"
# The probe's interpreter: it writes its arguments to PROBE_RECORD, creates
# the probe at the path it is given, as the real probe's bind does, and exits
# with PROBE_STATUS.
for name in python3 perl; do
    # shellcheck disable=SC2016 # expanded by the stand-in, not here
    stub "${STUBS}" "${name}" 'printf "%s\n" "$@" > "${PROBE_RECORD}"' \
        ': > "$3"' 'exit "${PROBE_STATUS:-0}"'
done
# A PATH with what the launchers run but no python3 and no perl.
mkdir -p "${BARE}"
for tool in dirname mkdir rm; do
    ln -s "$(command -v "${tool}")" "${BARE}/${tool}"
done
cp "${STUBS}/open" "${BARE}/open"

# make_root: a new root at ROOT, with Electrum in place for both platforms.
make_root() {
    rm -rf "${ROOT}"
    mkdir -p "${ROOT}/linux" "${ROOT}/macos"
    echo 0.0.0 > "${ROOT}/VERSION"
    stub "$(dirname "${APPIMAGE}")" electrum.AppImage "${STARTS[@]}"
    stub "${APP}/Contents/MacOS" run_electrum "${STARTS[@]}"
}

# run <launcher> [NAME=value...]: runs the launcher by bash, as
# Electrum-Launcher.command and linux/Electrum-Launcher.sh run it, against
# ROOT, with STUBS first on PATH and the variables given, and prints its
# output and then its exit status on a line of its own. /dev/fuse reads as
# readable where FUSE_READ exists, and as writable where FUSE_WRITE does.
run() (
    launcher="$1"
    shift
    rm -f "${RECORD}" "${PROBE_RECORD}"
    # Defined through eval, which shellcheck does not parse: it cannot parse
    # a function named [.
    # shellcheck disable=SC2016 # expanded when [ runs
    eval '[() {
        local arg prev=""
        local -a args=()
        for arg in "$@"; do
            case "${prev} ${arg}" in
                "-r /dev/fuse") arg="${FUSE_READ}" ;;
                "-w /dev/fuse") arg="${FUSE_WRITE}" ;;
                *) ;;
            esac
            args+=("${arg}")
            prev="${arg}"
        done
        builtin [ "${args[@]}"
    }'
    export -f '['
    env PORTANODE_ROOT="${ROOT}" STANDIN_RECORD="${RECORD}" \
        PROBE_RECORD="${PROBE_RECORD}" FUSE_READ="${FUSE_READ}" \
        FUSE_WRITE="${FUSE_WRITE}" \
        PATH="${STUBS}:${PATH}" "$@" "${BASH}" "${launcher}" < /dev/null 2>&1
    echo "exit $?"
)

# flags <name>: the arguments the launcher of that name gives Electrum after
# its data directory, one per line.
flags() {
    case "$1" in
        mainnet-local-server-only) printf '%s\n' --oneserver --server localhost:50002:s ;;
        regtest) echo --regtest ;;
        testnet3) echo --testnet ;;
        testnet4) echo --testnet4 ;;
        *) ;;
    esac
}

# started <expected>: 0 where Electrum was started with the arguments
# expected, one per line.
started() {
    [ -f "${RECORD}" ] || {
        echo "  Electrum was not started"
        return 1
    }
    same "$1" "$(cat "${RECORD}")"
}

# not_started: 0 where Electrum was not started.
not_started() {
    [ ! -e "${RECORD}" ] || {
        echo "  Electrum was started"
        return 1
    }
}

# probed: 0 where the probe was given daemon_rpc_socket's path and a probe
# path in electrum-datadir, and that probe is gone.
probed() {
    local probe
    same "${DATADIR}/daemon_rpc_socket" "$(sed -n 2p "${PROBE_RECORD}")" || return 1
    probe="$(sed -n 3p "${PROBE_RECORD}")"
    contains "${probe}" "${DATADIR}/.probe." || return 1
    [ ! -e "${probe}" ] || {
        echo "  the probe ${probe} is left behind"
        return 1
    }
}

# status_is <status> <output>: 0 where the output's last line is that status.
status_is() {
    same "exit $1" "$(tail -n 1 <<< "$2")"
}

# stops <output> <error>: 0 where the output is the root, the error and exit
# status 1, the launcher having stopped at the error.
stops() {
    same "ROOTDIR is ${ROOT}"$'\n'"$2"$'\n'"exit 1" "$1"
}

# Through two symbolic links, the first relative, and by a bare name found
# through PATH, which the launcher refuses. The links are new for each
# launcher: kcov credits the lines run through a link to the file the link
# named when kcov first read it.
links_and_path() {
    local launcher="$1" what="$2" dir out links
    links="$(mktemp -d "${TMP}/links.XXXXXX")" || return 1
    mkdir "${links}/first"
    ln -s ../second "${links}/first/link"
    ln -s "${launcher}" "${links}/second"
    out="$(run "${links}/first/link")"
    check "${what} started through symbolic links finds this checkout's script" \
        status_is 0 "${out}"
    check "${what} started through symbolic links starts Electrum" \
        test -f "${RECORD}"

    dir="$(dirname "${launcher}")"
    # bash looks for a script given by a bare name in the current directory,
    # then in PATH.
    out="$(cd "${TMP}" && run "$(basename "${launcher}")" \
        PATH="${dir}:${STUBS}:${PATH}")"
    check "${what} found through PATH refuses to run" \
        contains "${out}" "run this script by its path"
    check "${what} found through PATH exits 1" status_is 1 "${out}"
    check "${what} found through PATH does not start Electrum" not_started
}

for name in mainnet mainnet-local-server-only regtest testnet3 testnet4; do
    launcher="${REPO}/linux/scripts/electrum/${name}.sh"
    what="linux ${name}.sh"
    args="$(printf '%s\n' --dir "${DATADIR}" && flags "${name}")"
    rest=""
    while IFS= read -r flag; do
        rest="${rest} ${flag}"
    done < <(flags "${name}")
    : > "${FUSE_READ}"
    : > "${FUSE_WRITE}"

    make_root
    rm -r "${ROOT}/linux/bin"
    out="$(run "${launcher}")"
    check "${what} without linux/bin names it and exits 1" stops "${out}" \
        "Error: Binaries directory not found at linux/bin"

    make_root
    rm "${APPIMAGE}"
    out="$(run "${launcher}")"
    check "${what} without the AppImage names it and exits 1" stops "${out}" \
        "Error: Binary not found at linux/bin/electrum.AppImage"

    make_root
    chmod -x "${APPIMAGE}"
    out="$(run "${launcher}")"
    check "${what} with an AppImage not executable says so and exits 1" \
        stops "${out}" \
        "Error: Binary not executable at linux/bin/electrum.AppImage"
    check "${what} with an AppImage not executable does not start it" \
        not_started

    make_root
    rm "${FUSE_READ}" "${FUSE_WRITE}"
    out="$(run "${launcher}")"
    check "${what} without /dev/fuse says so" contains "${out}" \
        "Error: /dev/fuse is not available to this user."
    check "${what} without /dev/fuse prints the command that needs none" \
        same \
        "  ${APPIMAGE// /\\ } --appimage-extract-and-run --dir ${DATADIR// /\\ }${rest}" \
        "$(tail -n 2 <<< "${out}" | head -n 1)"
    check "${what} without /dev/fuse exits 1" status_is 1 "${out}"
    check "${what} without /dev/fuse does not start Electrum" not_started
    check "${what} without /dev/fuse stops before electrum-datadir" \
        test ! -e "${DATADIR}"

    # Each half of the test stops the launcher alone.
    for half in read write; do
        make_root
        : > "${FUSE_READ}"
        : > "${FUSE_WRITE}"
        if [ "${half}" = read ]; then
            rm "${FUSE_READ}"
        else
            rm "${FUSE_WRITE}"
        fi
        out="$(run "${launcher}")"
        check "${what} with /dev/fuse not open to ${half} says so" \
            contains "${out}" "Error: /dev/fuse is not available to this user."
        check "${what} with /dev/fuse not open to ${half} exits 1" \
            status_is 1 "${out}"
        check "${what} with /dev/fuse not open to ${half} does not start Electrum" \
            not_started
    done
    : > "${FUSE_READ}"
    : > "${FUSE_WRITE}"

    make_root
    : > "${DATADIR}"
    out="$(run "${launcher}")"
    check "${what} where electrum-datadir cannot be created says so" \
        contains "${out}" "Error: could not create electrum-datadir"
    check "${what} where electrum-datadir cannot be created exits 1" \
        status_is 1 "${out}"
    check "${what} where electrum-datadir cannot be created does not start it" \
        not_started
    check "${what} where electrum-datadir cannot be created stops before the probe" \
        test ! -e "${PROBE_RECORD}"

    make_root
    out="$(run "${launcher}")"
    check "${what} prints the root" contains "${out}" "ROOTDIR is ${ROOT}"
    check "${what} starts Electrum on electrum-datadir" started "${args}"
    check "${what} exits 0 where Electrum does" status_is 0 "${out}"
    check "${what} probes daemon_rpc_socket's filesystem" probed
    check "${what} prints no note where the probe binds" \
        same "ROOTDIR is ${ROOT}"$'\n'"exit 0" "${out}"

    out="$(run "${launcher}" STANDIN_STATUS=3)"
    check "${what} exits as Electrum does" status_is 3 "${out}"

    make_root
    out="$(run "${launcher}" PROBE_STATUS=4)"
    check "${what} where the bind is refused says so" contains "${out}" \
        "Error: electrum-datadir cannot hold a unix domain socket."
    check "${what} where the bind is refused prints the command to run" \
        same "  ${APPIMAGE// /\\ } --dir <path-on-another-filesystem>${rest}" \
        "$(tail -n 2 <<< "${out}" | head -n 1)"
    check "${what} where the bind is refused exits 1" status_is 1 "${out}"
    check "${what} where the bind is refused does not start Electrum" \
        not_started
    check "${what} where the bind is refused removes the probe" probed

    make_root
    out="$(run "${launcher}" PROBE_STATUS=2)"
    check "${what} where the path is too long for a socket says so" \
        contains "${out}" "Note: a unix domain socket address cannot hold a path as long as ${DATADIR}/daemon_rpc_socket"
    check "${what} where the path is too long still starts Electrum" \
        started "${args}"

    make_root
    out="$(run "${launcher}" PROBE_STATUS=1)"
    check "${what} where the probe fails otherwise says it did not run" \
        contains "${out}" "Note: the unix-socket check for electrum-datadir did not run."
    check "${what} where the probe fails otherwise still starts Electrum" \
        started "${args}"

    make_root
    out="$(run "${launcher}" PATH="${BARE}")"
    check "${what} without python3 says the probe is skipped" \
        contains "${out}" "Note: python3 not found; skipping the unix-socket check"
    check "${what} without python3 still starts Electrum" started "${args}"

    make_root
    links_and_path "${launcher}" "${what}"
done

for name in mainnet mainnet-local-server-only regtest testnet3 testnet4; do
    launcher="${REPO}/macos/scripts/electrum/${name}.command"
    what="macos ${name}.command"
    args="$(printf '%s\n' -n "${APP}" --args --dir "${DATADIR}" && flags "${name}")"

    make_root
    rm -r "${ROOT}/macos/bin"
    out="$(run "${launcher}")"
    check "${what} without macos/bin names it and exits 1" stops "${out}" \
        "Error: Binaries directory not found at macos/bin"

    make_root
    chmod -x "${APP}/Contents/MacOS/run_electrum"
    out="$(run "${launcher}")"
    check "${what} with no executable in the bundle says so and exits 1" \
        stops "${out}" \
        "Error: binary not found in macos/bin/Electrum.app/Contents/MacOS"
    check "${what} with no executable in the bundle does not open it" \
        not_started

    make_root
    mv "${APP}/Contents/MacOS/run_electrum" "${APP}/Contents/MacOS/Electrum"
    out="$(run "${launcher}")"
    check "${what} opens a bundle holding Electrum alone" started "${args}"

    make_root
    : > "${DATADIR}"
    out="$(run "${launcher}")"
    check "${what} where electrum-datadir cannot be created says so" \
        contains "${out}" "Error: could not create electrum-datadir"
    check "${what} where electrum-datadir cannot be created exits 1" \
        status_is 1 "${out}"
    check "${what} where electrum-datadir cannot be created does not open it" \
        not_started
    check "${what} where electrum-datadir cannot be created stops before the probe" \
        test ! -e "${PROBE_RECORD}"

    make_root
    out="$(run "${launcher}")"
    check "${what} prints the root" contains "${out}" "ROOTDIR is ${ROOT}"
    check "${what} opens the bundle on electrum-datadir" started "${args}"
    check "${what} exits 0 where open does" status_is 0 "${out}"
    check "${what} probes daemon_rpc_socket's filesystem" probed
    check "${what} prints no note where the probe binds" \
        same "ROOTDIR is ${ROOT}"$'\n'"exit 0" "${out}"

    out="$(run "${launcher}" STANDIN_STATUS=3)"
    check "${what} exits as open does" status_is 3 "${out}"

    make_root
    out="$(run "${launcher}" PROBE_STATUS=1)"
    check "${what} where the bind is refused says so" contains "${out}" \
        "Error: electrum-datadir cannot hold a unix domain socket."
    check "${what} where the bind is refused exits 1" status_is 1 "${out}"
    check "${what} where the bind is refused does not open the bundle" \
        not_started
    check "${what} where the bind is refused removes the probe" probed

    make_root
    out="$(run "${launcher}" PROBE_STATUS=2)"
    check "${what} where the path is too long for a socket says so" \
        contains "${out}" "Note: a unix domain socket address cannot hold a path as long as ${DATADIR}/daemon_rpc_socket"
    check "${what} where the path is too long still opens the bundle" \
        started "${args}"

    make_root
    out="$(run "${launcher}" PROBE_STATUS=3)"
    check "${what} where the probe fails otherwise says it did not run" \
        contains "${out}" "Note: the unix-socket check for electrum-datadir did not run."
    check "${what} where the probe fails otherwise still opens the bundle" \
        started "${args}"

    make_root
    out="$(run "${launcher}" PATH="${BARE}")"
    check "${what} without perl says the probe is skipped" \
        contains "${out}" "Note: perl not found; skipping the unix-socket check"
    check "${what} without perl still opens the bundle" started "${args}"

    make_root
    links_and_path "${launcher}" "${what}"
done

finish
