#!/bin/bash
set -euo pipefail

ROOTDIR="$(cd "$(dirname "$0")" && pwd)"

echo "PortaNode Launcher"
echo "1) Bitcoin Mainnet (GUI)"
echo "2) Bitcoin Testnet3 (GUI)"
echo "3) Bitcoin Regtest Alice (GUI)"
echo "4) Bitcoin Regtest Bob (GUI)"
echo "5) Bitcoin Regtest Carol (GUI)"
echo "6) Electrum Mainnet"
echo "7) Electrum Testnet"
echo "8) Electrum Regtest"
echo "9) Electrum Mainnet (local server only)"
echo "0) Exit"
printf "Select: "
read -r choice

case "$choice" in
  1) bash "$ROOTDIR/macos/scripts/bitcoin/mainnet-8333-qt.command" ;;
  2) bash "$ROOTDIR/macos/scripts/bitcoin/testnet3-18333-qt.command" ;;
  3) bash "$ROOTDIR/macos/scripts/bitcoin/regtest-18444-Alice-qt.command" ;;
  4) bash "$ROOTDIR/macos/scripts/bitcoin/regtest-18555-Bob-qt.command" ;;
  5) bash "$ROOTDIR/macos/scripts/bitcoin/regtest-18666-Carol-qt.command" ;;
  6) bash "$ROOTDIR/macos/scripts/electrum/mainnet.command" ;;
  7) bash "$ROOTDIR/macos/scripts/electrum/testnet.command" ;;
  8) bash "$ROOTDIR/macos/scripts/electrum/regtest.command" ;;
  9) bash "$ROOTDIR/macos/scripts/electrum/mainnet-local-server-only.command" ;;
  0) exit 0 ;;
  *) echo "Invalid selection." ; exit 1 ;;
esac
