# Default settings for testing RHEL 10. This requires being inside the Red Hat VPN.

# This is a reasonable default used until the new release is detected by osinfo library.
export KSTEST_OSINFO_NAME=fedora-eln
source ./network-device-names.cfg
export KSTEST_URL='https://mirror.stream.centos.org/10-stream/BaseOS/x86_64/os/'
export KSTEST_MODULAR_URL='https://mirror.stream.centos.org/10-stream/AppStream/x86_64/os/'
export KSTEST_FTP_URL='ftp://download.stream.rdu2.redhat.com/stream-10/production/latest-CentOS-Stream/compose/BaseOS/x86_64/os/'
export KSTEST_FTP_APPSTREAM_URL='ftp://download.stream.rdu2.redhat.com/stream-10/production/latest-CentOS-Stream/compose/AppStream/x86_64/os/'
export KSTEST_OSTREECONTAINER_URL='quay.io/centos-bootc/centos-bootc:stream10'
