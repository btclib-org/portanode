#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/macos/scripts/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
UNAME="$(uname -s 2>/dev/null || true)"

case "$UNAME" in
  MINGW*|MSYS*|CYGWIN*)
    if command -v cmd.exe >/dev/null 2>&1; then
      if [ -f "$ROOTDIR/Electrum-Launcher.bat" ]; then
        cmd.exe /c "\"${ROOTDIR}\\Electrum-Launcher.bat\""
      else
        echo "Script not found: $ROOTDIR/Electrum-Launcher.bat"
        exit 1
      fi
      exit 0
    fi
    ;;
esac

if [ -f "$ROOTDIR/Electrum-Launcher.command" ]; then
  bash "$ROOTDIR/Electrum-Launcher.command"
else
  echo "Script not found: $ROOTDIR/Electrum-Launcher.command"
  exit 1
fi
