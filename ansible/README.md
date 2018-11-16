Playbooks for running kickstart tests on remote hosts
=====================================================

The playbooks allow to deploy remote hosts for running kickstart tests (the *runners*). The tests can be run either from local host (using [run_kickstart_tests.sh](../scripts/run_kickstart_tests.sh)) or from one of the *runners* deployed further as the *master*. On the *master* the tests can be also configured and scheduled for periodical runs. The *master* can store and forward the results of the executed *test runs*.

The hosts used for deployment of *runner*s and *master* can be provisioned for example in cloud using [linchpin tooling](../linchpin). There is a [script](../kstests-in-cloud.sh) leveraging the playbooks for complete provisioning, deployment and running of a kickstart test, taking care of creating the inventory for the playbooks.

Using the playbooks for deployment of the *runners* independently of the linchpin script may require some [deployment configuration](#deployment-configuration) depending on how the hosts to be used for *runners* have been provisioned with regard to access to the hosts.


The playbooks
-------------

*runner*:

* `kstest-runners-deploy.yml` - deploys *runners* - hosts on which the tests can be run remotely

*master*:

* `kstest-master-deploy.yml` - deploys *master* runner (on top of a *runner*) from which the tests can be run or scheduled and which can also store and forward test results
* `kstest-master-configure-test.yml` - [configures a *test run*](#test-configuration) to be run from *master* on *runners*
* `kstest-master-run-test.yml` - runs a *test run* from *master* on *runners* (including the *master*)
* `kstest-master-show-test-status.yml` - shows the status of a *test run* initatiated from *master*
* `kstest-master-fetch-results.yml` - synchronizes test [results](#results) from *master* to local host
* `kstest-master-schedule-test.yml` - [schedules](#scheduling-configuration) *test runs* on *master*


Deployment configuration
------------------------

Before running the playbooks the inventory file has to be populated with hosts. When using [linchpin](../linchpin) this is done automatically. The default inventory directory configured in [ansible.cfg](ansible.cfg) contains a template [hosts](inventory/hosts) that can be used as a base of the inventory file.


```
[kstest]

[kstest-master]

[all:vars]
#ansible_python_interpreter=/usr/bin/python3
#ansible_ssh_private_key_file=
#ansible_ssh_user=fedora
#ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

Depending on the provisioning, access to the hosts may need to be additionally configured:

* Deployment private ssh key: path to the key for accessing the provisioned hosts by ansible for deployment may need to be set up. It can be done
    - in the inventory with `ansible_ssh_private_key` host group variable
    - in [ansible.cfg](ansible.cfg) with `private_key_file` variable
    - by passing `--private-key` to `ansible-playbook`

* Remote user used for deployment may need to be configured. For example Fedora cloud images are using `fedora` user, RHEL cloud images `cloud-user` user. It can be done
    - in the inventory with `ansible_ssh_user` host group variable
    - in [ansible.cfg](ansible.cfg) `remote_user` variable

* Access to *runners* can be further configured by dropping public ssh keys into [roles/kstest/files/authorized_keys](roles/kstest/files/authorized_keys) folder. These keys will be added to *runner*'s authorized keys. (Note that thanks to idempotency of the playbooks this can be done by re-running `kstest-runners-deploy.yml` playbook later after the *runners* are deployed).

* *Master* is using a *master key* for accessing the *runners* when distributing the *test run*. By default a new keypair is generated when deploying the *master* with `kstest-master-deploy.yml` playbook. It is possible to use custom keypair by setting the playbook variables `master_private_ssh_key` and `master_public_ssh_key` to the paths to the keys. This can be useful if automatic [syncing](#syncing) of results from master to a remote *resutlts host* is used.

To use python 3 for running the playbooks on deployed hosts set the `ansible_python_interpreter` variable. By default python 2 will be installed to the *runners* during deployment.

NOTE: It is also possible to specify the inventory and configure access to *runners* in `ansible.cfg` file by updating `inventory`, `remote_user` and `ssh_private_key` variables. In this case the inventory does not have to be passed to the playbooks with `-i` option. The file should be placed in current working directory.
```
cp ansible/ansible.cfg .
vim ansible.cfg
```

Test configuration
------------------

The configuration of the *test run* to be run from the *master* is internally done by setting up the run script (`/home/kstest/run_tests.sh`) on the *master* host with `kstest-master-configure-test.yml` playbook:

```
ansible-playbook kstest-master-configure-test.yml
```

Default test configuration values are defined in `kstest-master` role's configuration [file](roles/kstest-master/defaults/main/test-configuration.yml) and can be overriden in several ways:

* change the values in the default [file](roles/kstest-master/defaults/main/test-configuration.yml)
* override some variables with a file dropped in the role's vars directory, for example `roles/kstest-master/vars/main/test-configuration.yml`.
* use playbook extra variable to set up the configuration file to be used:
```
ansible-playbook --extra-vars 'test_configuration=/path/to/the/my-test-config.yml' kstest-master-configure-test.yml
```
* use playbook extra variables to override specific test configuration variables:
```
ansible-playbook --extra-vars 'kstest_updates_img=http://<URL> kstest_test_to_run="user hostname"'
kstest-master-configure-test.yml
```

Scheduling configuration
------------------------

A) *Test runs* can be scheduled by `cron` on *master* using a playbook:

```
ansible-playbook kstest-master-schedule-test.yml
```

Default scheduling configuration values are defined in kstest-master role's [scheduling variables file](roles/kstest-master/defaults/main/schedule.yml) and can be overriden by several means:

* change the values in the [default file](roles/kstest-master/defaults/main/schedule.yml)
* override some variables with a file dropped in the role's vars directory, for example `roles/kstest-master/vars/main/schedule.yml`.
* use playbook extra variables to override specific variables, for example to disable the scheduled test:
```
ansible-playbook --extra-vars 'kstest_schedule_cron_disabled=true' kstest-master-schedule-test.yml

```

B) It is also possible to schedule running the *test runs* on temporarily provisioned cloud resources with [linchpin](../linchpin/README.md#scheduling-a-test-run) script (setting up local host user systemd timer via a playbook).

Results
-------

By default the results and logs from a *test run* are stored on *master* in kstest user's home subdirectory `results` (`/home/kstest/results`) and are namespaced by the start time of the test run by default.

```
└── results
    └── runs
        └── 2018-06-03-22_00_02
            ├── isomd5sum.txt
            ├── kstest-autopart-encrypted-1.EfLCR2oF
            ├── kstest-bindtomac-ifname-httpks.fb8MlKI6
            ├── kstest-bootloader-4.DNBcteR2
            ├── kstest-clearpart-3.nACu3YPn
            ├── kstest.log
            ├── result_report.txt
            └── test_parameters.txt
```

* `runs` directory contains subdirectories with *test run* results
* `kstest-<TESTNAME>.*` directory contains logs and results for TESTNAME test
* `isomd5sum.txt` contains md5 sum of the installer iso used for the *test run*
* `kstest.log` is the output of `run_kickstart_tests.sh` command
* `result_report.txt` is an overall *test run* report generated by `scripts/run_results.sh` from `kstest.log`
* `test_parameters.txt` contains information about parameters of the *test run* (used repo, consumed time, ...)

#### Locations customization

The names of directories and files are configurable overriding ansible variable defaults from configuration files [roles/kstest-master/defaults/main/test-configuration.yml](roles/kstest-master/defaults/main/test-configuration.yml) and [roles/kstest-master/vars/main/main.yml](roles/kstest-master/vars/main/main.yml).

The configuration of results is applied by `kstest-master-configure-test.yml` playbook:

```
ansible-playbook kstest-master-configure-test.yml
```

#### Syncing

A) Pull from *master* to the local host:

The results of tests can be synced from *master* to local host using `kstest-master-fetch-results.yml` playbook. The local directory is configurable by `local_dir` ansible variable (by default a temporary directory in `/tmp` is created).
```
ansible-playbook --extra-vars='local_dir=/tmp/kstest-results' kstest-master-fetch-results.yml
```

B) Automatic push from *master* to a remote host:

*Master* can be configured to sync results to a remote host automatically when a test run fininshes. It is set by `kstest_remote_results_*` variables whose defaults are configured in [roles/kstest-master/defaults/main/test-configuration.yml](roles/kstest-master/defaults/main/test-configuration.yml) and applied by `kstest-master-configure-test.yml` playbook:
```
ansible-playbook --extra-vars='kstest_remote_results_path=user@results_server:results kstest_remote_results_keep_local=no' kstest-master-configure-test.yml
```
Note: the remote host for storing results needs to have *master* authorized for syncing the results. For example by adding `master_private_ssh_key` from *master* role to authorized keys.


Use case examples
-----------------

#### A) Run a *test run* from local host on deployed *runners*

Kickstart tests will be run remotely on multiple hosts with `run_kickstart_tests.sh` script (it is internally using `parallel`). The script distributes the installer boot iso and kickstart tests repository to the hosts, runs the tests in parallel, and fetches the logs from the hosts.

0) Clone the `kickstart-tests` repository and enter it as working directory.

```
git clone https://github.com/rhinstaller/kickstart-tests.git
cd kickstart-tests
```

1) Populate the inventory.

Make sure ansible inventory of `kstest` group is [populated and configured](#deployment-configuration) to access the hosts to be deployed.

```
cp ansible/inventory/{hosts,mytest.inventory}
vim ansible/inventory/mytest.inventory
```

2) Deploy the runners.

```
ansible-playbook -i ansible/inventory/mytest.inventory ansible/kstest-runners-deploy.yml
```

3) Run the test.

The tests must be run from the local `kickstart-tests` git repository root.

```
TEST_REMOTES=<IP1 IP2 ...> TEST_REMOTES_ONLY=yes scripts/run_kickstart_tests.sh -i ../boot.iso -k 1 hostname.sh user.sh
```

Remote runnig of tests is driven by these environment variables (the variables can be defined also in `kickstart-tests/defaults.sh` file):

* `TEST_REMOTES` - remote hosts used for the *test run* (`kstest` hosts from inventory)
* `TEST_REMOTES_ONLY` - set to `yes` if the tests should not be run on local host
* `TEST_JOBS` - number of jobs (installation VMs) run in parallel on single *runner* (default value is 4)

The repo used for installation is defined in `scripts/defaults.sh` `KSTEST_URL` variable.

4) Look at the results.

It may be a good idea to capture the output of `run_kickstart_tests.sh` script into a file with `tee` and run `scripts/run_report.sh` on the file to create the overall results report.

The logs will be fetched into ``/var/tmp/kstest-*`` directories on local host at the end of the *test run*.

#### B) Run a *test run* from *master* on *runners*

The *test run* will be run from *master* on *runners* (including the *master*). The results of the *run* can be managed by the *master*.

0) Clone the `kickstart-tests` repository and enter `ansible` subdirectory as working directory.

```
git clone https://github.com/rhinstaller/kickstart-tests.git
cd kickstart-tests/ansible
```

1) Populate the inventory.

Make sure ansible inventory of `kstest` and `kstest-master` groups is [populated and configured](#deployment-configuration) for accessing the hosts to be deployed.

```
cp inventory/{hosts,mytest.inventory}
vim inventory/mytest.inventory
```

2) Deploy the runners and the master.
```
ansible-playbook -i inventory/mytest.inventory kstest-runners-deploy.yml
ansible-playbook -i inventory/mytest.inventory kstest-master-deploy.yml

```

3) Configure the *test run*.

[Configure the test](#test-configuration) on the *master*:
```
ansible-playbook -i inventory/mytest.inventory kstest-master-configure-test.yml
```

4) Run the *test run*.

```
ansible-playbook -i inventory/mytest.inventory kstest-master-run-test.yml
```

It is possible to check the status of the running *test run* (from another terminal).

```
ansible-playbook -i inventory/mytest.inventory kstest-master-show-test-status.yml
```

5) Fetch the results to local host.

```
ansible-playbook -i inventory/mytest.inventory --extra-vars='local_dir=/tmp/kstest-results' kstest-master-fetch-results.yml
```

#### C) Scheduling nightly tests on *master*

The *test run* will be run from *master* on *runners* (including the *master*).

0) Clone the `kickstart-tests` repository and enter `ansible` subdirectory as working directory.

```
git clone https://github.com/rhinstaller/kickstart-tests.git
cd kickstart-tests/ansible
```

1) Populate the inventory.

Make sure ansible inventory of `kstest` and `kstest-master` groups is [populated and configured](#deployment-configuration) for accessing the hosts to be deployed.

```
cp inventory/{hosts,mytest.inventory}
vim inventory/mytest.inventory
```

2) Deploy the runners and the master.
```
ansible-playbook -i inventory/mytest.inventory kstest-runners-deploy.yml
ansible-playbook -i inventory/mytest.inventory kstest-master-deploy.yml
```

3) Configure the *test run*.

[Configure](#test-configuration) the *test run* on *master*:
```
ansible-playbook -i inventory/mytest.inventory kstest-master-configure-test.yml
```

4) Configure result synchronization.

See B) of [syncing](#syncing) for details.

```
ansible-playbook -i inventory/mytest.inventory --extra-vars='kstest_remote_results_path=user@results_server:results kstest_remote_results_keep_local=no' kstest-master-configure-test.yml
```

You need to authorize *master* for accessing the `results_server` with rsync.

5) Schedule the *test run*.

See [scheduling configuration](#scheduling-configuration) for details.

To schedule the *test run* to be run nigthly (the default) just enable the scheduling:
```
ansible-playbook -i inventory/mytest.inventory --extra-vars 'kstest_schedule_cron_disabled=false' kstest-master-schedule-test.yml
```
