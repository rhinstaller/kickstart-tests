#!/bin/bash

RESULT_DIR=/var/tmp/kstest.results.quick-start
mkdir -p ${RESULT_DIR}

./kstests-in-cloud.sh run quick-start --test-configuration linchpin/examples/quick-start-with-controller/quick-start.test-configuration.yml --results ${RESULT_DIR}
