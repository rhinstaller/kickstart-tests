# Default settings that work for everyone, but may not be optimal.

# Where's the package repo for tests that don't care about testing the package
# source.  This may be slow (especially for large numbers of tests) and you may
# want to define your own.
#
# CAUTION: the sed expression we currently use does not like white-space in the strings

source network-device-names.cfg
export KSTEST_URL='http://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Everything/$basearch/os/'
export KSTEST_METALINK='https://mirrors.fedoraproject.org/metalink?repo=fedora-$releasever&arch=$basearch'
export KSTEST_MIRRORLIST='https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-$releasever&arch=$basearch'
export KSTEST_MODULAR_URL='http://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Modular/$basearch/os/'
export KSTEST_FTP_URL='ftp://ftp.tu-chemnitz.de/pub/linux/fedora/linux/development/rawhide/Everything/$basearch/os/'
export KSTEST_OSTREECONTAINER_URL='quay.io/centos-bootc/fedora-bootc:eln'
