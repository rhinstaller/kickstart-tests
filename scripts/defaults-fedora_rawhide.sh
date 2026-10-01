# Settings for testing Fedora Rawhide.

# Everything else Rawhide needs is in the generic defaults, which the caller
# has already sourced. All this adds is where to get a payload mirror from,
# which has to live here rather than there: every platform reads defaults.sh,
# and RHEL must not end up pointed at a Fedora mirror.
#
# A plain http mirror is what we want, because that is what can be cached.
# download.fedoraproject.org and friends redirect http to https, and a
# transparent cache cannot store https - it is spliced through untouched, so
# every rpm is fetched again on every test.
export MIRROR_REPO_KSTEST_URL='rawhide'
# Only for when MirrorManager itself cannot be reached. https, so uncacheable:
# a way to keep the suite running rather than somewhere to stay.
export MIRROR_FALLBACKS_KSTEST_URL='https://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Everything/x86_64/os/'
