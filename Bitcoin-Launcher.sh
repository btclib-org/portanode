#!/usr/bin/env bash
set -euo pipefail

ROOTDIR="$(cd "$(dirname "$0")" && pwd)"
UNAME="$(uname -s 2>/dev/null || true)"

case "$UNAME" in
  MINGW*|MSYS*|CYGWIN*)
    if command -v cmd.exe >/dev/null 2>&1; then
      cmd.exe /c "\"${ROOTDIR}\\Bitcoin-Launcher.bat\""
      exit 0
    fi
    ;;
esac

if [ -f "$ROOTDIR/Bitcoin-Launcher.command" ]; then
  bash "$ROOTDIR/Bitcoin-Launcher.command"
else
  echo "Bitcoin-Launcher.command not found."
  exit 1
fi
