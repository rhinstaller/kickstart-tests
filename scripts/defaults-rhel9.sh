# Default settings for testing RHEL 9. This requires being inside the Red Hat VPN.

source ./network-device-names.cfg
export KSTEST_URL='http://download.eng.bos.redhat.com/rhel-9/nightly/RHEL-9/latest-RHEL-9.5.0/compose/BaseOS/x86_64/os/'
export KSTEST_MODULAR_URL='http://download.eng.bos.redhat.com/rhel-9/nightly/RHEL-9/latest-RHEL-9.5.0/compose/AppStream/x86_64/os/'
export KSTEST_FTP_URL='ftp://ftp.tu-chemnitz.de/pub/linux/fedora/linux/development/rawhide/Everything/x86_64/os/'
export KSTEST_OSTREECONTAINER_URL='quay.io/centos-bootc/centos-bootc:stream9'
