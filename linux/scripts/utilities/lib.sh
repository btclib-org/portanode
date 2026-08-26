#!/bin/bash
# Linux's own entry point for the platform-nameless download, PGP and
# checksum helpers. The implementation lives in shared/utilities/lib.sh;
# this file exists as a forwarder rather than sourcing that path
# directly from every caller, matching macos/scripts/utilities/lib.sh
# beside it. A linux/scripts/utilities/ script that needs one of these
# helpers sources this file by this exact path ($SCRIPT_DIR/lib.sh)
# rather than through linux/scripts/lib.sh, this file's own sibling
# forwarder, which carries resolve_root alone. Which scripts currently
# do that is not named here: that list is exactly the kind of count
# CLAUDE.md warns against, wrong the moment a script starts or stops
# sourcing this file with nothing here to catch it -- `git grep -n
# 'SCRIPT_DIR/lib.sh"' -- linux/scripts/utilities/` answers it live.

_UTILS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=shared/utilities/lib.sh
. "$_UTILS_LIB_DIR/../../../shared/utilities/lib.sh"
unset _UTILS_LIB_DIR
