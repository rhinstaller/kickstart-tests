# Default settings that work for everyone, but may not be optimal.

# Where's the package repo for tests that don't care about testing the package
# source.  This may be slow (especially for large numbers of tests) and you may
# want to define your own.
#
# CAUTION: the sed expression we currently use does not like white-space in the strings

source ./network-device-names.cfg
# No mirror is named here. Each platform says which MirrorManager repo to pick
# one from and scripts/check-mirrors.sh does the picking, so a mirror being
# retired needs no edit anywhere.
#
# Kept at whatever the environment already holds, so that a mirror chosen on
# the host survives into the container, where this file is read again.
export KSTEST_URL="${KSTEST_URL:-}"
export KSTEST_METALINK='https://mirrors.fedoraproject.org/metalink?repo=fedora-$releasever&arch=x86_64'
export KSTEST_MIRRORLIST='https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-$releasever&arch=x86_64'
export KSTEST_MODULAR_URL='http://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Modular/x86_64/os/'
export KSTEST_FTP_URL='ftp://mirrors.rit.edu/fedora/fedora/linux/development/rawhide/Everything/x86_64/os/'
export KSTEST_OSTREECONTAINER_URL='quay.io/fedora/fedora-bootc:rawhide'
