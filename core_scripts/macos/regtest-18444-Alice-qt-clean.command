#!/bin/bash
ROOTDIR=$(dirname $0)/../..
echo ROOTDIR is ${ROOTDIR}

rm -rf ${ROOTDIR}/core_datadir/regtest

BASENAME=$(basename $0)
FILENAME=${BASENAME%.*}
${ROOTDIR}/core_bin/macos/bin/bitcoin-qt -uacomment=${FILENAME} \
-datadir=${ROOTDIR}/core_datadir -regtest -addnode=localhost:18555 -addnode=localhost:18666
