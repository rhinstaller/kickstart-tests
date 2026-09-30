# Default settings that work for everyone, but may not be optimal.

# Where's the package repo for tests that don't care about testing the package
# source.  This may be slow (especially for large numbers of tests) and you may
# want to define your own.
#
# CAUTION: the sed expression we currently use does not like white-space in the strings

source ./network-device-names.cfg
# Pinned to one mirror rather than dl.fedoraproject.org, which redirects http to
# https. A transparent cache can only store plain http - anything on https is
# spliced through untouched - so with dl every rpm is fetched again on every
# test, and a suite downloads the same packages dozens of times. This mirror
# answers 200 over plain http and so is actually cacheable. The cost is a single
# point of failure: if it goes away, the fix is to pick another plain-http
# mirror, not to go back to dl.
export KSTEST_URL='http://mirrors.rit.edu/fedora/fedora/linux/development/rawhide/Everything/x86_64/os/'
export KSTEST_METALINK='https://mirrors.fedoraproject.org/metalink?repo=fedora-$releasever&arch=x86_64'
export KSTEST_MIRRORLIST='https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-$releasever&arch=x86_64'
export KSTEST_MODULAR_URL='http://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Modular/x86_64/os/'
export KSTEST_FTP_URL='ftp://mirrors.rit.edu/fedora/fedora/linux/development/rawhide/Everything/x86_64/os/'
export KSTEST_OSTREECONTAINER_URL='quay.io/fedora/fedora-bootc:rawhide'
