#!/bin/bash
set -euo pipefail

ROOTDIR="$(cd "$(dirname "$0")" && pwd)"

echo "Bitcoin Launcher"
echo "1) Mainnet (GUI)"
echo "2) Testnet3 (GUI)"
echo "3) Regtest Alice (GUI)"
echo "4) Regtest Bob (GUI)"
echo "5) Regtest Carol (GUI)"
echo "0) Exit"
printf "Select: "
read -r choice

case "$choice" in
  1) bash "$ROOTDIR/macos/scripts/bitcoin/mainnet-8333-qt.command" ;;
  2) bash "$ROOTDIR/macos/scripts/bitcoin/testnet3-18333-qt.command" ;;
  3) bash "$ROOTDIR/macos/scripts/bitcoin/regtest-18444-Alice-qt.command" ;;
  4) bash "$ROOTDIR/macos/scripts/bitcoin/regtest-18555-Bob-qt.command" ;;
  5) bash "$ROOTDIR/macos/scripts/bitcoin/regtest-18666-Carol-qt.command" ;;
  0) exit 0 ;;
  *) echo "Invalid selection." ; exit 1 ;;
esac
