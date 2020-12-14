# Default settings that work for everyone, but may not be optimal.

# Where's the package repo for tests that don't care about testing the package
# source.  This may be slow (especially for large numbers of tests) and you may
# want to define your own.
#
# CAUTION: the sed expression we currently use does not like white-space in the strings

# network device names
NETDEV_PREFIX="enp"
NETDEV_SUFFIX="s0"
export KSTEST_NETDEV1=${NETDEV_PREFIX}1${NETDEV_SUFFIX}
export KSTEST_NETDEV2=${NETDEV_PREFIX}2${NETDEV_SUFFIX}
export KSTEST_NETDEV3=${NETDEV_PREFIX}3${NETDEV_SUFFIX}
export KSTEST_NETDEV4=${NETDEV_PREFIX}4${NETDEV_SUFFIX}
export KSTEST_NETDEV5=${NETDEV_PREFIX}5${NETDEV_SUFFIX}
export KSTEST_NETDEV6=${NETDEV_PREFIX}6${NETDEV_SUFFIX}

export KSTEST_URL='--url=http://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Everything/$basearch/os/'
export KSTEST_MODULAR_URL='http://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Modular/$basearch/os/'
export KSTEST_FTP_URL='ftp://ftp.tu-chemnitz.de/pub/linux/fedora/linux/development/rawhide/Everything/$basearch/os/'
