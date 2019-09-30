#!/bin/bash
# Run the test including provisioning and destroying of temporary runners.

RESULT_DIR=/var/tmp/kstest.results.quick-start
mkdir -p ${RESULT_DIR}

# Activate virtualenv with linchpin
source /home/kstest/virtualenv-linchpin/bin/activate

./kstests-in-cloud.sh test quick-start --pinfile PinFile.quick-start --test-configuration linchpin/examples/quick-start-with-controller/quick-start.test-configuration.yml --results ${RESULT_DIR} --ansible-python-interpreter /usr/bin/python3
