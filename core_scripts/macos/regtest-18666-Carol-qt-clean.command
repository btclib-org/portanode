#!/bin/bash
ROOTDIR=$(dirname $0)/../..
echo ROOTDIR is ${ROOTDIR}

rm -rf ${ROOTDIR}/core_datadir/regtest_carol
mkdir ${ROOTDIR}/core_datadir/regtest_carol

BASENAME=$(basename $0)
FILENAME=${BASENAME%.*}
${ROOTDIR}/core_bin/macos/bin/bitcoin-qt -uacomment=${FILENAME} \
-datadir=${ROOTDIR}/core_datadir/regtest_carol -regtest -port=18666 \
-addnode=localhost:18444 -addnode=localhost:18555

