#!/bin/bash
BASEDIR=$(dirname $0)/../..
open -n ${BASEDIR}/electrum_bin/macos/Electrum.app --args \
--dir ${BASEDIR}/electrum_data --testnet