#!/bin/bash
BASEDIR=$(dirname $0)/../../
open -n ${BASEDIR}/electrum_bin/macos/Electrum.app --args \
--dir ${BASEDIR}/electrum_data --oneserver --server localhost:50002:s
