Example: Testing a change on subset of tests run parallelly on two temporary *targets*
--------------------------------------------------------------------------------------

Run a *test run* with functional subset of tests - networking tests - and compare the results with another *test run* applying a patch/change via Anaconda updates image.

Two temporary *targets* will be used for testing original and patched Anaconda. The *test runs* will be run on the *targets* in parallel.

#### Resources configuration:

[PinFile](PinFile) is defining two *targets* `network-tests` and `network-tests-patched` sharing the same [topology](../../topologies/kstests.yml) and inventory [layout](../../layouts/kstests.yml).


#### Test configuration:

There are two test configurations:

* [test-configuration.yml](test-configuration.yml) for the reference test
* [test-configuration.patched.yml](test-configuration.patched.yml) for test with updates applied

They contain modifications to the [default configuration](../../../ansible/roles/kstest-master/defaults/main/test-configuration.yml)

* `kstest_boot_iso_url` - `boot.iso` with installer to be tested
* `kstest_updates_img` - updates image with installer changes to be tested
* `kstest_url` - url of the installation repository to be used for the test (should correspond to the `kstest_boot_iso_url`)
* `kstest_tests_type` - run only tests of type `network`

#### Running the tests:

The script needs to be run from `kickstart-tests` repository.

1) Run tests on both *targets* in parallel:


Run `network-tests` target:
```
./kstests-in-cloud.sh test network-tests --pinfile examples/example3/PinFile --test-configuration linchpin/examples/example3/test-configuration.yml --results /tmp/kstest-results-network-patch
```
Switch to another terminal and run `network-tests-patched` *target*:

```
./kstests-in-cloud.sh test network-tests-patched --pinfile examples/example3/PinFile --test-configuration linchpin/examples/example3/test-configuration.patched.yml --results /tmp/kstest-results-network-patch
```

After the tests start running (provisioning of the resources and deployment takes a while) you can check the status of the tests in yet another terminal:
```
./kstests-in-cloud.sh status network-tests
./kstests-in-cloud.sh status network-tests-patched

```

Note that both runs are fetching the logs into the same directory for further processing and comparison:

```
$ tree /tmp/kstest-results-network-patch/ -L 2
/tmp/kstest-results-network-patch/
└── runs
    ├── network-tests.2018-11-03-15_40_20
    └── network-tests-patched.2018-11-03-15_40_19

```

2) Comparing the results:

A rudimentary script is available to produce history of the *test runs* from a given directory on single html page with links to the test logs:

```
ansible/roles/kstest-master/files/scripts/kstests_history.py /tmp/kstest-results-network-patch/runs > /tmp/kstest-results-network-patch/summary.html
```

