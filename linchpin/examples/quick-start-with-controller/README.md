Example: Run a single kickstart test in cloud via *controller*
--------------------------------------------------------------

This example shows how to run a single kickstart test in cloud in a few steps and demonstrates further configuration options of the [tooling](../..) for various use case requirements.

A dedicatet host called [*controller*](../../README.md#controller)  is used for the example.

### On your local host:

1) Configure access to the cloud.

Make sure access to the cloud is configured in [`~/.config/openstack/clouds.yml`](clouds.yml) under profile name `kstests` (see [Check openstack cloud access](#check-openstack-cloud-access)).

2) Create the controller host.

This [kickstart](ks.kstest-controller.cfg) can be used for installation of a Fedora host. Just update the public ssh key supplied by the `sshkey` command with your public key.

3) Deploy the controller.

Update [inventory](kstest-controller.inventory.yml) with:
 - IP address of the controller host replacing `<IP_ADDRESS>`
 - public ssh key for user access to the controller in variable `kstest_controller_user_authorized_key`
 - if needed configure the private key ansible needs to use to access the controller host in `ansible_ssh_private_key_file` (ie the key corresponding to the public key in `ssh-key` kickstart command)

Deploy the controller using the inventory:

```
ansible-playbook -i linchpin/examples/quick-start-with-controller/kstest-controller.inventory.yml ansible/kstest-controller-deploy.yml
```

4) Ssh to the controller as `kstest` user.

```
ssh kstest@<IP_ADDRESS>
```

### On the controller:

5) Clone `kickstart-tests` repo and `cd` into it.

```
git clone https://github.com/rhinstaller/kickstart-tests.git
cd kickstart-tests
```

4) Configure the test runners provisioning.

Move the PinFile with the configuration of test runners to be provisioned (defined as target `quick-start` in the [PinFile](PinFile.quick-start)) to the path expected by *linchpin*.

```
cp linchpin/examples/quick-start-with-controller/PinFile.quick-start linchpin/
```

5) Run the test.

Run a small script [test.sh](test.sh) wrapping [kstests-in-cloud.sh](../../README.md) tool. It will create and deploy the `quick-start` target, run the test on it, and destroy the target.

```
linchpin/examples/quick-start-with-controller/test.sh
```

6) See the results.

The [results](../../../ansible/README.md#results) which had been synced from master runner to the controller can be found in `/var/tmp/kstest.results.quick-start` folder as configured in [test.sh](test.sh) script.



Options:
--------

### Deployment, running and scheduling

##### Schedule periodic run of the test.

Run wrapper script [schedule.sh](schedule.sh):
```
linchpin/examples/quick-start-with-controller/schedule.sh
```

Check if the run has been scheduled:
```
systemctl --user list-timers --all
```

To unschedule the test run [unschedule.sh](unschedule.sh):
```
linchpin/examples/quick-start-with-controller/unschedule.sh
```

[Watch the progress of scheduled deployment](#watch-the-progress-of-scheduled-deployment)

##### Deploy runners and run tests in separate steps.

Instead of running the [test.sh](test.sh) in one shot the process can be split into three steps:

* Target provisioning ([provision.sh](provision.sh)):

```
linchpin/examples/quick-start-with-controller/provision.sh
```

* Test run(s) ([run.sh](run.sh)):

```
linchpin/examples/quick-start-with-controller/run.sh
```

* Target destroying ([destroy.sh](destroy.sh)):

```
linchpin/examples/quick-start-with-controller/destroy.sh
```

##### Schedule test run by *master* of a permanent target.

As an alternative to scheduling tests by controller it is possible to schedule them by permanent master host. A permanent target can be deployed by [provision.sh](provision.sh) as in [Deploy runners and run tests in separate steps](#deploy-runners-and-run-tests-in-separate-steps).

Move the scheduling configuration to the place where it overrides [master scheduling playbook](../../../ansible/kstest-master-schedule-test.yml) defaults and configure the scheduling.

```
cp linchpin/examples/quick-start-with-controller/schedule.yml ansible/roles/kstest-master/vars/main/schedule.yml
vim ansible/roles/kstest-master/vars/main/schedule.yml
```

Get the path of the inventory generated during provisioning:

```
./kstests-in-cloud.sh status quick-start --show-inventory
```

Apply the scheduling by the playbook using inventory generated during provisioning:

```
ansible-playbook -i linchpin/inventories/quick-start.inventory ansible/kstest-master-schedule-test.yml
```

Check that the scheduling was applied to master:
```
ansible -i linchpin/inventories/quick-start.inventory kstest-master -a "crontab -l -u kstest" --become
```

To disable the scheduled run with the playbook you can either update the configration `schedule.yml` created above or supply the variable `kstest_master_cron_disabled` to the playbook directly:
```
ansible-playbook -i linchpin/inventories/quick-start.inventory ansible/kstest-master-schedule-test.yml --extra-vars='kstest_master_cron_disabled=true'
```

##### Provision and deploy the controller in cloud.

To deploy the controller on a cloud instance the [inventory](kstest-controller.inventory.yml) may require some modifications:

- set `ansible_ssh_user=fedora`
- set the `ansible_ssh_private_key` to the key corresponding to the public key used for the cloud instance during provisioning 

The playbook was tested to be working with Fedora 29 Cloud Image.

There is also an [example](../controller-provisioning-linchpin) for controller provisioning of with lichpin.

##### Use my local host as controller.

Your local host could well play the role of the controller. Using a dedicated controller host deployed by [ansible playbook]() may be preferred because linchpin installation is not trivial (as of now it is not packaged for Fedora), and the dedicated host may be more suitable for executing (and scheduling) long test runs via ansible playbooks which require the connection throughout the whole run.

To use your local host as a controller you just basically need to install ansible, linchpin, and configure cloud access in `.config/linchpin/clouds.yml`. See the [kstest-controller](../../../ansible/roles/kstest-controller) ansible role for details.

##### Number and size of test runners.

The number of runners and their flavors are defined in [PinFile](PinFile.quick-start) by `flavor` and `count` variables. The third variable in play to balance the load and performance defines how many of tests/VMs should run in parellel on one runner/hypervisor and is set by `kstest_test_jobs` value of [test configuration](quick-start.test-configuration.yml).

For a runner with 8 VCPUs, 16 GB RAM, and 40 GB of storage the appropriate number of parallel tests is 4 (like in [PinFile.quick-start.all-tests.test-configuration](PinFile.quick-start.all-tests.test-configuration) and [quick-start.all-tests.test-configuration.yml](quick-start.all-tests.test-configuration.yml)). To get a rough picture - a test run of 180 tests on 2 such runners takes 8 hours.

### Test configuration

The default test configuration is set and described in [kstest-master role defaults](../../../ansible/roles/kstest-master/defaults/main/test-configuration.yml).

##### Select tests to be run.

By default all available tests are run. To select a subset of the tests for a test run modify the [test configuration](quick-start.test-configuration.yml) with these variables overriding [kstest-master role defaults](../../../ansible/roles/kstest-master/defaults/main/test-configuration.yml):

```
kstest_tests_to_run
kstest_test_type
kstest_skip_test_types
```

It might be also desirable to modify the [number and size of test runners](#number-and-size-of-test-runners) used for the test run in proprotion to the number of selected tests.

##### Configure installer version to be tested.

The installer to be tested is specified by url of the installer *boot.iso* in `kstest_boot_iso_url` variable of [test configuration](quick-start.test-configuration.yml). A test usually also needs to have software source repositories specified which is done by `kstest_url`, `kstest_repos` and `kstest_ftp_url` variables.

To test installer modifications delivered via installer [updates image](https://github.com/rhinstaller/anaconda/blob/master/scripts/makeupdates) set the `kstest_updates_img`.

##### Use additional installer boot options.

Set additional installer boot option to all tests in the run by `kstest_additional_boot_options` variable of [test configuration](quick-start.test-configuration.yml).

Currently it does not work because the `-b` option is broken in [run_one_test.py](../../../scripts/launcher/run_one_test.py) which is used to run tests via `run_kickstart_tests.sh` on master. A workaround would be to modify the default options in the source code ([functions.sh](../../../functions.sh)). Then use the modified branch in the [test configuration](quick-start.test-configuration.yml) by setting `kstest_git_repo` and `kstest_git_version`.

### Status

##### See the status of the runner cloud instances.

Some useful commands inspecting the cloud:

```
openstack --os-cloud kstests server list
openstack --os-cloud kstests server show <id>
openstack --os-cloud kstests keypair list
openstack --os-cloud kstests flavor list
openstack --os-cloud kstests quota show
```

##### See the status of a test run.

To see the status of a test run in progress on `quick-start` target run:

```
./kstests-in-cloud.sh status quick-start
```

##### Watch the progress of scheduled deployment.

To watch the progress of ansible playbook run by scheduler:

```
systemctl --user status kstests-cloud-quick-start.service
```

or watch the log file specified in [schedule.sh](schedule.sh) script:

```
tail -f /var/tmp/kstest.quick-start.schedule.runs.log
```


### Results

The default configuration or results handling is set and described in [kstest-master role defaults](../../../ansible/roles/kstest-master/defaults/main/test-configuration.yml).

##### Push the results to a remote host.

Instead of pulling the tests to the controller as in [run.sh](run.sh) with `--results` option, it is possible to [configure](quick-start.test-configuration.yml) a test run so that master pushes the results to an external server with `kstest_remote_results_path`.

Note that [master's ssh key](../../README.md#ssh-keys) needs to be authorized to access the results server. In the example a throw-away key is generated (eg by [provision.sh](provision.sh)). To see what key should be added to authorized keys to result host look at the `authorized_keys` of a runner (in our case the only runner is the master):
```
ansible -i linchpin/inventories/quick-start.inventory kstest-master -a "cat /home/kstest/.ssh/authorized_keys" --become
```

If you want to push results to remote server it would be easier to use `--use-key-for-master` option in [provision.sh](provision.sh) so that the key generated for deployment (*deployment key*) is used also for master (*master key*). In this case the key to be added to results server can be found in the target-specific directory for generated *deployment key*. For this `quick-start` example the key is:
```
ls linchpin/keys/quick-start/*pub
```

##### Don't keep the results on the master.

By default the results of a test run are kept on the master after the results are [pushed to a remote host](#push-the-results-to-a-remote-host). To delete the results after the run (and eventually results push) set `kstest_remote_results_keep_local` in the [test configuration](quick-start.test-configuration.yml).

##### Generate results overview.

To generate summary html page from a folder containing [results](../../../ansible/README.md#results) of multiple test runs there is a rudimentary Python 3 [script](../../../ansible/roles/kstest-master/files/scripts/kstests_history.py) available

##### Change template of test run results folder name.

A test run [results](../../../ansible/README.md#results) are stored in a folder with generated name (based on timestamp by default). To modify the name you can use `kstest_result_run_dir_prefix` and `kstest_result_run_dir_suffix` in the [test configuration](quick-start.test-configuration.yml).

### Credentials

##### Use existing keypair from cloud.

To use a keypair already existing in cloud (for example a keypair named `kstests`) for runners deployment add these options to [provision.sh](provision.sh) or [run.sh](run.sh):
```
--key-use-existing --key-name kstests --ansible-private-key ~/.ssh/kstests.pem
```

The `--ansible-private-key` defines private key used for ansible access to the provisioned hosts (configured via target inventory - `linchpin/inventories/quick-start.inventory` in our example).

To upload the `kstests.pem` private key to the controller using [controller deployment playbook](../../../ansible/kstest-controller-deploy.yml) define the `private_keys_to_upload` variable of [controller deployment role](../../../ansible/roles/kstest-controller/defaults/main.yml), for example via [inventory](kstest-controller.inventory.yml) and re-run the playbook.

It may be a good idea to use the key also as [master key](../../README.md#ssh-keys), for example if the results are pushed from master to a remote host which needs to have master's public key added to authorized keys. In this case add also `--key-use-for-master` option.

##### Use existing local keypair.

To use a local keypair of which the public key will be uploaded to the cloud under specified name (for example `mykey`) for runners deployment add these options to [provision.sh](provision.sh) or [run.sh](run.sh):

```
--public-key-upload <PATH_TO_THE_PUBLIC_KEY> --key-name mykey
```

If the key is not the default one used for ssh connections you may need to set it for ansible access to the provisioned hosts (configured via target inventory - `linchpin/inventories/quick-start.inventory` in our example) by adding the path to the private key, for example:
```
--public-key-upload <PATH_TO_THE_PUBLIC_KEY> --key-name mykey --ansible-private-key <PATH_TO_THE_PRIVATE_KEY>
```

In this case you probably don't want to use the private key as [master's ssh key](../../README.md#ssh-keys). If you do, add also `--key-use-for-master` option.

##### Watch the running tests with virt-manager.

Add public key for virt-manager connection to the runners' authorized keys by copying them into a special directory of [kstest runner role](../../../ansible/roles/kstest) and running the kstest runners deployment playbook:

```
cp <PATH_TO_THE_PUBLIC_KEY> ansible/roles/kstest/files/authorized_keys
ansible-playbook -i linchpin/inventories/quick-start.inventory ansible/kstest-runners-deploy.yml --tags "ssh-keys"
```
Only the playbook tasks tagged "ssh-keys" are run to be faster.

To see the IP addresses of runners for adding connections to virt-manager run:
```
./kstests-in-cloud.sh status quick-start --show-inventory
```

##### Use different cloud profile.

The cloud profile is used for provisioning and destoying of runners (or even controller) in cloud.

Default location of cloud configuration file for controller deployment is:
```
~/.config/openstack/clouds.yml
```
from where the configuration is passed to the controller to default location for linchpin which used to provision master and runners:
```
~/.config/linchpin/clouds.yml
```

Default profile is `kstests`. To use another profile set `--cloud` option of `kststs-in-cloud.sh` (eg in [test.sh](test.sh)).


### Troubleshooting

See also [Status](#status)

##### Check openstack cloud access.

Having `~/.config/openstack/clouds.yml` configured with `kstests` profile, to check the access run:

```
openstack --os-cloud kstests server list
```

##### Stop running test.

If the test is run from controller as in [run.sh](run.sh) or [test.sh](test.sh) just interrupt (CTRL-C) or terminate the ansible process.

If the test was scheduled from controller stop the service:
```
systemctl --user stop kstests-cloud-quick-start.service
```

If the test was scheduled from master just [destroy](destroy.sh) the runners.

##### Clean up interrupted test or provisioning.

For now the only really safe option after [stopping a running test](#stop-running-test) is [destroying](destroy.sh) the target and re-provisioning the target.

I'd like to add playbooks for better interrupted or broken test handling:

- stop the test run with processing of results obtained so far
- stop the test run and clean up the runners for the next test run
- clean up runners for the next run
