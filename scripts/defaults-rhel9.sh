# Default settings for testing RHEL 9. This requires being inside the Red Hat VPN.

# network-device-names.cfg is redefined here
NETDEV_PREFIX="ens"
NETDEV_SUFFIX=""
export KSTEST_NETDEV1=${NETDEV_PREFIX}3${NETDEV_SUFFIX}
export KSTEST_NETDEV2=${NETDEV_PREFIX}4${NETDEV_SUFFIX}
export KSTEST_NETDEV3=${NETDEV_PREFIX}5${NETDEV_SUFFIX}
export KSTEST_NETDEV4=${NETDEV_PREFIX}6${NETDEV_SUFFIX}
export KSTEST_NETDEV5=${NETDEV_PREFIX}7${NETDEV_SUFFIX}
export KSTEST_NETDEV6=${NETDEV_PREFIX}8${NETDEV_SUFFIX}

export KSTEST_URL='--url=http://download.eng.bos.redhat.com/rhel-9/development/RHEL-9-Beta/latest-RHEL-9/compose/BaseOS/x86_64/os/'
export KSTEST_MODULAR_URL='http://download.eng.bos.redhat.com/rhel-9/development/RHEL-9-Beta/latest-RHEL-9/compose/AppStream/x86_64/os/'
export KSTEST_FTP_URL='ftp://ftp.tu-chemnitz.de/pub/linux/fedora/linux/development/rawhide/Everything/$basearch/os/'

