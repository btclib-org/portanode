#!/usr/bin/env bash
# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# Verify binaries against macos/checksums.sha256
set -euo pipefail

# bash looks for a bare name in the current directory, then in PATH. Found
# through PATH, $0 has no directory, so the directory below would be wrong.
case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=macos/scripts/utilities/lib.sh
. "$SCRIPT_DIR/lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")" || exit 1

# The parser lives in shared/utilities/lib.sh's verify_binaries: this
# script and linux/scripts/utilities/verify-binaries.sh differ only in
# the checksum file and the path prefix passed here.
verify_binaries "$ROOTDIR" "macos/checksums.sha256" "macos"
