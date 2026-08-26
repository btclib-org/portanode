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
  echo "Bitcoin Launcher ($ROOTDIR)"
  echo "1) Mainnet (GUI)"
  echo "2) Testnet3 (GUI)"
  echo "3) Testnet4 (GUI)"
  echo "4) Regtest Alice (GUI)"
  echo "5) Regtest Alice (GUI, clean)"
  echo "6) Regtest Alice (CLI)"
  echo "7) Regtest Alice (CLI, clean)"
  echo "8) Regtest Bob (GUI)"
  echo "9) Regtest Bob (GUI, clean)"
  echo "10) Regtest Bob (CLI)"
  echo "11) Regtest Bob (CLI, clean)"
  echo "12) Regtest Carol (GUI)"
  echo "13) Regtest Carol (GUI, clean)"
  echo "14) Regtest Carol (CLI)"
  echo "15) Regtest Carol (CLI, clean)"
  echo "0) Exit"
  printf "Select: "
  read -r choice

  if [ -z "$choice" ]; then
    choice=0
  fi

  case "$choice" in
    1) run_script "$ROOTDIR/macos/scripts/bitcoin/mainnet-8333-qt.command" ;;
    2) run_script "$ROOTDIR/macos/scripts/bitcoin/testnet3-18333-qt.command" ;;
    3) run_script "$ROOTDIR/macos/scripts/bitcoin/testnet4-48333-qt.command" ;;
    4) run_script "$ROOTDIR/macos/scripts/bitcoin/regtest-18444-Alice-qt.command" ;;
    5) run_script "$ROOTDIR/macos/scripts/bitcoin/regtest-18444-Alice-qt-clean.command" ;;
    6) run_script "$ROOTDIR/macos/scripts/bitcoin/regtest-18444-Alice-cli.command" ;;
    7) run_script "$ROOTDIR/macos/scripts/bitcoin/regtest-18444-Alice-cli-clean.command" ;;
    8) run_script "$ROOTDIR/macos/scripts/bitcoin/regtest-18555-Bob-qt.command" ;;
    9) run_script "$ROOTDIR/macos/scripts/bitcoin/regtest-18555-Bob-qt-clean.command" ;;
    10) run_script "$ROOTDIR/macos/scripts/bitcoin/regtest-18555-Bob-cli.command" ;;
    11) run_script "$ROOTDIR/macos/scripts/bitcoin/regtest-18555-Bob-cli-clean.command" ;;
    12) run_script "$ROOTDIR/macos/scripts/bitcoin/regtest-18666-Carol-qt.command" ;;
    13) run_script "$ROOTDIR/macos/scripts/bitcoin/regtest-18666-Carol-qt-clean.command" ;;
    14) run_script "$ROOTDIR/macos/scripts/bitcoin/regtest-18666-Carol-cli.command" ;;
    15) run_script "$ROOTDIR/macos/scripts/bitcoin/regtest-18666-Carol-cli-clean.command" ;;
    0) exit 0 ;;
    *) echo "Invalid selection." ;;
  esac

  echo ""
done
