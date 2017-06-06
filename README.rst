Kickstart Test Documentation
****************************

:Authors:
   Chris Lumens <clumens@redhat.com>
   Martin Kolman <mkolman@redhat.com>

Chapter 0. How to run a single kickstart test manually
======================================================

What are kickstart tests ?
--------------------------

Kickstart tests are one way of testing the Anaconda Installer, by running an automated installation based on a kickstart file and checking the results.

Setting up
----------

First you need to install the needed dependencies:

- livemedia-creator
- Python bindings for libvirt
- libguestfs
- virt-install

On Fedora the dependencies can be installed with dnf like this::

  sudo dnf install livemedia-creator libvirt-python3 libquestfs virt-install

Then clone the kickstart-tests repository::

  git clone https://github.com/rhinstaller/kickstart-tests

And you also need a rawhide boot.iso (provided you want to run the kickstart tests on Rawhide)::

  wget http://download.eng.brq.redhat.com/pub/fedora/linux/development/latest-rawhide/Server/x86_64/os/images/boot.iso

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

Chapter 1. Environment Variables
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
scripts/defaults.sh.  It will then look at any user-specific defaults in
~/.kstests.defaults.sh.  These take precedence over the local environment.
Environment variables set on the command line have the highest priority.

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
  contains version of the OS. For example Fedora 26 have
  KSTEST_OS_VERSION = 26 and RHEL 7.3 have KSTEST_OS_VERSION = 7.3 .

Chapter 2. Sharing common code in kickstart (.ks.in) files
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
