# Default settings for testing RHEL 8. This requires being inside the Red Hat VPN.

source scripts/defaults.sh
export KSTEST_URL='--url=http://download.devel.redhat.com/rhel-8/nightly/RHEL-8/latest-RHEL-8/compose/BaseOS/x86_64/os/'
export KSTEST_MODULAR_URL='http://download.devel.redhat.com/rhel-8/nightly/RHEL-8/latest-RHEL-8/compose/AppStream/x86_64/os/'
