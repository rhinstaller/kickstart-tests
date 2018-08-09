# Default settings that work for everyone, but may not be optimal.

# Where's the package repo for tests that don't care about testing the package
# source.  This may be slow (especially for large numbers of tests) and you may
# want to define your own.
#
# CAUTION: the sed expression we currently use does not like white-space in the strings

export KSTEST_URL='--mirror=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-rawhide\\&arch=$basearch'
export KSTEST_MODULAR_URL='--mirror=http://mirrors.fedoraproject.org/mirrorlist?repo=rawhide-modular\\&arch=$basearch'
export KSTEST_FTP_URL='ftp://mirror.utexas.edu/pub/fedora/linux/development/rawhide/Everything/$basearch/os/'
