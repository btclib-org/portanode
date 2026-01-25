#!/bin/bash
ROOTDIR=$(dirname "$0")/../../..
echo ROOTDIR is ${ROOTDIR}

# rm -rf ${ROOTDIR}/bitcoin-datadir/regtest_bob
mkdir ${ROOTDIR}/bitcoin-datadir/regtest_bob

BASENAME=$(basename $0)
FILENAME=${BASENAME%.*}
${ROOTDIR}/macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt -uacomment=${FILENAME} \
-datadir=${ROOTDIR}/bitcoin-datadir/regtest_bob -regtest -port=18555 \
-addnode=localhost:18444 -addnode=localhost:18666

