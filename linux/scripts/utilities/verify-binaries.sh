#!/usr/bin/env bash
# Verify binaries against linux/checksums.sha256
set -euo pipefail

# bash looks for a bare name in the current directory, then in PATH. Found
# through PATH, $0 has no directory, so the directory below would be wrong.
case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=linux/scripts/utilities/lib.sh
. "$SCRIPT_DIR/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")" || exit 1

# The parser lives in shared/utilities/lib.sh's verify_binaries: this
# script and macos/scripts/utilities/verify-binaries.sh differ only in
# the checksum file and the path prefix passed here.
verify_binaries "$ROOTDIR" "linux/checksums.sha256" "linux"
