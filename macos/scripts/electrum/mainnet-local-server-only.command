#!/bin/bash
BASEDIR=$(dirname "$0")/../../..
open -n ${BASEDIR}/macos/bin/Electrum.app --args \
--dir ${BASEDIR}/electrum-datadir --oneserver --server localhost:50002:s
