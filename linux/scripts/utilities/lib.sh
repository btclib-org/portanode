#!/bin/bash
# Linux's own entry point for the platform-nameless download, PGP and
# checksum helpers. The implementation lives in shared/utilities/lib.sh;
# this file exists as a forwarder rather than sourcing that path
# directly from every caller, matching macos/scripts/utilities/lib.sh
# beside it -- update-bitcoin.sh and rollback-bitcoin.sh source it by
# this exact path ($SCRIPT_DIR/lib.sh).

_UTILS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=shared/utilities/lib.sh
. "$_UTILS_LIB_DIR/../../../shared/utilities/lib.sh"
unset _UTILS_LIB_DIR
