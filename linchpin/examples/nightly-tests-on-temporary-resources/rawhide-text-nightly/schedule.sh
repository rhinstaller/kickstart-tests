#!/bin/bash
./kstests-in-cloud.sh schedule rawhide-text-nightly --pinfile PinFile.rawhide-text-nightly --virtualenv /home/kstest/virtualenv-linchpin --logfile /var/tmp/kstest.rawhide-text-nightly.scheduled_runs.log --when "*-*-* 22:00:00" --key-name kstests --key-use-existing --ansible-private-key ~/.ssh/kstests.pem --key-use-for-master --test-configuration rawhide-text-nightly.test-configuration.yml --ansible-python-interpreter /usr/bin/python3

