#!/bin/bash
# Shared helpers for macOS scripts.

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
        if [ -f "$dir/VERSION" ] && [ -d "$dir/macos" ] && [ -d "$dir/win" ]; then
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
