#!/bin/bash
ROOTDIR=$(dirname $0)/../..
echo ROOTDIR is ${ROOTDIR}

rm -rf ${ROOTDIR}/core_datadir/regtest_bob
mkdir ${ROOTDIR}/core_datadir/regtest_bob

BASENAME=$(basename $0)
FILENAME=${BASENAME%.*}
${ROOTDIR}/core_bin/macos/bin/bitcoin-qt -uacomment=${FILENAME} \
-datadir=${ROOTDIR}/core_datadir/regtest_bob -regtest -port=18555 \
-addnode=localhost:18444 -addnode=localhost:18666

