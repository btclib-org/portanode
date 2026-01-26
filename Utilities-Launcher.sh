#!/usr/bin/env bash
set -euo pipefail

ROOTDIR="$(cd "$(dirname "$0")" && pwd)"
UNAME="$(uname -s 2>/dev/null || true)"

case "$UNAME" in
  MINGW*|MSYS*|CYGWIN*)
    if command -v cmd.exe >/dev/null 2>&1; then
      echo "Utilities Launcher (Windows)"
      cmd.exe /c "\"${ROOTDIR}\\Utilities-Launcher.bat\""
      exit 0
    fi
    ;;
esac

if [ -f "$ROOTDIR/Utilities-Launcher.command" ]; then
  echo "Utilities Launcher (macOS)"
  bash "$ROOTDIR/Utilities-Launcher.command"
else
  echo "Utilities-Launcher.command not found."
  exit 1
fi
