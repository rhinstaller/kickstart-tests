Example: Testing a change running a single test repeatedly on permanent *target*
--------------------------------------------------------------------------------

Run a *test run* with a single test named `user` with Anaconda updates image applying a patch to test.

A *target* will be provisioned and the test will be run several times with new versions of Anaconda updates. At the end the *target* will be destroyed.

#### Resources configuration:

[PinFile](PinFile)

contains these modifications of the [template pinfile](../../PinFile):

* `count` - to use only single *master* *runner* (modified both in the topology and layout)
* `flavor` - to use smaller instance as only one test is run

#### Test configuration:

[test-configuration.yml](test-configuration.yml)

contains modifications to the [default configuration](../../../ansible/roles/kstest-master/defaults/main/test-configuration.yml)

* `kstest_boot_iso_url` - `boot.iso` with installer to be tested
* `kstest_updates_img` - updates image with installer changes to be tested
* `kstest_url` - url of the installation repository to be used for the test (should correspond to the `kstest_boot_iso_url`)
* `kstest_tests_to_run` - run only `user` test
* `kstest_test_jobs` - run only one test in parallel on a *runner*

#### Running the test(s)

The script needs to be run from `kickstart-tests` repository.

1) Provision the *target*.

```
./kstests-in-cloud.sh provision example2 --pinfile examples/example2/PinFile
```

2) Run the test.

```
./kstests-in-cloud.sh run example2 --test-configuration linchpin/examples/example2/test-configuration.yml --results /tmp/kstest-results-example2
```

The results of the run are stored in a subdirectory of `/tmp/kstest-results-example2`

```
$ tree -L 2 /tmp/kstest-results-example2/
/tmp/kstest-results-example2/
└── runs
    └── example2.2018-11-02-09_47_30

```

3) Update the updates image with better fix.

There is no need to change the test configuration as the updates image of the same name is being updated.

4) Run the test again.

runnig the same `run` command again:

```
./kstests-in-cloud.sh run example2 --test-configuration linchpin/examples/example2/test-configuration.yml --results /tmp/kstest-results-example2
```

Subdirectory with the results of the new *test run* was added (results were synced from *master*):
```
$ tree -L 2 /tmp/kstest-results-example2/
/tmp/kstest-results-example2/
└── runs
    ├── example2.2018-11-02-09_47_30
    └── example2.2018-11-02-10_03_35

```

5) Destroy the *target*.

```
./kstests-in-cloud.sh destroy example2 --pinfile examples/example2/PinFile
```
