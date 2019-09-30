#!/bin/bash

# Activate virtualenv with linchpin
source /home/kstest/virtualenv-linchpin/bin/activate

./kstests-in-cloud.sh destroy quick-start --pinfile PinFile.quick-start --force
