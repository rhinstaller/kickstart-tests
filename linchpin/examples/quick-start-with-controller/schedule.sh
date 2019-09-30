#!/bin/bash

RESULT_DIR=/var/tmp/kstest.results.quick-start
mkdir -p ${RESULT_DIR}

./kstests-in-cloud.sh schedule quick-start --pinfile PinFile.quick-start --virtualenv /home/kstest/virtualenv-linchpin --logfile /var/tmp/kstest.quick-start.scheduled_runs.log --when "*-*-* 20:55:00" --test-configuration linchpin/examples/quick-start-with-controller/quick-start.test-configuration.yml --results ${RESULT_DIR} --ansible-python-interpreter /usr/bin/python3
