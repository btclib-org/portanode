#!/bin/bash
ROOTDIR=$(dirname "$0")/../../..
echo ROOTDIR is ${ROOTDIR}

rm -rf ${ROOTDIR}/bitcoin-datadir/regtest

BASENAME=$(basename $0)
FILENAME=${BASENAME%.*}
${ROOTDIR}/macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt -uacomment=${FILENAME} \
-datadir=${ROOTDIR}/bitcoin-datadir -regtest -addnode=localhost:18555 -addnode=localhost:18666
