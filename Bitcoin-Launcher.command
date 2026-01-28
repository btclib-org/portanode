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
  echo "Bitcoin Launcher"
  echo "1) Mainnet (GUI)"
  echo "2) Testnet3 (GUI)"
  echo "3) Regtest Alice (GUI)"
  echo "4) Regtest Bob (GUI)"
  echo "5) Regtest Carol (GUI)"
  echo "0) Exit"
  printf "Select: "
  read -r choice

  if [ -z "$choice" ]; then
    choice=0
  fi

  case "$choice" in
    1) run_cmd bash \
         "$ROOTDIR/macos/scripts/bitcoin/mainnet-8333-qt.command" ;;
    2) run_cmd bash \
         "$ROOTDIR/macos/scripts/bitcoin/testnet3-18333-qt.command" ;;
    3) run_cmd bash \
         "$ROOTDIR/macos/scripts/bitcoin/regtest-18444-Alice-qt.command" ;;
    4) run_cmd bash \
         "$ROOTDIR/macos/scripts/bitcoin/regtest-18555-Bob-qt.command" ;;
    5) run_cmd bash \
         "$ROOTDIR/macos/scripts/bitcoin/regtest-18666-Carol-qt.command" ;;
    0) exit 0 ;;
    *) echo "Invalid selection." ;;
  esac

  echo ""
done
