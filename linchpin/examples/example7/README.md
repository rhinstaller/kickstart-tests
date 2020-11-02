Example: Adding a new kickstart test
------------------------------------

Run a *test run* with a single new test to be eventually added to `kickstart-test` repository.

A small *target* will be provisioned and the test will be run possibly several times to make it right. At the end the *target* will be destroyed.

#### Resources configuration:

[PinFile](PinFile)

contains these modifications of the [template pinfile](../../PinFile):

* `count` - to use only single *master* *runner* (modified both in the topology and layout)
* `flavor` - to use smaller instance as only one test is run

#### Test configuration:

[test-configuration.yml](test-configuration.yml)

contains modifications to the [default configuration](../../../ansible/roles/kstest-master/defaults/main/test-configuration.yml)

* `kstest_boot_iso_url` - `boot.iso` with installer to be tested
* `kstest_url` - url of the installation repository to be used for the test (should correspond to the `kstest_boot_iso_url`)
* `kstest_tests_to_run` - run only `new-test` test
* `kstest_test_jobs` - run only one test in parallel on a *runner*
* `kstest_git_repo` - the `kickstart-tests` repository with the `new-test` test (`myrepo` below)
* `kstest_git_version` - the repository branch with the `new-test` test


#### Running the test(s)

The script needs to be run from `kickstart-tests` repository.

1) Provision the *target*.

```
scripts/kstests-in-cloud.sh provision example7 --pinfile examples/example7/PinFile
```

2) Create and add the `new-test` test to the remote kickstart-test repository

The `myrepo` repository is the repository defined by `kstest_git_repo` variable of [test-configuration.yml](test-configuration.yml)

```
git checkout -b new-test
vim new-test.sh
vim new-test.ks.in
git add new-test.sh
git add new-test.ks.in
git commit
git push myrepo new-test
```

3) Run the test.

```
scripts/kstests-in-cloud.sh run example7 --test-configuration linchpin/examples/example7/test-configuration.yml --results /tmp/kstest-results-example7
```

The results of the run are stored in a subdirectory of `/tmp/kstest-results-example7`

```
$ tree -L 2 /tmp/kstest-results-example7/
/tmp/kstest-results-example7/
└── runs
    └── example7.2018-11-02-09_47_30

```

4) Fix the test if needed and run it again

Fix the test:
```
vim new-test.ks.in
git commit -a
git push myrepo new-test
```

Test the test:
```
scripts/kstests-in-cloud.sh run example7 --test-configuration linchpin/examples/example7/test-configuration.yml --results /tmp/kstest-results-example7
```

Subdirectory with the results of the new *test run* was added (results were synced from *master*):
```
$ tree -L 2 /tmp/kstest-results-example7/
/tmp/kstest-results-example7/
└── runs
    ├── example7.2018-11-02-09_47_30
    └── example7.2018-11-02-10_03_35

```

5) Destroy the *target*.

```
scripts/kstests-in-cloud.sh destroy example7 --pinfile examples/example7/PinFile
```
