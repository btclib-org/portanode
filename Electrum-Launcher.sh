#!/usr/bin/env bash
set -euo pipefail

# readlink -f: $0 is the symlink's own path where a launcher is
# started through one, which would send both the source below and
# the root walk into the wrong directory.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
. "$SCRIPT_DIR/shared/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
UNAME="$(uname -s 2>/dev/null || true)"

case "$UNAME" in
  MINGW*|MSYS*|CYGWIN*)
    if command -v cmd.exe >/dev/null 2>&1; then
      if [ -f "$ROOTDIR/Electrum-Launcher.bat" ]; then
        cmd.exe /c "\"${ROOTDIR}\\Electrum-Launcher.bat\""
      else
        echo "Script not found: Electrum-Launcher.bat"
        exit 1
      fi
      exit 0
    fi
    ;;
  Linux)
    # The .command below runs macOS's own menu, whose entries reach
    # Mach-O binaries that do not exist on this platform, so Linux is
    # served by a menu of its own rather than by that one.
    if [ -f "$ROOTDIR/linux/Electrum-Launcher.sh" ]; then
      bash "$ROOTDIR/linux/Electrum-Launcher.sh"
    else
      echo "Script not found: linux/Electrum-Launcher.sh"
      exit 1
    fi
    exit 0
    ;;
esac

if [ -f "$ROOTDIR/Electrum-Launcher.command" ]; then
  bash "$ROOTDIR/Electrum-Launcher.command"
else
  echo "Script not found: Electrum-Launcher.command"
  exit 1
fi
