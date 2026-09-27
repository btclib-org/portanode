#!/usr/bin/env bash
set -euo pipefail

# Portable readlink -f: macOS's own readlink has no -f before 12.3
# (apple-oss-distributions/file_cmds tag file_cmds-352.40.6 vs.
# file_cmds-353.100.22), so $0 -- the symlink's own path where a
# launcher is started through one, which would send both the source
# below and the root walk into the wrong directory -- is resolved a
# link at a time instead.
resolve_symlink() {
  local target="$1" dir
  while [ -L "$target" ]; do
    dir="$(cd -P "$(dirname "$target")" && pwd)"
    target="$(readlink "$target")"
    case "$target" in
      /*) ;;
      *) target="$dir/$target" ;;
    esac
  done
  printf '%s\n' "$target"
}
SCRIPT_DIR="$(cd "$(dirname "$(resolve_symlink "$0")")" && pwd)"
. "$SCRIPT_DIR/shared/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
UNAME="$(uname -s 2>/dev/null || true)"

case "$UNAME" in
  MINGW*|MSYS*|CYGWIN*)
    if command -v cmd.exe >/dev/null 2>&1; then
      if [ -f "$ROOTDIR/Bitcoin-Launcher.bat" ]; then
        cmd.exe /c "\"${ROOTDIR}\\Bitcoin-Launcher.bat\""
      else
        echo "Script not found: Bitcoin-Launcher.bat"
        exit 1
      fi
      exit 0
    fi
    ;;
  Linux)
    # The .command below runs macOS's own menu, whose entries reach
    # Mach-O binaries that do not exist on this platform, so Linux is
    # served by a menu of its own rather than by that one.
    if [ -f "$ROOTDIR/linux/Bitcoin-Launcher.sh" ]; then
      bash "$ROOTDIR/linux/Bitcoin-Launcher.sh"
    else
      echo "Script not found: linux/Bitcoin-Launcher.sh"
      exit 1
    fi
    exit 0
    ;;
esac

if [ -f "$ROOTDIR/Bitcoin-Launcher.command" ]; then
  bash "$ROOTDIR/Bitcoin-Launcher.command"
else
  echo "Script not found: Bitcoin-Launcher.command"
  exit 1
fi
