# Network configuration tests

TESTTYPE="network"

### Multiple network devices:

To define multiple network devices use prepare_network() function in .sh file. See onboot-activate.sh which defines 3 NICs. The values are passed to virt-install --network option. Tests usually use one or more `user` networks, so that they can run without privileges and are isolated from one another (for parallel test runs).

It is sometimes useful to control the devices that would be activated in initramfs stage, which can be done by overriding kernel_args() function in .sh file.

### Device names:

We are assuming device names assigned in the form ensX. This might be fragile. It should be possible to use "net.ifnames=0 biosdevname=0" boot options to use kernel ethX naming scheme, but note that this would made the test a special case.

virt-install --network command allows for MAC address definition. This can be configured for a test in prepare_network() .sh function.

### Fetching kickstart via http:

In normal case when kickstart is injected in initrd and ks=file:/ method is used the network devices are not set up when we parse kickstart in initramfs and as a consequence network commands are not applied (ifcfg files are not created) in initramfs (this does not apply to virtual devices, eg bond, team). They will be created later by anaconda (as they would be for network command defined in %pre section). To be able to test generating of ifcfg files in initramfs we fetch the kickstart from local http server on hypervisor. The server is setup and torn down by overriden prepare() and cleanup() .sh function (see onboot-activate-httpks.sh) and boot option for fetching the kickstart is added in kernel_args() .sh function. The variants of tests using http are suffixed with -httpks string and they use the same .ks.in file (at the moment it is just a copy of non httpks case with matching file name).

### Pre section tests:

These are variants of tests checking defining network in %pre section which means creating connections (ifcfgs) in anaconda instead of initramfs. They use the same .sh file (currently there is .sh file matching the test name including the non-pre variant .sh file). Example: team.ks.in team-pre.ks.in. Note that in this case (team is a virtual device) we don't have to fetch kickstart from http to apply it in initramfs (which is required for ethernet devices as described above), so there is no -httpks variant of the test.

### Result testing functions to be shared:

Look into onboot-activate.ks.sh for %post bash functions that can be commonly used to test results of installation wrt network device activation and content of created ifcfg files.

We could think about mechanism for sharing %post script bash snippets/functions via additional test files (ks.in) preprocessing.
