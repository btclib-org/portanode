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
  echo "Utilities Launcher ($ROOTDIR)"
  echo "1) Update Bitcoin Version"
  echo "2) Update Electrum Version"
  echo "3) Rollback Last Bitcoin Update"
  echo "4) Rollback Last Electrum Update"
  echo "5) Verify binaries"
  echo "6) Validate setup"
  echo "7) Set permissions"
  echo "8) Health check"
  echo "9) Monitor Bitcoin log"
  echo "10) Rotate Bitcoin log"
  echo "11) Clean macOS artifacts"
  echo "0) Exit"
  printf "Select: "
  read -r choice

  if [ -z "$choice" ]; then
    choice=0
  fi

  case "$choice" in
    1) run_script "$ROOTDIR/macos/scripts/utilities/update-bitcoin.sh" ;;
    2) run_script "$ROOTDIR/macos/scripts/utilities/update-electrum.sh" ;;
    3) run_script "$ROOTDIR/macos/scripts/utilities/rollback-bitcoin.sh" ;;
    4) run_script "$ROOTDIR/macos/scripts/utilities/rollback-electrum.sh" ;;
    5) run_script "$ROOTDIR/macos/scripts/utilities/verify-binaries.sh" ;;
    6) run_script "$ROOTDIR/macos/scripts/utilities/validate-setup.sh" ;;
    7) run_script "$ROOTDIR/macos/scripts/utilities/set-permissions.sh" ;;
    8) run_script "$ROOTDIR/macos/scripts/utilities/health-check.sh" ;;
    9) run_script "$ROOTDIR/macos/scripts/utilities/monitor-bitcoin-log.sh" ;;
    10) run_script "$ROOTDIR/macos/scripts/utilities/rotate-bitcoin-log.sh" ;;
    11) run_script "$ROOTDIR/macos/scripts/utilities/clean-artifacts.sh" ;;
    0) exit 0 ;;
    *) echo "Invalid selection." ;;
  esac

  echo ""
done
