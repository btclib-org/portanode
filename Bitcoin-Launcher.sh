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
      if [ -f "$ROOTDIR/Bitcoin-Launcher.bat" ]; then
        cmd.exe /c "\"${ROOTDIR}\\Bitcoin-Launcher.bat\""
      else
        echo "Script not found: $ROOTDIR/Bitcoin-Launcher.bat"
        exit 1
      fi
      exit 0
    fi
    ;;
  Linux)
    # No linux/Bitcoin-Launcher of its own yet: refuse rather than fall
    # through to the .command below, which runs macOS's own menu against
    # Mach-O binaries that do not exist on this platform.
    echo "Linux is not supported yet by Bitcoin-Launcher.sh."
    exit 1
    ;;
esac

if [ -f "$ROOTDIR/Bitcoin-Launcher.command" ]; then
  bash "$ROOTDIR/Bitcoin-Launcher.command"
else
  echo "Script not found: $ROOTDIR/Bitcoin-Launcher.command"
  exit 1
fi
