#!/usr/bin/env bash
# Verify binaries against macos/checksums.sha256
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=macos/scripts/utilities/lib.sh
. "$SCRIPT_DIR/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"

# The parser lives in shared/utilities/lib.sh's verify_binaries: this
# script and linux/scripts/utilities/verify-binaries.sh differ only in
# the checksum file and the path prefix passed here.
verify_binaries "$ROOTDIR" "macos/checksums.sha256" "macos"
