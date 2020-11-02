Example: Testing a code change running a single test on temporary *target*
--------------------------------------------------------------------------

Run a *test run* with a single test named `user` with Anaconda updates image applying a patch to be tested.

A temporary *target* will be provisioned and destroyed after finishing the *test run*.

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


#### Running the test:

From `kistart-tests` repository root run:
```
scripts/kstests-in-cloud.sh test example1 --pinfile examples/example1/PinFile --test-configuration linchpin/examples/example1/test-configuration.yml --results /tmp/kstest-results-example1
```
The results are stored in `/tmp/kstest-results-example1` as configured with `--results` option.

```
$ tree -L 2 /tmp/kstest-results-example1/
/tmp/kstest-results-example1/
└── runs
    └── example1.2018-11-02-08_46_24
```

For the results run directory content see [playbooks README](../../../ansible/README.md#results)
