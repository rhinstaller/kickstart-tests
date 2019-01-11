Running kickstart tests in cloud
================================

There is a suite of [ansible playbooks](../ansible) for running kickstart tests on remote hosts (*runners*) deployed by the playbooks.

Using `linchpin`, the *runners* can be provisioned in cloud while creating respective inventory for the playbooks.

To pull *runners* provisioning (linchpin) and deployment (ansible), *test run* configuration (ansible), *test run* execution (ansible), results gathering (ansible), and *runners* teardown (linchpin) together there is a [kstests-in-cloud.sh](../kstests-in-cloud.sh) script available. 

Requirements
-----------

The script requires `linchpin` and `ansible` to be installed. Linchpin `pip` installation in `virtualenv` is desribed in [documentation](https://linchpin.readthedocs.io).

Linchpin target
---------------

Linchpin *target* is the reference to the group of cloud resources (hosts) used for *test runs*. It is possible to work with multiple *targets* from  a single `kickstart-tests` repository in parallel, but only a single *target* of a given name should be used from a single local host at the same time.

The resources to be provisioned for a *target* are defined in a linchpin *pinfile*. By default the template [PinFile](PinFile) would be used. The file contains one template *target* `kstests`. Custom *targets* can be either added to the file or defined in a separate file which is passed to the [script](../kstests-in-cloud.sh) with `--pinfile` option.

Cloud credentials
-----------------

The cloud credentials need to be provided in the file and profile referred by `credentials` variable of the *target's* *pinfile*. Example [PinFile](PinFile) names the file `clouds.yml`. The default value of the `cloud_profile` variable is defined in the [script](../kstests-in-cloud.sh) as `kstest` (can be configured by `--cloud` option). By default the file will be looked up in `~/.config/linchpin`. The example of credentials configuration for `kstests` profile:

```
$ cat ~/.config/linchpin/clouds.yml
clouds:
  kstests:
    auth:
      auth_url:
      project_name:
      username:
      password:
```

Resources configuration
-----------------------

#### Resource types

A kickstart *test run* (a batch of selected individual tests) can be run using two types of remote runners:

* *runners* - Hosts that can be used as remote runners for individual tests distributed in the *test run*. The tests are run as instrumented kickstart installations in kvm guests on *runner* hypervisors.
* *master* - Is an enhanced *runner* which can serve as the executor of a *test run*, taking care of the *test run* configuration, distribution to *runners*, and results gathering and forwarding.

For more details see [ansible playbooks](../ansible/README.md) for deployment and running of kickstart tests. The playbooks are applied to *runners* and *master* defined in [inventory](../ansible/inventory/hosts) groups `kstest` and `kstest-master`. The inventory for a *target* is generated automatically when provisioning the hosts with `linchpin`.

To learn the path to the inventory generated for *target* `TARGET` (for example to run the playbooks individually on provisioned *target*), use `status` command:
```
kstest-in-cloud.sh status <TARGET>
```

#### Resoruces configuration

A *target*'s resources are defined in a *pinfile*. Template [PinFile](PinFile) defines openstack *target* `kstests`. A custom *target* can be either added to the file or defined in another file passed to the script by `--pinfile` option. See [examples](examples). Sometimes it makes more sense to define multiple *targets* in a non-flat [exapmles/example3/PinFile](examples/example3/PinFile) including shared [topology](topologies/kstests.yml) and [inventory layout](layouts/kstests.yml) definitions.

Some of the values need to be configured for used cloud resource pools, for example `fip_pool` and `networks`.

Some of them may be modified depending on the amount of required resources (RAM, storage, CPUs) estimated by the number of tests included in the *test run*:

* `count` - Number of *runners* (including *master*) to be provisioned. [Example](examples/example1/PinFile) of using only one single *runner* which also serves as *master*
* `flavor` - Size of the *runner* (RAM, CPUs, storage). This value is related to the number of tests (kvm guests) to be run on a *runner* in parallel which is configurable by [`kstest_tests_jobs`](../ansible/roles/kstest-master/defaults/main/test-configuration.yml) variable or [test configuration](#test-run-configuration). For example for running 4 tests in parallel 8 CPUs, 16 GB of RAM, and 40 GB of storage should be enough.

Some of them may require using a *script* parameter:

* `image` - Cloud image to be used as the base for *runners* deployment. This may require setting the default remote user for deployment by `--remote-user` option. (For example Fedora cloud images have `fedora` user, RHEL cloud images have `cloud-user`.)

Depending on the OS image used it may be possible to use python 3 for ansible playbooks on deployed hosts by setting the `--ansible-python-interpreter` to the python 3 interpreter path.

Ssh keys
--------

By default all needed keys will be automatically generated when provisioning a *target*, but it is possible to configure keys to be used.

There are two ssh keypairs:

* *Deployment key* - Used by ansible to access *master* and *runners*. By default a new keypair is generated in the cloud. There are options to use existing key or upload a key to the cloud (`--key-use-existing`, `--key-upload`). The key name (of the key to be generated or used or uploaded) is specified by `--key-name` option.
* *Master key* - Used by *master* to access *runners* for distribution of a *test run*. By default a new throw-away keypair is generated. It is possible to use the *deployment key* with `--key-use-for-master` option. To authorize additional keys on *runners* drop them into [../ansible/roles/kstest/files/authorized_keys](../ansible/roles/kstest/files/authorized_keys) before provisioning (this can be done also after provisioning with [../ansible/kstest-runners-deploy.yml](../ansible/kstest-runners-deploy.yml) playbook) 



*Test run* configuration
------------------------

Default test configuration is defined in ansible kstest-master role's [test-configuration.yml](../ansible/roles/kstest-master/defaults/main/test-configuration.yml) file. The default values can be overriden in a file passed to the script with `--test-configuration` option ([example custom configuration](examples/example1/test-configuration.yml)).

The [details](../ansible/README.md#test-configuration).

Results
-------

The results and logs are stored in directory passed by `--results` option. For the structure of the results see [details](../ansible/README.md#results).

To show the status and temporary results of a *test run* currently running on a *target* run the script with `status` command.
```
kstest-in-cloud.sh status <TARGET>
```

Scheduling a *test run*
-----------------------

To schedule a *test run* on a temporarily provisioned *target* just replace the `test` command with `schedule` and add scheduling related options eventually (as in this [example](examples/example4)):

```
./kstests-in-cloud.sh schedule nightly1 --pinfile examples/example4/PinFile --test-configuration linchpin/examples/example4/test-configuration.yml --results /tmp/kstest-results-nightly --virtualenv /home/rvykydal/work/linchpin/linchpin-latest --logfile /tmp/kstest-results-nightly/sheduled_runs.log --when "Mon-Fri *-*-* 00:00:05"
```

* `--when` - systemd's timer specification
* `--logfile` - log of the scheduled *script* run
* `--virtualenv` - required if linchpin is installed in `virtualenv`

To remove a schedule for the *target* run:
```
kstest-in-cloud.sh schedule <TARGET> --remove
```
As can be seen in the example the results can be configured to be either pulled from local host or to be pushed from the *master* to a remote *results host*.

In the latter case the *master* has to be authorized to rsync the results to the *results host* so it makes sense to use existing [ssh key](#ssh-keys) that would be added to the *results host's* authorized keys as *master* key (`--key-name=kstests --ansible-private-key=~/.ssh/kstests.pem --key-use-for-master`)

It is also possible to set up the scheduling on the *master* of a permanent *target* (using *master's* `cron`). See this [example](examples/example5).

Examples
--------

[examples](examples)
