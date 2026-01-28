#!/bin/bash
set -u
set -o pipefail

ROOTDIR="$(cd "$(dirname "$0")" && pwd)"

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
  echo "Utilities Launcher"
  echo "1) Update Bitcoin binaries"
  echo "2) Update Electrum binaries"
  echo "3) Verify binaries"
  echo "4) Validate setup"
  echo "5) Set permissions"
  echo "6) Health check"
  echo "7) Monitor Bitcoin log"
  echo "8) Rotate Bitcoin log"
  echo "9) Clean macOS artifacts"
  echo "0) Exit"
  printf "Select: "
  read -r choice

  if [ -z "$choice" ]; then
    choice=0
  fi

  case "$choice" in
    1) run_script "$ROOTDIR/macos/scripts/utilities/update-bitcoin.sh" ;;
    2) run_script "$ROOTDIR/macos/scripts/utilities/update-electrum.sh" ;;
    3) run_script "$ROOTDIR/macos/scripts/utilities/verify-binaries.sh" ;;
    4) run_script "$ROOTDIR/macos/scripts/utilities/validate-setup.sh" ;;
    5) run_script "$ROOTDIR/macos/scripts/utilities/set-permissions.sh" ;;
    6) run_script "$ROOTDIR/macos/scripts/utilities/health-check.sh" ;;
    7) run_script "$ROOTDIR/macos/scripts/utilities/monitor-bitcoin-log.sh" ;;
    8) run_script "$ROOTDIR/macos/scripts/utilities/rotate-bitcoin-log.sh" ;;
    9) run_script "$ROOTDIR/macos/scripts/utilities/clean-artifacts.sh" ;;
    0) exit 0 ;;
    *) echo "Invalid selection." ;;
  esac

  echo ""
done
