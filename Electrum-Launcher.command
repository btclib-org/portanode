#!/bin/bash
set -u
set -o pipefail

# readlink -f: $0 is the symlink's own path where a launcher is
# started through one, which would send both the source below and
# the root walk into the wrong directory.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
. "$SCRIPT_DIR/macos/scripts/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"

run_script() {
  local script="$1"
  if [ ! -f "$script" ]; then
    echo "Script not found: $script"
    return 0
  fi
  bash "$script"
  local status=$?
  if [ $status -ne 0 ]; then
    echo "Command failed (exit $status)."
  fi
  return 0
}

while true; do
  echo "Electrum Launcher ($ROOTDIR)"
  echo "1) Mainnet"
  echo "2) Testnet3"
  echo "3) Testnet4"
  echo "4) Regtest"
  echo "5) Mainnet (local server only)"
  echo "0) Exit"
  printf "Select: "
  read -r choice

  if [ -z "$choice" ]; then
    choice=0
  fi

  case "$choice" in
    1) run_script "$ROOTDIR/macos/scripts/electrum/mainnet.command" ;;
    2) run_script "$ROOTDIR/macos/scripts/electrum/testnet3.command" ;;
    3) run_script "$ROOTDIR/macos/scripts/electrum/testnet4.command" ;;
    4) run_script "$ROOTDIR/macos/scripts/electrum/regtest.command" ;;
    5) run_script "$ROOTDIR/macos/scripts/electrum/mainnet-local-server-only.command" ;;
    0) exit 0 ;;
    *) echo "Invalid selection." ;;
  esac

  echo ""
done
