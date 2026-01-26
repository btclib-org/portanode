#!/bin/bash
set -euo pipefail

ROOTDIR="$(cd "$(dirname "$0")" && pwd)"

echo "Electrum Launcher"
echo "1) Mainnet"
echo "2) Testnet"
echo "3) Regtest"
echo "4) Mainnet (local server only)"
echo "0) Exit"
printf "Select: "
read -r choice

case "$choice" in
  1) bash "$ROOTDIR/macos/scripts/electrum/mainnet.command" ;;
  2) bash "$ROOTDIR/macos/scripts/electrum/testnet.command" ;;
  3) bash "$ROOTDIR/macos/scripts/electrum/regtest.command" ;;
  4) bash "$ROOTDIR/macos/scripts/electrum/mainnet-local-server-only.command" ;;
  0) exit 0 ;;
  *) echo "Invalid selection." ; exit 1 ;;
esac
