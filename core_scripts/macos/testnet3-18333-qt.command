#!/bin/bash
ROOTDIR=$(dirname $0)/../..
echo ROOTDIR is ${ROOTDIR}

BASENAME=$(basename $0)
FILENAME=${BASENAME%.*}
${ROOTDIR}/core_bin/macos/bin/bitcoin-qt \
-uacomment=${FILENAME} -datadir=${ROOTDIR}/core_datadir -blocksdir=${ROOTDIR}/core_blocksdir -testnet
