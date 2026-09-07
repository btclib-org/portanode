#!/bin/bash
set -u
set -o pipefail

# readlink -f: $0 is the symlink's own path where a launcher is
# started through one, which would send both the source below and
# the root walk into the wrong directory.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# shellcheck source=linux/scripts/lib.sh
. "$SCRIPT_DIR/scripts/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"

run_script() {
  local rel="$1"
  local script="$ROOTDIR/$rel"
  if [ ! -f "$script" ]; then
    echo "Script not found: $rel"
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
    1) run_script "linux/scripts/bitcoin/mainnet-8333-qt.sh" ;;
    2) run_script "linux/scripts/bitcoin/testnet3-18333-qt.sh" ;;
    3) run_script "linux/scripts/bitcoin/testnet4-48333-qt.sh" ;;
    4) run_script "linux/scripts/bitcoin/regtest-18444-Alice-qt.sh" ;;
    5) run_script "linux/scripts/bitcoin/regtest-18444-Alice-qt-clean.sh" ;;
    6) run_script "linux/scripts/bitcoin/regtest-18444-Alice-cli.sh" ;;
    7) run_script "linux/scripts/bitcoin/regtest-18444-Alice-cli-clean.sh" ;;
    8) run_script "linux/scripts/bitcoin/regtest-18555-Bob-qt.sh" ;;
    9) run_script "linux/scripts/bitcoin/regtest-18555-Bob-qt-clean.sh" ;;
    10) run_script "linux/scripts/bitcoin/regtest-18555-Bob-cli.sh" ;;
    11) run_script "linux/scripts/bitcoin/regtest-18555-Bob-cli-clean.sh" ;;
    12) run_script "linux/scripts/bitcoin/regtest-18666-Carol-qt.sh" ;;
    13) run_script "linux/scripts/bitcoin/regtest-18666-Carol-qt-clean.sh" ;;
    14) run_script "linux/scripts/bitcoin/regtest-18666-Carol-cli.sh" ;;
    15) run_script "linux/scripts/bitcoin/regtest-18666-Carol-cli-clean.sh" ;;
    0) exit 0 ;;
    *) echo "Invalid selection." ;;
  esac

  echo ""
done
