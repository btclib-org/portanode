#!/bin/bash
set -u
set -o pipefail

ROOTDIR="$(cd "$(dirname "$0")" && pwd)"

run_cmd() {
  "$@"
  local status=$?
  if [ $status -ne 0 ]; then
    echo "Command failed (exit $status). Returning to menu."
  fi
  return 0
}

while true; do
  echo "Utilities Launcher"
  echo "1) Verify binaries"
  echo "2) Validate setup"
  echo "3) Health check"
  echo "4) Rotate Bitcoin log"
  echo "5) Monitor Bitcoin log"
  echo "6) Clean macOS artifacts"
  echo "7) Set permissions"
  echo "0) Exit"
  printf "Select: "
  read -r choice

  if [ -z "$choice" ]; then
    choice=0
  fi

  case "$choice" in
    1) run_cmd bash "$ROOTDIR/macos/scripts/utilities/verify-binaries.sh" ;;
    2) run_cmd bash "$ROOTDIR/macos/scripts/utilities/validate-setup.sh" ;;
    3) run_cmd bash "$ROOTDIR/macos/scripts/utilities/health-check.sh" ;;
    4) run_cmd bash "$ROOTDIR/macos/scripts/utilities/rotate-bitcoin-log.sh" ;;
    5) run_cmd bash "$ROOTDIR/macos/scripts/utilities/monitor-bitcoin-log.sh" ;;
    6) run_cmd bash "$ROOTDIR/macos/scripts/utilities/clean-artifacts.sh" ;;
    7) run_cmd bash "$ROOTDIR/macos/scripts/utilities/set-permissions.sh" ;;
    0) exit 0 ;;
    *) echo "Invalid selection." ;;
  esac

  echo ""
done
