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

The `squashfs` kernel module needs to be running on the host. To check run:
```
lsmod | grep squashfs
```

The host needs to have enough available loop device nodes created to be able to mount various images.
To check existing nodes run:
```
ls /dev/loop[0-9]*
```
To check used nodes run:
```
losetup
```
There should be at least three available nodes.
To create a new node on the host run mknod, for example to create /dev/loop<NUM> run:
```
sudo mknod /dev/loop<NUM> b 7 <NUM>
```

There is a [playbook](runner-host.yml) for deployment of the host on Fedora Cloud Base Image. See [Troubleshooting] for preferred version to be used.

Run a test in a container
-------------------------

Build the container:
```
sudo podman build -t kstest-runner .
```
Note: we can't use rootless containers because of mounting of images in the contaier.

Define the directory for passing of data between the container and the system (via volume):
```
export VOLUME_DIR=${PWD}/data
```

Create subdirs for test inputs (installation image) and outputs (logs):
```
mkdir -p ${VOLUME_DIR}/images
mkdir -p ${VOLUME_DIR}/logs
```

Download the test subject (installer boot iso):
```
curl -L https://download.fedoraproject.org/pub/fedora/linux/development/rawhide/Server/x86_64/os/images/boot.iso --output ${VOLUME_DIR}/images/boot.iso
```

Run the test:
```
sudo podman run --env KSTESTS_TEST=keyboard -v ${VOLUME_DIR}:/opt/kstest/data:z --name last-kstest --privileged=true --device=/dev/kvm kstest-runner
```
Instead of keeping named container you can remove it after the test by replacing `--name last-kstest` option with `--rm`.

See the results:
```
tree -L 3 ${VOLUME_DIR}/logs
cat ${VOLUME_DIR}/logs/kstest-*/anaconda/virt-install.log
```

This will check out and use kickstart-tests master from GitHub. To run against
your local development branch instead, pass `-v .:/opt/kstest/kickstart-tests`
to `podman run`.

Configuration of the test
-------------------------

Environment variables for the container (`--env` option):
* KSTESTS_TEST - name of the test to be run
* UPDATES_IMAGE - HTTP URL of updates image to be used
* KSTESTS_REPOSITORY - kickstart-tests git repository to be used
* KSTESTS_BRANCH - kickstart-tests git branch to be used
* BOOT_ISO - name of the installer boot iso from ${VOLUME_DIR}/images to be tested (default is "boot.iso")


Troubleshooting
---------------

### Tests runnable in container
Some tests require services, resources, or configration in VM hypervisor that might not be working in container. Checking the tests and trying to resolve the issues is TBD.
