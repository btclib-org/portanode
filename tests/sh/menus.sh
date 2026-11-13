# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# The menus and their entries: the three launchers at the root, which open
# the menu of the platform they run on, and the menus they open, Linux's
# under linux/ and macOS's .command files at the root. Each runs from this
# checkout against a stand-in root that PORTANODE_ROOT names. There every
# script a menu can start is a stand-in that prints its path under the root
# and exits with STANDIN_STATUS, 0 where that is unset. A stand-in uname on
# PATH tells a root launcher which platform it runs on, so every case runs
# alike on macOS and on Linux. tests/sh/launchers.sh runs the root launchers
# against this checkout's own menus.

case "$0" in */*) ;; *) [ -f "$0" ] || {
    echo "$0: run this script by its path, not by a name found through PATH" >&2
    exit 1
} ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "${SCRIPT_DIR}/../lib.sh"

set -u
unset PORTANODE_ROOT STANDIN_STATUS
TMP="$(mktemp -d)" || exit 1
TMP="$(cd "${TMP}" && pwd -P)"
trap 'rm -rf "${TMP}"' EXIT

# entries <Bitcoin|Electrum|Utilities> <linux|macos>: the script each entry
# of that menu starts, relative to the root, in the order of the entries.
entries() {
    local dir ext=.sh names who
    case "$1" in
        Bitcoin)
            dir=bitcoin
            names="mainnet-8333-qt testnet3-18333-qt testnet4-48333-qt"
            for who in 18444-Alice 18555-Bob 18666-Carol; do
                names="${names} regtest-${who}-qt regtest-${who}-qt-clean"
                names="${names} regtest-${who}-cli regtest-${who}-cli-clean"
            done
            [ "$2" = linux ] || ext=.command
            ;;
        Electrum)
            dir=electrum
            names="mainnet testnet3 testnet4 regtest mainnet-local-server-only"
            [ "$2" = linux ] || ext=.command
            ;;
        Utilities)
            dir=utilities
            names="update-bitcoin update-electrum rollback-bitcoin"
            names="${names} rollback-electrum verify-binaries validate-setup"
            names="${names} set-permissions health-check monitor-bitcoin-log"
            names="${names} rotate-bitcoin-log clean-artifacts"
            ;;
        *) return 1 ;;
    esac
    local name
    for name in ${names}; do
        printf '%s/scripts/%s/%s%s\n' "$2" "${dir}" "${name}" "${ext}"
    done
}

# labels <Bitcoin|Electrum|Utilities> <linux|macos>: the label each entry
# of that menu shows, in the order of the entries, the order entries gives
# their scripts in.
labels() {
    local who
    case "$1" in
        Bitcoin)
            printf '%s\n' "Mainnet (GUI)" "Testnet3 (GUI)" "Testnet4 (GUI)"
            for who in Alice Bob Carol; do
                printf '%s\n' "Regtest ${who} (GUI)" "Regtest ${who} (GUI, clean)" \
                    "Regtest ${who} (CLI)" "Regtest ${who} (CLI, clean)"
            done
            ;;
        Electrum)
            printf '%s\n' Mainnet Testnet3 Testnet4 Regtest \
                "Mainnet (local server only)"
            ;;
        Utilities)
            printf '%s\n' "Update Bitcoin Version" "Update Electrum Version" \
                "Rollback Last Bitcoin Update" "Rollback Last Electrum Update" \
                "Verify binaries" "Validate setup" "Set permissions" \
                "Health check" "Monitor Bitcoin log" "Rotate Bitcoin log"
            if [ "$2" = linux ]; then
                echo "Clean Linux artifacts"
            else
                echo "Clean macOS artifacts"
            fi
            ;;
        *) return 1 ;;
    esac
}

# make_root <dir>: a folder resolve_root accepts, with no script in it.
make_root() {
    mkdir -p "$1/linux" "$1/macos"
    echo 0.0.0 > "$1/VERSION"
}

# standin <path>: a script that prints its path under PORTANODE_ROOT and
# exits with STANDIN_STATUS.
standin() {
    mkdir -p "$(dirname "$1")"
    # shellcheck disable=SC2016 # expanded by the stand-in, not here
    printf '%s\n' 'printf "ran %s\n" "${0#"${PORTANODE_ROOT}/"}"' \
        'exit "${STANDIN_STATUS:-0}"' > "$1"
}

# stub <dir> <name> <line...>: an executable <dir>/<name> running the lines.
stub() {
    local dir="$1" name="$2"
    shift 2
    mkdir -p "${dir}"
    printf '%s\n' '#!/bin/sh' "$@" > "${dir}/${name}"
    chmod +x "${dir}/${name}"
}

# chain <target>: a relative symlink to an absolute one to <target>, so
# that a script started through it has resolve_symlink follow both kinds.
# It prints the path of the first link.
chain() {
    local dir
    dir="$(mktemp -d "${TMP}/link.XXXXXX")" || return 1
    ln -s "$1" "${dir}/absolute"
    ln -s absolute "${dir}/relative"
    printf '%s\n' "${dir}/relative"
}

# run <input> <command...>: feeds <input> to the command and prints its
# output, then its exit status on a line of its own. A menu's prompt ends
# with no newline, hence the one before the status.
run() {
    local input="$1" status
    shift
    printf '%b' "${input}" | "$@" 2>&1
    status=$?
    printf '\nexit %s\n' "${status}"
}

ROOT="${TMP}/root"
EMPTY="${TMP}/empty"
make_root "${ROOT}"
make_root "${EMPTY}"
for name in Bitcoin Electrum Utilities; do
    standin "${ROOT}/linux/${name}-Launcher.sh"
    standin "${ROOT}/${name}-Launcher.command"
    for platform in linux macos; do
        while IFS= read -r rel; do
            standin "${ROOT}/${rel}"
        done < <(entries "${name}" "${platform}")
    done
done

stub "${TMP}/Linux" uname 'echo Linux'
stub "${TMP}/Darwin" uname 'echo Darwin'
stub "${TMP}/MINGW" uname 'echo MINGW64_NT-10.0-19045'
# shellcheck disable=SC2016 # expanded by the stub, not here
stub "${TMP}/MINGW" cmd.exe 'printf "cmd.exe"' 'printf " [%s]" "$@"' 'echo'

# The root launchers: each opens the menu of the platform uname names, and
# stops with a message where that menu is missing. Each is started through
# a chain of symlinks where it opens its menu.
for name in Bitcoin Electrum Utilities; do
    launcher="${REPO}/${name}-Launcher.sh"
    for pair in "Linux linux/${name}-Launcher.sh" \
        "Darwin ${name}-Launcher.command"; do
        platform="${pair%% *}"
        menu="${pair#* }"
        link="$(chain "${launcher}")" || exit 1
        out="$(run '' env PATH="${TMP}/${platform}:${PATH}" \
            PORTANODE_ROOT="${ROOT}" "${BASH}" "${link}")"
        check "${name}-Launcher.sh on ${platform} opens ${menu}" \
            same "$(printf 'ran %s\n\nexit 0' "${menu}")" "${out}"
        out="$(run '' env PATH="${TMP}/${platform}:${PATH}" \
            PORTANODE_ROOT="${EMPTY}" "${BASH}" "${launcher}")"
        check "${name}-Launcher.sh on ${platform} without ${menu} says so" \
            contains "${out}" "Script not found: ${menu}"
        check "${name}-Launcher.sh on ${platform} without ${menu} exits 1" \
            same "exit 1" "$(tail -n 1 <<< "${out}")"
    done

    touch "${ROOT}/${name}-Launcher.bat"
    out="$(run '' env PATH="${TMP}/MINGW:${PATH}" \
        PORTANODE_ROOT="${ROOT}" "${BASH}" "${launcher}")"
    check "${name}-Launcher.sh in Git Bash hands ${name}-Launcher.bat to cmd.exe" \
        same "$(printf 'cmd.exe [/c] ["%s\\%s-Launcher.bat"]\n\nexit 0' \
            "${ROOT}" "${name}")" "${out}"
    out="$(run '' env PATH="${TMP}/MINGW:${PATH}" \
        PORTANODE_ROOT="${EMPTY}" "${BASH}" "${launcher}")"
    check "${name}-Launcher.sh in Git Bash without ${name}-Launcher.bat says so" \
        contains "${out}" "Script not found: ${name}-Launcher.bat"
    check "${name}-Launcher.sh in Git Bash without ${name}-Launcher.bat exits 1" \
        same "exit 1" "$(tail -n 1 <<< "${out}")"
done

# The platform menus. Each is started through a chain of symlinks and given
# every entry in turn, then the number after the last, then an empty line.
# A stand-in's line follows the prompt, or a line of its own where an entry
# starts a second script.
for name in Bitcoin Electrum Utilities; do
    for platform in linux macos; do
        if [ "${platform}" = linux ]; then
            menu="linux/${name}-Launcher.sh"
        else
            menu="${name}-Launcher.command"
        fi
        expected="$(entries "${name}" "${platform}")"
        count="$(wc -l <<< "${expected}" | tr -d ' ')"

        while IFS= read -r rel; do
            check "${menu}: ${rel} is in the tree" test -f "${REPO}/${rel}"
        done <<< "${expected}"

        link="$(chain "${REPO}/${menu}")" || exit 1
        out="$(run "$(seq "$((count + 1))")\n\n" env PORTANODE_ROOT="${ROOT}" \
            "${BASH}" "${link}")"
        check "${menu}: started through two symlinks, it names the root" \
            contains "${out}" "${name} Launcher (${ROOT})"
        ran="$(sed -n 's/^\(Select: \)\{0,1\}ran //p' <<< "${out}")"
        shown="$(sed -n '/^Select: /q; /^[0-9][0-9]*) /p' <<< "${out}")"
        k=0
        while IFS= read -r rel; do
            k=$((k + 1))
            label="$(labels "${name}" "${platform}" | sed -n "${k}p")"
            check "${menu}: entry ${k} reads ${label}" \
                same "${k}) ${label}" "$(sed -n "${k}p" <<< "${shown}")"
            check "${menu}: entry ${k} starts ${rel}" \
                same "${rel}" "$(sed -n "${k}p" <<< "${ran}")"
        done <<< "${expected}"
        check "${menu}: it shows these entries and 0) Exit, no other" \
            same "$((count + 1))" "$(grep -c . <<< "${shown}")"
        check "${menu}: 0) Exit comes last" \
            same "0) Exit" "$(tail -n 1 <<< "${shown}")"
        check "${menu}: no other script starts" \
            same "${count}" "$(grep -c . <<< "${ran}")"
        check "${menu}: the number after the last entry is refused" \
            contains "${out}" "Invalid selection."
        check "${menu}: an empty line exits 0" \
            same "exit 0" "$(tail -n 1 <<< "${out}")"

        first="$(head -n 1 <<< "${expected}")"
        out="$(run '1\n0\n' env PORTANODE_ROOT="${ROOT}" STANDIN_STATUS=3 \
            "${BASH}" "${REPO}/${menu}")"
        check "${menu}: an entry that fails is reported" \
            contains "${out}" "Command failed (exit 3)."
        check "${menu}: after a failed entry, 0 exits 0" \
            same "exit 0" "$(tail -n 1 <<< "${out}")"

        out="$(run '1\n0\n' env PORTANODE_ROOT="${EMPTY}" \
            "${BASH}" "${REPO}/${menu}")"
        check "${menu}: an entry whose script is missing says so" \
            contains "${out}" "Script not found: ${first}"
        check "${menu}: after a missing script, 0 exits 0" \
            same "exit 0" "$(tail -n 1 <<< "${out}")"
    done
done

# bash looks for a script given by a bare name in the current directory,
# then in PATH. Found through PATH, each launcher and menu refuses to run.
for menu in Bitcoin-Launcher.sh Electrum-Launcher.sh Utilities-Launcher.sh \
    Bitcoin-Launcher.command Electrum-Launcher.command \
    Utilities-Launcher.command linux/Bitcoin-Launcher.sh \
    linux/Electrum-Launcher.sh linux/Utilities-Launcher.sh; do
    dir="$(dirname "${REPO}/${menu}")"
    out="$(cd "${TMP}" && run '' env PATH="${dir}:${PATH}" \
        "${BASH}" "$(basename "${menu}")")"
    check "${menu}: found through PATH, it refuses to run" \
        contains "${out}" "run this script by its path"
    check "${menu}: found through PATH, it exits 1" \
        same "exit 1" "$(tail -n 1 <<< "${out}")"
done

finish
