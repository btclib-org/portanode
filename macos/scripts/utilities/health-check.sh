#!/bin/bash
# Health check for PortaNode

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "Health Check"

# Disk free space (GB)
DISK_FREE_KB=$(df -Pk "$ROOTDIR" | awk 'NR==2 {print $4}')
DISK_FREE_GB=$((DISK_FREE_KB / 1024 / 1024))
echo "Disk free: ${DISK_FREE_GB} GB"

# Bitcoin status
BTC_CLI=""
if [ -x "$ROOTDIR/macos/bin/Bitcoin-Qt.app/Contents/MacOS/bitcoin-cli" ]; then
    BTC_CLI="$ROOTDIR/macos/bin/Bitcoin-Qt.app/Contents/MacOS/bitcoin-cli"
elif command -v bitcoin-cli >/dev/null 2>&1; then
    BTC_CLI="bitcoin-cli"
fi

BTC_RUNNING="no"
BTC_METHOD=""
BLOCKCHAIN_INFO=""
ARTIFACT_NOTE=""
ARTIFACTS_FOUND=0
if [ -n "$BTC_CLI" ]; then
    BLOCKCHAIN_INFO=$("$BTC_CLI" -datadir="$ROOTDIR/bitcoin-datadir" getblockchaininfo 2>/dev/null || true)
    if [ -n "$BLOCKCHAIN_INFO" ]; then
        BTC_RUNNING="yes"
        BTC_METHOD="bitcoin-cli"
    fi
fi

if [ "$BTC_RUNNING" != "yes" ] && pgrep -f -i "bitcoind\\|bitcoin-qt\\|bitcoin qt\\|bitcoin-qt.app" > /dev/null; then
    BTC_RUNNING="yes"
    BTC_METHOD="pgrep"
fi

if [ "$BTC_RUNNING" != "yes" ]; then
    ARTIFACTS=()
    if [ -f "$ROOTDIR/bitcoin-datadir/.lock" ]; then
        ARTIFACTS+=(".lock")
        ARTIFACTS_FOUND=1
    fi
    if [ -f "$ROOTDIR/bitcoin-datadir/.cookie" ]; then
        ARTIFACTS+=(".cookie")
        ARTIFACTS_FOUND=1
    fi
    if [ -f "$ROOTDIR/bitcoin-datadir/bitcoind.pid" ]; then
        ARTIFACTS+=("bitcoind.pid")
        ARTIFACTS_FOUND=1
        PID="$(cat "$ROOTDIR/bitcoin-datadir/bitcoind.pid" 2>/dev/null || true)"
        if [ -n "$PID" ] && kill -0 "$PID" >/dev/null 2>&1; then
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
                echo "Bitcoin running: yes (${BTC_METHOD}: ${BTC_CLI})"
            fi
        else
            echo "Bitcoin running: yes (${BTC_METHOD})"
        fi
    else
        echo "Bitcoin running: yes"
    fi
    if [ -z "$BLOCKCHAIN_INFO" ] && [ -n "$BTC_CLI" ]; then
        BLOCKCHAIN_INFO=$("$BTC_CLI" -datadir="$ROOTDIR/bitcoin-datadir" getblockchaininfo 2>/dev/null || true)
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

# Electrum status
ELECTRUM_RUNNING="no"
ELECTRUM_METHOD=""
if pgrep -f -i "Electrum.app/Contents/MacOS/(Electrum|run_electrum)$|/Electrum$|/electrum$|python.*electrum" > /dev/null; then
    ELECTRUM_RUNNING="yes"
    ELECTRUM_METHOD="pgrep"
fi
if [ "$ELECTRUM_RUNNING" != "yes" ] && command -v ps >/dev/null 2>&1; then
    if ps -ax -o comm= 2>/dev/null | awk 'tolower($0) ~ /(electrum|run_electrum)$/ { found=1 } END { exit found?0:1 }'; then
        ELECTRUM_RUNNING="yes"
        ELECTRUM_METHOD="ps"
    fi
fi
if [ "$ELECTRUM_RUNNING" = "yes" ] && [ -n "$ELECTRUM_METHOD" ]; then
    echo "Electrum running: yes (${ELECTRUM_METHOD})"
else
    echo "Electrum running: $ELECTRUM_RUNNING"
fi
