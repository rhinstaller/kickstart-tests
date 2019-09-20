#!/bin/bash
./kstests-in-cloud.sh schedule f31-nightly --pinfile PinFile.f31-nightly --virtualenv /home/kstest/virtualenv-linchpin --logfile /var/tmp/kstest.f31-nightly.scheduled_runs.log --when "*-*-* 22:00:00" --key-name kstests --key-use-existing --ansible-private-key ~/.ssh/kstests.pem --key-use-for-master --test-configuration f31-nightly.test-configuration.yml --ansible-python-interpreter /usr/bin/python3

