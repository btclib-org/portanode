#!/bin/bash
set -euo pipefail

ROOTDIR="$(cd "$(dirname "$0")" && pwd)"

echo "Utilities Launcher"
echo "1) Verify binaries"
echo "2) Validate setup"
echo "3) Health check"
echo "4) Rotate Bitcoin log"
echo "5) Monitor Bitcoin log"
echo "6) Clean artifacts"
echo "7) Set permissions"
echo "0) Exit"
printf "Select: "
read -r choice

case "$choice" in
  1) bash "$ROOTDIR/macos/scripts/utilities/verify-binaries.sh" ;;
  2) bash "$ROOTDIR/macos/scripts/utilities/validate-setup.sh" ;;
  3) bash "$ROOTDIR/macos/scripts/utilities/health-check.sh" ;;
  4) bash "$ROOTDIR/macos/scripts/utilities/rotate-bitcoin-log.sh" ;;
  5) bash "$ROOTDIR/macos/scripts/utilities/monitor-bitcoin-log.sh" ;;
  6) bash "$ROOTDIR/macos/scripts/utilities/clean-artifacts.sh" ;;
  7) bash "$ROOTDIR/macos/scripts/utilities/set-permissions.sh" ;;
  0) exit 0 ;;
  *) echo "Invalid selection." ; exit 1 ;;
esac
