#!/bin/bash
set -u
set -o pipefail

ROOTDIR="$(cd "$(dirname "$0")" && pwd)"

run_cmd() {
  "$@"
  local status=$?
  if [ $status -ne 0 ]; then
    echo "Command failed (exit $status)."
  fi
  return 0
}

while true; do
  echo "PortaNode Launcher"
  echo "1) Bitcoin Mainnet (GUI)"
  echo "2) Bitcoin Testnet3 (GUI)"
  echo "3) Bitcoin Regtest Alice (GUI)"
  echo "4) Bitcoin Regtest Bob (GUI)"
  echo "5) Bitcoin Regtest Carol (GUI)"
  echo "6) Electrum Mainnet"
  echo "7) Electrum Testnet"
  echo "8) Electrum Regtest"
  echo "9) Electrum Mainnet (local server only)"
  echo "0) Exit"
  printf "Select: "
  read -r choice

  if [ -z "$choice" ]; then
    exit 0
  fi

  case "$choice" in
    1) run_cmd bash "$ROOTDIR/macos/scripts/bitcoin/mainnet-8333-qt.command" ;;
    2) run_cmd bash "$ROOTDIR/macos/scripts/bitcoin/testnet3-18333-qt.command" ;;
    3) run_cmd bash "$ROOTDIR/macos/scripts/bitcoin/regtest-18444-Alice-qt.command" ;;
    4) run_cmd bash "$ROOTDIR/macos/scripts/bitcoin/regtest-18555-Bob-qt.command" ;;
    5) run_cmd bash "$ROOTDIR/macos/scripts/bitcoin/regtest-18666-Carol-qt.command" ;;
    6) run_cmd bash "$ROOTDIR/macos/scripts/electrum/mainnet.command" ;;
    7) run_cmd bash "$ROOTDIR/macos/scripts/electrum/testnet.command" ;;
    8) run_cmd bash "$ROOTDIR/macos/scripts/electrum/regtest.command" ;;
    9) run_cmd bash "$ROOTDIR/macos/scripts/electrum/mainnet-local-server-only.command" ;;
    0) exit 0 ;;
    *) echo "Invalid selection." ;;
  esac

  echo ""
done
