#!/bin/bash
./kstests-in-cloud.sh schedule rhel8-nightly --pinfile PinFile.rhel8-nightly --virtualenv /home/kstest/virtualenv-linchpin --logfile /var/tmp/kstest.rhel8-nightly.scheduled_runs.log --when "*-*-* 22:00:00" --key-name kstests --key-use-existing --ansible-private-key ~/.ssh/kstests.pem --key-use-for-master --test-configuration rhel8-nightly.test-configuration.yml --ansible-python-interpreter /usr/bin/python3

