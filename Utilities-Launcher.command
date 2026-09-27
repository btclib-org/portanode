#!/bin/bash
set -u
set -o pipefail

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
. "$SCRIPT_DIR/macos/scripts/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"

run_script() {
  local rel="$1"
  local script="$ROOTDIR/$rel"
  if [ ! -f "$script" ]; then
    echo "Script not found: $rel"
    return 0
  fi
  bash "$script"
  local status=$?
  if [ $status -ne 0 ]; then
    echo "Command failed (exit $status)."
  fi
  return 0
}

while true; do
  echo "Utilities Launcher ($ROOTDIR)"
  echo "1) Update Bitcoin Version"
  echo "2) Update Electrum Version"
  echo "3) Rollback Last Bitcoin Update"
  echo "4) Rollback Last Electrum Update"
  echo "5) Verify binaries"
  echo "6) Validate setup"
  echo "7) Set permissions"
  echo "8) Health check"
  echo "9) Monitor Bitcoin log"
  echo "10) Rotate Bitcoin log"
  echo "11) Clean macOS artifacts"
  echo "0) Exit"
  printf "Select: "
  read -r choice

  if [ -z "$choice" ]; then
    choice=0
  fi

  case "$choice" in
    1) run_script "macos/scripts/utilities/update-bitcoin.sh" ;;
    2) run_script "macos/scripts/utilities/update-electrum.sh" ;;
    3) run_script "macos/scripts/utilities/rollback-bitcoin.sh" ;;
    4) run_script "macos/scripts/utilities/rollback-electrum.sh" ;;
    5) run_script "macos/scripts/utilities/verify-binaries.sh" ;;
    6) run_script "macos/scripts/utilities/validate-setup.sh" ;;
    7) run_script "macos/scripts/utilities/set-permissions.sh" ;;
    8) run_script "macos/scripts/utilities/health-check.sh" ;;
    9) run_script "macos/scripts/utilities/monitor-bitcoin-log.sh" ;;
    10) run_script "macos/scripts/utilities/rotate-bitcoin-log.sh" ;;
    11) run_script "macos/scripts/utilities/clean-artifacts.sh" ;;
    0) exit 0 ;;
    *) echo "Invalid selection." ;;
  esac

  echo ""
done
