#!/bin/bash
# Linux's own entry point for the platform-nameless root-resolution
# helper. The implementation lives in shared/lib.sh; this file exists as
# a forwarder rather than sourcing shared/lib.sh directly from every
# caller, matching macos/scripts/lib.sh beside it -- a forwarder keeps
# the relative-path arithmetic into shared/ in one file per platform
# instead of in every script that reaches it through this one.

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=shared/lib.sh
. "$_LIB_DIR/../../shared/lib.sh"
unset _LIB_DIR
