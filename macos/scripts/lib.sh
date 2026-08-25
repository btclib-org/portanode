#!/bin/bash
# macOS's own entry point for the platform-nameless root-resolution
# helper. The implementation lives in shared/lib.sh; this file stays at
# this path, as a forwarder rather than being deleted, because
# Bitcoin-Launcher.command, Electrum-Launcher.command and
# Utilities-Launcher.command source it by this exact path, and because a
# forwarder keeps the relative-path arithmetic into shared/ in one file
# instead of in every caller that reaches it through this one.

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=shared/lib.sh
. "$_LIB_DIR/../../shared/lib.sh"
unset _LIB_DIR
