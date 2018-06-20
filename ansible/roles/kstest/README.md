Running installer kickstart tests on remote hosts
=================================================

Kickstart tests can be run remotely on multiple hosts using `parallel` via `run_kickstart_tests.sh` script. The script distributes the installer boot iso and kickstart tests repository to the hosts, runs the tests in parallel, and fetches the logs from the hosts.

Remote hosts deployment
-----------------------

The deployment is done with `kstest.yml` playbook.

Before running it:

* Inventory and ansible configuration has to be updated based on the provisioned hosts - see [README](../../README.md).
* Public keys authorized to run tests on the hosts have to be added to [files/authorized_keys](files/authorized_keys) directory.

The deployment is done by running:

```
ansible-playbook kstest.yml
```

Running the test
----------------

The tests must be run from the local `kickstart-tests` git repository root:

```
TEST_REMOTES=<IP1 IP2 ...> TEST_REMOTES_ONLY=yes scripts/run_kickstart_tests.sh -i ../boot.iso -k 1 hostname.sh user.sh
```

Remote runnig of tests is driven by these environment variables (the variables can be defined also in `kickstart-tests/defaults.sh` file):

* `TEST_REMOTES` - remote hosts used for the test run
* `TEST_REMOTES_ONLY` - set to `yes` if the tests should not be run on local host
* `TEST_JOBS` - number of jobs (installation VMs) run in parallel on one host

The repo used for installation is defined in `scripts/defaults.sh` `KSTEST_URL` variable.

Seeing the results
------------------

It may be a good idea to capture the output of `run_kickstart_tests.sh` script into a file with `tee` and run `scripts/run_report.sh` on the file to create the overall results report.

The logs will be fetched into ``/var/tmp/kstest-*`` directories on local host at the end of the test run.


