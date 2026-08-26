#!/bin/bash
# Shared helpers for every platform's scripts. This file names no
# platform on purpose. macos/scripts/lib.sh and linux/scripts/lib.sh each
# forward to it rather than holding the implementation, so the path
# arithmetic into shared/ lives in one forwarder per platform instead of
# in every script that would otherwise source it directly.

resolve_root() {
    local start_dir="$1"

    if [ -n "${PORTANODE_ROOT:-}" ]; then
        if [ -d "$PORTANODE_ROOT" ]; then
            (cd "$PORTANODE_ROOT" && pwd -P)
            return 0
        fi
        printf "%s" "$PORTANODE_ROOT"
        return 0
    fi

    local dir="$start_dir"
    while [ -n "$dir" ]; do
        # A root is marked by VERSION plus at least one platform
        # directory, not by all three: a checkout of a source archive, or
        # a tree being assembled, need not hold every platform directory
        # yet, and requiring all three here would make this probe fail on
        # such a checkout, sending its caller to the fallback below
        # instead of to the root it is actually sitting in.
        #
        # This is looser than requiring all three: an ancestor holding
        # VERSION plus only one platform directory now matches, where the
        # stricter form would have refused it and kept walking. That is
        # safe for a real caller in this tree, and not merely assumed
        # safe: this loop starts at start_dir and walks upward, returning
        # on the first match, and a genuine checkout's own root already
        # satisfies the probe (VERSION, macos/ and win/ are all there) --
        # so the walk from any script actually inside this folder stops
        # at that real root before it can reach any looser-matching
        # ancestor further up. The loosened match only fires where no
        # real root sits between start_dir and it, which is not a shape
        # any caller in this tree is in.
        if [ -f "$dir/VERSION" ] && \
           { [ -d "$dir/macos" ] || [ -d "$dir/win" ] || [ -d "$dir/linux" ]; }; then
            (cd "$dir" && pwd -P)
            return 0
        fi
        local parent
        parent="$(cd "$dir/.." && pwd -P)"
        if [ "$parent" = "$dir" ]; then
            break
        fi
        dir="$parent"
    done

    (cd "$start_dir" && pwd -P)
}
