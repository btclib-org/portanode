#!/bin/bash
ROOTDIR="${PORTANODE_ROOT:-$(dirname "$0")/../../..}"
echo "ROOTDIR is ${ROOTDIR}"

if [ ! -d "${ROOTDIR}/macos/bin" ]; then
    echo "Error: Binaries directory not found at ${ROOTDIR}/macos/bin"
    exit 1
fi

if [ ! -x "${ROOTDIR}/macos/bin/Electrum.app/Contents/MacOS/run_electrum" ] && [ ! -x "${ROOTDIR}/macos/bin/Electrum.app/Contents/MacOS/Electrum" ]; then
    echo "Error: Electrum executable not found in ${ROOTDIR}/macos/bin/Electrum.app/Contents/MacOS"
    exit 1
fi

open -n "${ROOTDIR}/macos/bin/Electrum.app" --args \
--dir "${ROOTDIR}/electrum-datadir"
