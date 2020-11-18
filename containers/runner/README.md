Running kickstart tests in containers
-------------------------------------

Tooling for running tests in VMs in cloud (OpenStack) is in [../../linchpin](../../linchpin).

The motivation for moving from VMs to containers to run kickstart tests is:
* To be able to use containers tooling for deployment, scheduling and scaling of resources for batches of kickstart tests.
* To allow the user to run a kickstart test manually in an easy way.


Host requirements
-----------------

Dependencies needed to be installed are defined in `host_packages` variable of [vars.yml](vars.yml).
```
sudo dnf install git podman
```

There is a [playbook](runner-host.yml) for deployment of the host on Fedora Cloud Base Image. See [Troubleshooting] for preferred version to be used.

Run a test in a container
-------------------------
Use the [launch](./launch) script to run a set of tests from the current kickstart-tests directory in the runner container:
```
containers/runner/launch keyboard [test2 test3 ...]
```

Call `launch all` to run all tests. This can be controlled further through `--testtype` and/or `--skip-testtypes`, see `--help`.

This will download the [automatically built](.github/workflows/container-autoupdate.yml) [official container image](https://quay.io/repository/rhinstaller/kstest-runner).

You can also build the container yourself to test modifications to it:
```
podman build -t rhinstaller/kstest-runner .
```

The `launch` script creates a `./data/` directory for passing of data between the container and the system (via volume). By default it downloads the current Fedora Rawhide boot.iso, but to test some other image you can put it into `data/images/boot.iso` before running `launch`.

There is also a [daily boot.iso](.github/workflows/daily-boot-iso.yml) built
from Rawhide and various COPRs (e.g. Anaconda and DNF) for regression testing,
which you can test against with the `--daily-iso` option. When given, `launch`
downloads/unpacks that instead of the the official Rawhide boot.iso. This
requires authentication, so the option expects a GitHub token file as value.

The result logs get written into `./data/logs/`:
```
tree -L 3 data/logs
cat data/logs/kstest-*/anaconda/virt-install.log
```

Configuration of the test
-------------------------
For more control, you can run the container manually:
```
podman run -it --name last-kstest --env KSTESTS_TEST=keyboard -v ./data:/opt/kstest/data:z -v .:/kickstart-tests:ro --device=/dev/kvm rhinstaller/kstest-runner
```

Instead of keeping named container you can remove it after the test by replacing `--name last-kstest` option with `--rm`.

Environment variables for the container (`--env` option):
* KSTESTS_TEST - name of the test to be run
* UPDATES_IMAGE - HTTP URL or path (inside the container) of updates image to be used
* KSTESTS_REPOSITORY - kickstart-tests git repository to be used
* KSTESTS_BRANCH - kickstart-tests git branch to be used
* BOOT_ISO - name of the installer boot iso from `data/images` to be tested (default is "boot.iso")

By default, the container runs the [run-kstest](./run-kstest) script. To get an interactive shell, append `bash` to the command line.

Running tests with cached package downloads
-------------------------------------------

Depending on parallelism and availabe network bandwidth, downloading the RPMs
and package indexes takes a significant amount of time for every test. This can
be sped up greatly with a transparent HTTP proxy. This requires root privileges
(to configure IP routing through the proxy) and only works with system podman
containers (which use a real bridge), not user podman containers (which use
SLIRP networking).

To use this, run

    sudo containers/squid.sh start

and build/run the `runner` container from above through `sudo containers/runner/launch` or `sudo podman`.

This starts a container named `squid` and uses a persistent podman volume
`ks-squid-cache`.

Troubleshooting
---------------

### Tests runnable in container
Some tests require services, resources, or configration in VM hypervisor that might not be working in container. Checking the tests and trying to resolve the issues is TBD.
