# Running kickstart tests in container

The runner container provides a well-defined and reproducible environment with
all the dependencies necessary to run the tests. It makes it easy for developers
to run the tests locally without permanent change to their system, as well as
running them in CI in _exactly_ the same way.

The container can be run with podman or docker.

Use the [launch](./launch) script to run a set of tests from the current
kickstart-tests directory in the runner container:

    containers/runner/launch keyboard [test2 test3 ...]

Call `launch all` to run all tests. This can be controlled further through `--testtype` and/or `--skip-testtypes`, see `--help`.

This will download the [automatically built](.github/workflows/container-autoupdate.yml) [official container image](https://quay.io/repository/rhinstaller/kstest-runner).

You can also build the container yourself to test modifications to it:

    podman build --no-cache -t quay.io/rhinstaller/kstest-runner containers/runner/

The container to use can be overridden by setting the `CONTAINER` environmental
variable to the name of the container to use when calling launch. eg:

    CONTAINER="kstest-local:latest" containers/runner/launch keyboard

The `launch` script creates a `./data/` directory for passing of data between
the container and the system (via volume).  By default it downloads the current
Fedora Rawhide boot.iso or adequate iso file based on `--platform` option.
To test other images they can be put into `data/images/boot.iso` before running `launch`.

There is also a [daily boot.iso](.github/workflows/daily-boot-iso.yml) built
from Rawhide and various COPRs (e.g. Anaconda and DNF) for regression testing,
which you can test against with the `--daily-iso` option. When given, `launch`
downloads/unpacks that instead of the the official Rawhide boot.iso. This
requires authentication, so the option expects a GitHub token file as value.

The result logs get written into `./data/logs/`:

    tree -L 3 data/logs
    cat data/logs/kstest-*/anaconda/virt-install.log

To run tests on a different operating system (e.g. RHEL 9) use `--platform`
option (e.g. `--platform rhel9`. It will make sure the kickstart fragments for
the respective platform (`rhel9`) from [fragments/platform](/fragments/platform) are used.

# Configuration of the test

For more control, you can run the container manually:

    podman run -it --name last-kstest [--security-opt label=disable] --env KSTESTS_TEST=keyboard -v ./data:/opt/kstest/data:z -v .:/kickstart-tests:ro --device=/dev/kvm rhinstaller/kstest-runner

Instead of keeping named container you can remove it after the test by replacing `--name last-kstest` option with `--rm`.

Environment variables for the container (`--env` option):
* KSTESTS_TEST - name of the test to be run
* UPDATES_IMAGE - HTTP URL or path (inside the container) of updates image to be used
* KSTESTS_REPOSITORY - kickstart-tests git repository to be used
* KSTESTS_BRANCH - kickstart-tests git branch to be used
* BOOT_ISO - name of the installer boot iso from `data/images` to be tested (default is "boot.iso")
* KSTEST_EXTRA_BOOTOPTS - additional boot options applied to all tests (semicolon separated)

By default, the container runs the [run-kstest](./run-kstest) script. To get an
interactive shell, append `bash` to the command line.

**Beware** of the [issue](https://bugzilla.redhat.com/show_bug.cgi?id=1901462#c12) that podman
is not able to get access to kvm socket in rootless mode. This issue will result in awfully
slow execution of the tests. In that case please add `--security-opt label=disable`.

# Running tests with cached package downloads

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

To stop the proxy, call

    sudo containers/squid.sh stop

again.

# Hints and tips

## Updates image

To apply Anaconda updates image use the `-u` argument of the `containers/runner/launch`
script. If the image is uploaded on the server use:

    containers/runner/launch -u http://example.com/my_updates.img keyboard [test2 test3]

Or use local updates image directly:

    containers/runner/launch -u ./my_updates.img keyboard [test2 test3]

## Downloading last daily build boot.iso

The `containers/runner/launch` script is able to automatically download last daily boot.iso with
our COPR daily builds in it. However, to be able to do that you need to provide your GitHub token.
This GitHub token needs to have `public_repo` access. Please look
[here](https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/creating-a-personal-access-token)
to find out how to generate the token.

Then you can use `--daily-iso <path_to_token>` to download newest ISO. ISO will be stored to
`./data/images/boot.iso` if not already present. If you need newer ISO please remove the locally
stored one first!

    containers/runner/launch --daily-iso ./path/to/token_file keyboard [test2 test3]

## Connecting to a test run

It's essential to know how to connect to the running tests to see why they are failing. For these
situations you should follow this guide.

Run tests as **root** to have bridging instead of using SLIRP and having IP address for the
container so we know where to connect.

    sudo containers/runner/launch keyboard


Before the tests are started you should see something like this.

    ************************************************************************
    You can connect to this container's libvirt with this connection string:
   
       qemu+tcp://<IP>/session
   
    ************************************************************************

Then you can copy the hypervisor connection URI (`qemu+tcp://<IP>/session`) and display
the graphical console for a virtual machine with a command:

    virt-viewer -c qemu+tcp://<IP>/session

To change of the boot options for the tests (for example to add `inst.text`), please use
`--run-args="--env KSTEST_EXTRA_BOOTOPTS=inst.text"` parameter for the `launch` script.

## Running test manually from the container

Sometimes it could be helpful to run the test in the container manually to be able to inspect the
container after the run. To do that:

1. Run `containers/runner/launch` with `-c` argument in addition to other arguments. This will
open shell of the container where you can do what you want to before starting the test. 
2. Start the test(s) execution with `/kickstart-tests/containers/runner/run-kstest`.

## Debugging test failures

If you want to keep virtual machine of a finished test alive for further investigation add a `halt` command to the end of the test kickstart.

If you want to prevent killing virtual machine of a test on a failure detected in the log before the installation finishes (eg `Traceback` indicated in the log) it is possible to configure monitored messages in the [log monitor](/scripts/launcher/lib/log_monitor/log_handler.py) file.

You can run the tests in dry-run mode using `--dry-run` option. It can be used to see which tests would be actually run and the kickstarts with substitutions applied.

We are tracking the test suite issues and flakes in the repository issues. There is a [script](/scripts/classify-failures) to detect such known issues from test logs.
