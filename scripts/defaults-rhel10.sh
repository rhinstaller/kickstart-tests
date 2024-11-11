# Default settings for testing RHEL 10. This requires being inside the Red Hat VPN.

# This is a reasonable default used until the new release is detected by osinfo library.
export KSTEST_OSINFO_NAME=fedora-eln
source ./network-device-names.cfg
export KSTEST_URL='http://download.devel.redhat.com/rhel-10/nightly/RHEL-10/latest-RHEL-10.0/compose/BaseOS/x86_64/os/'
export KSTEST_MODULAR_URL='http://download.devel.redhat.com/rhel-10/nightly/RHEL-10/latest-RHEL-10.0/compose/AppStream/x86_64/os/'
export KSTEST_FTP_URL='ftp://download.devel.redhat.com/mnt/redhat/rhel-10/nightly/RHEL-10/latest-RHEL-10.0/compose/BaseOS/x86_64/os/'
export KSTEST_OSTREECONTAINER_URL='quay.io/centos-bootc/centos-bootc:stream10'
