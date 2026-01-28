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
  echo "Electrum Launcher"
  echo "1) Mainnet"
  echo "2) Testnet"
  echo "3) Regtest"
  echo "4) Mainnet (local server only)"
  echo "0) Exit"
  printf "Select: "
  read -r choice

  if [ -z "$choice" ]; then
    choice=0
  fi

  case "$choice" in
    1) run_cmd bash \
         "$ROOTDIR/macos/scripts/electrum/mainnet.command" ;;
    2) run_cmd bash \
         "$ROOTDIR/macos/scripts/electrum/testnet.command" ;;
    3) run_cmd bash \
         "$ROOTDIR/macos/scripts/electrum/regtest.command" ;;
    4) run_cmd bash \
         "$ROOTDIR/macos/scripts/electrum/mainnet-local-server-only.command" ;;
    0) exit 0 ;;
    *) echo "Invalid selection." ;;
  esac

  echo ""
done
