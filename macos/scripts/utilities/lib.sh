#!/bin/bash
# macOS's own entry point for the platform-nameless download, PGP and
# checksum helpers. The implementation lives in shared/utilities/lib.sh;
# this file stays at this path, as a forwarder rather than being
# deleted, because rollback-bitcoin.sh, rollback-electrum.sh,
# update-bitcoin.sh and update-electrum.sh source it by this exact
# path ($SCRIPT_DIR/lib.sh). The rest of macos/scripts/utilities/
# sources ../lib.sh instead -- macos/scripts/lib.sh, this file's own
# sibling forwarder -- and never touches this file directly.

_UTILS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=shared/utilities/lib.sh
. "$_UTILS_LIB_DIR/../../../shared/utilities/lib.sh"
unset _UTILS_LIB_DIR
