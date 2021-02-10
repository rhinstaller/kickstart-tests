# FIXME: Defaults for our custom built iso - the network device naming differs
# from latest rawhide isos but seems to have other cause then
# https://github.com/rhinstaller/kickstart-tests/issues/448
# See https://github.com/rhinstaller/kickstart-tests/issues/482

source scripts/defaults.sh
# network device names
NETDEV_PREFIX="ens"
NETDEV_SUFFIX=""
export KSTEST_NETDEV1=${NETDEV_PREFIX}3${NETDEV_SUFFIX}
export KSTEST_NETDEV2=${NETDEV_PREFIX}4${NETDEV_SUFFIX}
export KSTEST_NETDEV3=${NETDEV_PREFIX}5${NETDEV_SUFFIX}
export KSTEST_NETDEV4=${NETDEV_PREFIX}6${NETDEV_SUFFIX}
export KSTEST_NETDEV5=${NETDEV_PREFIX}7${NETDEV_SUFFIX}
export KSTEST_NETDEV6=${NETDEV_PREFIX}8${NETDEV_SUFFIX}
