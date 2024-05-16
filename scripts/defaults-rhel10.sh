# Default settings for testing RHEL 10. This requires being inside the Red Hat VPN.

# This is a reasonable default used until the new release is detected by osinfo library.
export KSTEST_OSINFO_NAME=fedora-eln
source network-device-names.cfg
export KSTEST_URL='http://composes.stream.centos.org/stream-10/development/latest-CentOS-Stream/compose/BaseOS/x86_64/os/'
export KSTEST_MODULAR_URL='http://composes.stream.centos.org/stream-10/development/latest-CentOS-Stream/compose/AppStream/x86_64/os/'
export KSTEST_FTP_URL='ftp://ftp.tu-chemnitz.de/pub/linux/fedora/linux/development/rawhide/Everything/$basearch/os/'
export KSTEST_OSTREECONTAINER_URL='quay.io/centos-bootc/centos-bootc:stream10'
