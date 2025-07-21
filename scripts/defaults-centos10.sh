# Default settings for testing RHEL 10. This requires being inside the Red Hat VPN.

# This is a reasonable default used until the new release is detected by osinfo library.
export KSTEST_OSINFO_NAME=fedora-eln
source ./network-device-names.cfg
export KSTEST_URL='https://mirror.stream.centos.org/10-stream/BaseOS/x86_64/os/'
export KSTEST_MODULAR_URL='https://mirror.stream.centos.org/10-stream/AppStream/x86_64/os/'
# FIXME: either find the URL or disable the test on centos10
export KSTEST_FTP_URL='ftp://download.devel.redhat.com/mnt/redhat/rhel-10/nightly/RHEL-10/latest-RHEL-10.1/compose/BaseOS/x86_64/os/'
export KSTEST_OSTREECONTAINER_URL='quay.io/centos-bootc/centos-bootc:stream10'
