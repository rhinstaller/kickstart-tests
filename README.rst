Kickstart Test Documentation
****************************

Kickstart tests are one way of testing the Anaconda Installer, by running an automated installation based on a kickstart file and checking the results.

:Authors:
   Chris Lumens <clumens@redhat.com>
   Martin Kolman <mkolman@redhat.com>

Chapter 1. How to run kickstart tests in a container
====================================================

This is the canonical way to run tests, as it requires very little setup, does
not do any permanent changes to your system, and exactly reproduces results
from CI runs.

Clone the kickstart-tests repository and enter its directory::

  git clone https://github.com/rhinstaller/kickstart-tests
  cd kickstart-tests

The launch script downloads a current Fedora Rawhide boot.iso, downloads and
starts the runner container, and runs a set of tests in it::

  containers/runner/launch keyboard [test2 test3 ...]

Please see the `runner documentation`_ for further details, like how to run all
tests or some test types, running the container manually, using a different
boot.iso, enabling caching, and more.

Chapter 2. How to run kickstart tests manually on the host
==========================================================

*Warning*: This is deprecated now.

Setting up
----------

First you need to install the needed dependencies:

- livemedia-creator
- Python bindings for libvirt
- libguestfs-tools
- virt-install
- parallel
- createrepo
- python3-rpmfluff
- squid
- scp
- genisoimage
- make

You also need to start libvirt service to be able to use virt-install::

  sudo systemctl start libvirtd

Then clone the kickstart-tests repository::

  git clone https://github.com/rhinstaller/kickstart-tests

And you also need a rawhide boot.iso (provided you want to run the kickstart tests on Rawhide)::

  wget https://download.fedoraproject.org/pub/fedora/linux/development/rawhide/Server/x86_64/os/images/boot.iso

Please note that due to the dynamic nature of Rawhide the boot.iso might not always work.

Running a test
--------------

Lets just run a simple test to check that everything works correctly – for example the simple tmpfs kickstart command test. First change directory to the kickstart-tests folder::

  cd kickstart-tests

Then run the single test::

  scripts/run_kickstart_tests.sh -i ../boot.iso -k 2 tmpfs-fixed_size.sh

About the parameters:

  -i   sets the path to the boot.iso
  -k   sets if logs from the run should be kept, as for the values:

 - 0 = keep nothing (the default)
 - 1 = keep log files
 - 2 = keep log files and disk images (will take up a lot of space)

  -u   use updates image given by URL or local file path
  -b   use additional installer boot options

And at the end name of the kickstart test script to run.

The -k 2 option is especially useful if you are doing more complicated post-install test validation in you kickstart test script that needs to check contents of the disk image/images.

The results
-----------

If everything worked out, you should be greeted by a successful test result similar to this one::


    ===========================================================================
    tmpfs-fixed_size.ks on computer.hostname
    ===========================================================================
    PYTHONPATH=
    ...................................................
    Domain LiveOS-1710fd05-898c-4cf2-b4e1-67d40aaf5f3d has been undefined

    Pool kstest-tmpfs-fixed_size.RI8HWHMF destroyed

    Pool kstest-tmpfs-fixed_size.RI8HWHMF has been undefined


    RESULT:tmpfs-fixed_size:SUCCESS
    2017-06-06 16:46:34,477: install_log = /var/tmp/kstest-tmpfs-fixed_size.RI8HWHMF/virt-install.log
    2017-06-06 16:46:34,513: Running virt-install.
    2017-06-06 16:46:35,903: Processing logs from ('127.0.0.1', 53130)
    2017-06-06 16:55:06,646: Install finished. Or at least virt shut down.
    2017-06-06 16:55:06,650: Shutting down LiveOS-1710fd05-898c-4cf2-b4e1-67d40aaf5f3d
    error: Failed to destroy domain LiveOS-1710fd05-898c-4cf2-b4e1-67d40aaf5f3d
    error: Requested operation is not valid: the domain is not running
    2017-06-06 16:55:06,777: Shutting down log processing
    2017-06-06 16:55:06,778: unmounting the iso
    2017-06-06 16:55:06,812: Disk Image install successful
    2017-06-06 16:55:06,812: SUMMARY
    2017-06-06 16:55:06,812: -------
    2017-06-06 16:55:06,813: Logs are in /var/tmp/kstest-tmpfs-fixed_size.RI8HWHMF
    2017-06-06 16:55:06,813: Disk image(s) at /var/tmp/kstest-tmpfs-fixed_size.RI8HWHMF/disk-a.img,cache=unsafe
    2017-06-06 16:55:06,813: Results are in /var/tmp/kstest-tmpfs-fixed_size.RI8HWHMF

Chapter 3. A test definition
============================

A kickstart test consists of two files:

- <TEST_NAME>.sh - a file defining installer boot options and procedures to set
  up test-specific environment (eg http server for providing the kickstart
  file, special virtual networks, iscsi targets for test, etc). This file name
  is used to specify the kickstart test to be run.

- <TEST_NAME>.ks.in - the kickstart file belonging to the test, containing
  variables that would be preprocessed (as described in following chapters) to
  generate the actual kicstart file passed to installer. By default, the file
  with the same name as the .sh file is used. This can be overriden (eg to
  share kickstarts among tests that differ only in boot options) in .sh file
  using KICKSTART_NAME=<ANOTHER_TEST_NAME> variable. For example by defining

  ::

    KICKSTART_NAME=network-device-default

  in network-device-default-httpks.sh test, the test will use kickstart
  network-device-default.ks.in.

  NOTE: possible redefinintions of KICKSTART_NAME value in files included in
  the the .sh file (eg to reuse .sh file of another test) are ignored.

  NOTE: The fragments (%ksappend) mechanism does not work together with
  KICKSTART_NAME setting (%ksappend is not applied).

Chapter 4. Environment Variables
================================

A lot of tests need configuration.  This is information that is required by
tests but typically cannot be hard coded.  Typically, this configuration is
a package repository needed for testing an installation method.  It is up to
the user running the tests to do whatever local setup is required and set
these configuration parameters.

Configuration parameters come from the environment.  All environment variables
starting with KSTEST_ will be grabbed by run_kickstart_tests.sh and
automatically substituted in to the kickstart file before it is run.  In the
kickstart file, the target of a substitution is any string starting with
@KSTEST_ and ending with another @.  This is similar to how the autotools work.

Configuration parameters may also come from special shell scripts that are
sourced during run_kickstart_tests.sh.  It will first look at the defaults in
scripts/defaults.sh.  Next, if platform is specified using -p PLATFORM option,
the scripts/defaults-PLATFORM.sh file is sourced.  Finally it will source any
user-specific defaults in ~/.kstests.defaults.sh.  These take precedence over
the local environment.  Environment variables set on the command line have the
highest priority.

Note that not every test needs every setting.  You can determine which are
required for the test you are running by simply running "grep KSTEST_" on it.

The following environment variables are currently supported:

- KSTEST_HTTP_ADDON_REPO - This variable is a URL that points to an addon
  repository.  It is only needed if you are testing that functionality, not
  if you are testing something else that just happens to use the url command.
  It will be set up for you automatically with a web server and auto-generated
  packages.  There is no need to specify this variable.

- KSTEST_LIVEIMG_CHECKSUM - This variable is the checksum of the image given
  by KSTEST_LIVEIMG_URL.  It is only needed if you are testing the liveimg
  command.  It will be set up for you automatically.  There is no need to
  specify this variable.

- KSTEST_LIVEIMG_URL - This variable is a URL that points to an install.img
  that is used by the liveimg command.  It is only needed if you are testing
  that command.  It will be set up for you automatically based on the boot.iso
  specified on the command line.  There is no need to specify this variable.

- KSTEST_NFS_ADDON_REPO - This variable points to an NFS server and path where
  an addon repository can be found.  This is different from KSTEST_NFS_PATH
  and KSTEST_NFS_SERVER.  Those are used with the nfs command.  This variable
  is used with the repo command, and its format is different.  Here, it takes
  the form of nfs://<server>:<path>.  See the kickstart documentation.  You
  will need to set up your own NFS server.

- KSTEST_NFS_PATH - This variable points to the path of a package repository
  on the NFS server given by KSTEST_NFS_SERVER.  It is only needed if you are
  testing the nfs command and installation method.  You will need to set up
  your own NFS server.

- KSTEST_NFS_SERVER - This variable points at an NFS server, and is only needed
  if you are testing the nfs command and installation method.  You will need to
  set up your own NFS server.

- KSTEST_OSTREE_REPO - This variable points at the atomic repo, and is only
  needed if you are testing the ostreesetup command and installation method.
  You will need to set up your own repo.

- KSTEST_FTP_URL - This variable is used by FTP tests. It is set to a Fedora
  mirror in Texas, USA in scripts/defaults.sh. This is potentially slow and
  you may want to point it at a local mirror.

- KSTEST_URL - This variable is used by all tests that don't test installation
  method and instead just use the default.  It is set to the Fedora mirrors in
  scripts/defaults.sh.  This is potentially slow if you are running a lot of
  tests, and you may want to point it at a local mirror.

- KSTEST_OS_NAME - This variable is read from the input boot.iso and it
  contains a name of the OS. Possible names can be "fedora", "rhel".

- KSTEST_OS_VERSION - This variable is read from the input boot.iso and it
  contains version of the OS. For example Fedora 26 has
  KSTEST_OS_VERSION = 26, Fedora rawhide has "Rawhide", and RHEL 7.3 has
  KSTEST_OS_VERSION = 7.3 .

- KSTEST_EXTRA_BOOTOPTS - This variable is used in functions.sh to pass
  additional kernel command line options. For example, setting this to `inst.text`
  enables Anaconda's text mode (instead of the default GUI). Multiple values
  separated by semicolon can be passed.

Chapter 5. Sharing common code in kickstart (.ks.in) files
==========================================================

To include kickstart or code snippets into test kickstart file during its
pre-processing (just after KSTEST_ variables are substituted) use
@KSINCLUDE@ <FILE_NAME> directive.

For example to include post-lib-network.sh which is a library with functions
for checking test results of network tests, include it in ks.in test file:

::

  %post

  @KSINCLUDE@ post-lib-network.sh

  check_device_connected ens4 yes

  %end

The including is flat, only one level is supported. Do not use @KSINCLUDE@ in
included files, the results could be unexpected.

Chapter 6. Networking tests
===========================

This section contains tips for creating kicstart tests for network
configuration.  In some test cases special or additional network devices and
virtual networks for test/virt-install instance are defined in prepare() and
prepare_network() functions of .sh test file.

Network device names
--------------------

Network device names used in guest may differ for tested os variants (eg RHEL
vs Fedora).  Actual naming scheme to be used by the tests is defined in
network-device-names.cfg snippet which is sourced both in .sh files for boot
options network configuration (via functions.sh) and .ks.in files for kickstart
network configuration (via @KSTEST_ substitution). The variables used in .sh and
.ks.in files have the form of KSTEST_NETDEV<INDEX> where <INDEX> is the
numerical index of the device, starting from 1.

Static IP configuration
-----------------------

For tests using static IP configuration, separate NATed network is created in
prepare() function for each test so IP address collisions between tests running
in parallel are prevented. Static configuration generated during network
creation is referred to in kickstart using @KSTEST_ substitiution described
above.

Allocating device MAC addresses
-------------------------------

For tests requiring definition of MAC address assigned to the device the
address is statically assigned in prepare_network() function.  For kvm/qemu
virtual machines it must start with 52:54:00.

httpks tests
------------

The tests containing httpks in its name are fetching kickstart from https
server (prepare() function of .sh test file) instead of including it via initrd
inject into initramfs - which is the default approach used in tests.  The
reason is that using the inject method the network devices are not initialized
in time of parsing kickstart and obtaining information from sysfs (mostly
getting hw address) fails which results in incomplete ifcfg file generated.

Chapter 7. Continuous Integration structure
===========================================

Regular test runs
-----------------
Every night, the `scenarios workflow`_ runs all tests on all our supported
operating systems/repositories, like "Fedora Rawhide" or "RHEL 8". These are
defined in the `containers/runner/scenario`_ script, which essentially calls
the runner container's ``launch`` script documented above with the desired
parameters.

The ``rawhide`` and ``daily-iso`` scenarios can in principle run on any host
that has enough resources. The ``rhel8`` test however needs to run on RHEL
internal infrastructure.

Currently all scenarios run on `self-hosted GitHub action runners`_, which are
running in our upshift cluster. See our internal ``builders.git`` repository
for details and the launch/setup playbooks. These have little magic, though,
they mostly just create an OpenStack instance and install/configure the action
runner binary as a service. All the actual test logic is contained in the
workflow files and the runner container.

The results can be viewed on the `GitHub Daily run workflows page`_. Each run
has an artifact attached with the detailed log files. This is currently not
very comfortable, and we are actively looking for a better solution how to
publish the test result history.

These tests are expected to succeed normally. On failures, rhinstaller
maintainers get a "failed workflow" notification email and should investigate
the cause.

Sometimes tests fail due to networking/infrastructure flakes. To avoid this
kind of noise, the nightly runs use the ``--retry`` option to re-run a test
which failed due to an unspecific reason (i.e. not due to a skip or a syntax
error in the kickstart file, etc.). The test log will still show both results
right after each other, so that the original failure can be examined; but if
the retry works, the test as a whole counts as success.

Pull requests
-------------
PRs are gated to avoid introducing broken or unstable tests, and to validate
changes to existing tests. To keep PRs open to the whole community, we want to
avoid running them in self-hosted internal infrastructure (if we did, we'd need
to restrict running the tests to avoid exfiltrating secrets from the internal
Red Hat network).

Thus PR tests run on Travis_, which is one of the few public CI providers who
offer ``/dev/kvm``. The entry point is `.travis.yml`_. The ``run_travis.sh``
script checks which tests are affected by the PR, and runs the first six in
the runner container's launch script. Travis jobs are limited to 50 minutes, so
we cannot currently run more; but that should suffice in most cases.

PR runs do *not* auto-retry test failures. This avoids introducing unstable
tests, and PRs usually just run a few tests so that flakes are much less likely
to ruin the result.

Service jobs
------------
* The `container-autoupdate`_ workflow refreshes the runner container
  every week, and pushes it to `quay.io/rhinstaller/kstest-runner`_.
  Developers, CI, and the ``launch`` script usually download it from there.

* The `daily-boot-iso`_ workflow creates a ``boot.iso`` out of current Fedora
  Rawhide and various COPRs every night, so that we can test updates to
  anaconda, dnf, or blivet before they get released. This is consumed by the
  ``daily-iso`` scenario.

These jobs don't have any particular infrastructure requirements. They run on
GitHub's infrastructure and can be run manually by a developer.

.. _runner documentation: ./containers/runner/README.md
.. _containers: ./containers
.. _self-hosted GitHub action runners: https://docs.github.com/en/free-pro-team@latest/actions/hosting-your-own-runners
.. _scenarios workflow: .github/workflows/scenarios.yml
.. _containers/runner/scenario: ./containers/runner/scenario
.. _GitHub Daily run workflows page: https://github.com/rhinstaller/kickstart-tests/actions?query=workflow%3A%22Daily+run%22
.. _Travis: https://travis-ci.com/
.. _.travis.yml: ./.travis.yml
.. _container-autoupdate: ./.github/workflows/container-autoupdate.yml
.. _quay.io/rhinstaller/kstest-runner: https://quay.io/repository/rhinstaller/kstest-runner
.. _daily-boot-iso: ./.github/workflows/daily-boot-iso.yml
