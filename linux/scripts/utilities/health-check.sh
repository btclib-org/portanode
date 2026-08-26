#!/bin/bash
# Health check for PortaNode (Linux)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=linux/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"

echo "Health Check"

# Disk free space (GB)
DISK_LINE=$(df -Pk "$ROOTDIR" | awk 'NR==2')
DISK_FREE_KB=$(echo "$DISK_LINE" | awk '{print $4}')
DISK_MOUNT=$(echo "$DISK_LINE" | awk '{print $6}')
DISK_FREE_GB=$((DISK_FREE_KB / 1024 / 1024))
if [ -n "$DISK_MOUNT" ]; then
    echo "Disk free: ${DISK_FREE_GB} GB (${DISK_MOUNT})"
else
    echo "Disk free: ${DISK_FREE_GB} GB"
fi

# Bitcoin status. The pattern is the one update-bitcoin.sh and
# rollback-bitcoin.sh beside this file refuse to run against, so the three
# agree on what counts as a running node; pgrep's regex is extended on both
# procps and BSD, hence "|" rather than a GNU-BRE "\|".
BTC_PGREP_PATTERN="bitcoind|bitcoin-qt|bitcoin qt"
BTC_CLI=""
if [ -x "$ROOTDIR/linux/bin/bitcoin-cli" ]; then
    BTC_CLI="$ROOTDIR/linux/bin/bitcoin-cli"
elif command -v bitcoin-cli >/dev/null 2>&1; then
    BTC_CLI="bitcoin-cli"
fi

BTC_RUNNING="no"
BTC_METHOD=""
BLOCKCHAIN_INFO=""
ARTIFACT_NOTE=""
if [ -n "$BTC_CLI" ]; then
    BLOCKCHAIN_INFO=$(
      "$BTC_CLI" -datadir="$ROOTDIR/bitcoin-datadir" \
        getblockchaininfo 2>/dev/null || true
    )
    if [ -n "$BLOCKCHAIN_INFO" ]; then
        BTC_RUNNING="yes"
        BTC_METHOD="bitcoin-cli"
    fi
fi

if [ "$BTC_RUNNING" != "yes" ] && \
   pgrep -f -i "$BTC_PGREP_PATTERN" >/dev/null 2>&1; then
    BTC_RUNNING="yes"
    BTC_METHOD="pgrep"
fi

if [ "$BTC_RUNNING" != "yes" ]; then
    ARTIFACTS=()
    # Note: .lock is intentionally NOT treated as an artifact. Bitcoin Core
    # leaves the empty .lock file in the datadir even after a clean shutdown
    # (it is only an advisory lock while running), so it carries no info about
    # whether Bitcoin is running and flagging it produced false "maybe" alarms.
    if [ -f "$ROOTDIR/bitcoin-datadir/.cookie" ]; then
        ARTIFACTS+=(".cookie")
    fi
    if [ -f "$ROOTDIR/bitcoin-datadir/bitcoind.pid" ]; then
        ARTIFACTS+=("bitcoind.pid")
        PID="$(cat "$ROOTDIR/bitcoin-datadir/bitcoind.pid" 2>/dev/null || true)"
        # Confirm the PID is actually a Bitcoin process: after a crash the pid
        # file can be left behind and its number reused by something unrelated,
        # so a bare kill -0 would report a false "running".
        if [ -n "$PID" ] && \
           ps -p "$PID" -o comm= 2>/dev/null | grep -qi "bitcoin"; then
            BTC_RUNNING="yes"
            BTC_METHOD="pid"
        else
            ARTIFACT_NOTE=" (stale pid)"
        fi
    fi
    if [ ${#ARTIFACTS[@]} -gt 0 ] && [ "$BTC_RUNNING" != "yes" ]; then
        BTC_RUNNING="maybe"
        BTC_METHOD="artifacts"
        echo "Bitcoin artifacts: ${ARTIFACTS[*]}${ARTIFACT_NOTE}"
    fi
fi

if [ "$BTC_RUNNING" = "yes" ]; then
    if [ -n "$BTC_METHOD" ]; then
        if [ "$BTC_METHOD" = "bitcoin-cli" ] && [ -n "$BTC_CLI" ]; then
            if [ "$BTC_CLI" = "bitcoin-cli" ]; then
                BTC_CLI_PATH="$(command -v bitcoin-cli 2>/dev/null || true)"
                if [ -n "$BTC_CLI_PATH" ]; then
                    echo "Bitcoin running: yes (${BTC_METHOD}: ${BTC_CLI_PATH})"
                else
                    echo "Bitcoin running: yes (${BTC_METHOD}: PATH)"
                fi
            else
                echo "Bitcoin running: yes (${BTC_METHOD}: linux/bin/bitcoin-cli)"
            fi
        else
            echo "Bitcoin running: yes (${BTC_METHOD})"
        fi
    else
        echo "Bitcoin running: yes"
    fi
    if [ -z "$BLOCKCHAIN_INFO" ] && [ -n "$BTC_CLI" ]; then
        BLOCKCHAIN_INFO=$(
          "$BTC_CLI" -datadir="$ROOTDIR/bitcoin-datadir" \
            getblockchaininfo 2>/dev/null || true
        )
    fi
    if [ -n "$BLOCKCHAIN_INFO" ] && command -v jq >/dev/null 2>&1; then
        SYNC=$(echo "$BLOCKCHAIN_INFO" | jq -r '.verificationprogress')
        if [ "$SYNC" != "null" ] && [ -n "$SYNC" ]; then
            PCT=$(printf "%.2f" "$(echo "$SYNC * 100" | bc -l)")
            echo "Bitcoin sync: ${PCT}%"
        else
            echo "Bitcoin sync: unknown"
        fi
    else
        echo "Bitcoin sync: unknown"
    fi
else
    if [ "$BTC_RUNNING" = "maybe" ]; then
        echo "Bitcoin running: maybe"
        echo "Bitcoin sync: unknown"
    else
        echo "Bitcoin running: no"
        echo "Bitcoin sync: n/a"
    fi
fi

# Electrum status. The pattern is update-electrum.sh's and
# rollback-electrum.sh's own, so the three agree here as the Bitcoin three
# do above.
#
# There is no second pass over process names here, where the macOS half has
# one: a name is truncated to fifteen characters on Linux, so the installed
# artifact's own name does not survive into it. Measured on a GitHub Actions
# ubuntu-latest runner, a process started from a file named
# electrum.AppImage reads back as "electrum.AppIma" from /proc/<pid>/comm
# and from "ps -o comm=", and "pgrep -x electrum.AppImage" refuses the
# pattern outright: "pattern that searches for process name longer than 15
# characters will result in zero matches". "pgrep -f" reads the whole
# command line and matched that same process, which is why it is the only
# pass needed.
ELECTRUM_PGREP_PATTERN="electrum\.AppImage|python.*electrum|run_electrum"
if pgrep -f -i "$ELECTRUM_PGREP_PATTERN" > /dev/null; then
    echo "Electrum running: yes (pgrep)"
else
    echo "Electrum running: no"
fi
