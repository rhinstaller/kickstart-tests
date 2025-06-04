# Default settings for testing RHEL 8. This requires being inside the Red Hat VPN.

source ./network-device-names.cfg
export KSTEST_URL='http://download.devel.redhat.com/rhel-8/nightly/RHEL-8/latest-RHEL-8.10.0/compose/BaseOS/x86_64/os/'
export KSTEST_MODULAR_URL='http://download.devel.redhat.com/rhel-8/nightly/RHEL-8/latest-RHEL-8.10.0/compose/AppStream/x86_64/os/'
export KSTEST_FTP_URL='ftp://download.devel.redhat.com/mnt/redhat/rhel-8/nightly/RHEL-8/latest-RHEL-8.10.0/compose/BaseOS/x86_64/os/'
export KSTEST_FTP_APPSTREAM_URL='ftp://download.devel.redhat.com/mnt/redhat/rhel-8/nightly/RHEL-8/latest-RHEL-8.10.0/compose/AppStream/x86_64/os/'
