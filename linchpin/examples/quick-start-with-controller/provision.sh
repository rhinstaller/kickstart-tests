#!/bin/bash

# Activate virtualenv with linchpin
source /home/kstest/virtualenv-linchpin/bin/activate

./kstests-in-cloud.sh provision quick-start --pinfile PinFile.quick-start --ansible-python-interpreter /usr/bin/python3
