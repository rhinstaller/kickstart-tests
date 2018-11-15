Example: Schedule nightly *test run* on a temporary *target*
------------------------------------------------------------

Schedule a nightly *test run* of all tests.

The *target* will be created before running the *test run* and destroyed after. Results will be synced to the local host.

For alternative approach to *test run* scheduling see also these [example](../example5).

#### Resources configuration:

[PinFile](PinFile)

#### Test configuration:

* [test-configuration.yml](test-configuration.yml) defines test subject - points to the latest build of installer and corresponding installation repositories.

contains modifications to the [default configuration](../../../ansible/roles/kstest-master/defaults/main/test-configuration.yml)

* `kstest_boot_iso_url` - `boot.iso` with installer to be tested
* `kstest_url` - url of the installation repository to be used for the test (should correspond to the `kstest_boot_iso_url`)
* `kstest_ftp_url` - FTP url of installation repository (required for *ftp* tests).

#### Scheduling the test:

1) Schedule the test on *target*.
```
./kstests-in-cloud.sh schedule nightly1 --pinfile examples/example4/PinFile --test-configuration linchpin/examples/example4/test-configuration.yml --results /tmp/kstest-results-nightly --virtualenv /home/rvykydal/work/linchpin/linchpin-latest --logfile /tmp/kstest-results-nightly/sheduled_runs.log --when "Mon-Fri *-*-* 00:00:05"
```

The results will be pulled to local host to `--results` directory.


2) Check the created timer.
```
systemctl --user list-timers --all | grep nightly1
```

3) After a scheduled *test run* has been run see the *script* log.

```
cat /tmp/kstest-results-nightly/scheduled_runs.log
```

4) Present history of the tests in a summary.

A rudimentary script is available to produce history of the *test runs* in a given directory on single html page with links to the test logs:
```
ansible/roles/kstest-master/files/scripts/kstests_history.py /tmp/kstest-results-nightly/runs > /tmp/kstest-results-nightly/summary.html
```

The script can be passed `-s NUMBER_OF_RUNS` option that would mark tests with interesting (failing) results based on latest `NUMBER_OF_RUNS` runs.

5) Remove the *test run* scheduling.

```
./kstests-in-cloud.sh schedule nightly1 --remove
```

#### Syncing results by pushing to remote host:

In the example above the results are pulled to the local host into a directory defined by `--results` option.

It is also possible to have the results pushed from *master* to a remote *results host*. The *master* has to be authorized to rsync the result to the *results host* so in this case it makes sense to use existing [ssh key](../../README.md#ssh-keys) that would be added to the *results host's* authorized keys as *master* key.

The [test configuration](test-configuration.push.yml) is updated with location of the *results host* (`kstests_remote_results_path`).

The command to schedule the test is modified by removing `--results` option (we don't want to pull the results to the local host) and using specific ssh key:

```
./kstests-in-cloud.sh schedule nightly1 --pinfile examples/example4/PinFile --test-configuration linchpin/examples/example4/test-configuration.yml --virtualenv /home/rvykydal/work/linchpin/linchpin-latest --logfile /tmp/kstest-results-nightly/sheduled_runs.log --when "Mon-Fri *-*-* 00:00:05" --key-name kstests --key-use-existing --key-use-for-master
```



