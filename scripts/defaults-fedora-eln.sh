# Default settings for testing Fedora ELN.

# This is a reasonable default used until the new release is detected by osinfo library.
export KSTEST_OSINFO_NAME=fedora-eln
source ./network-device-names.cfg
# Plain http rather than download.fedoraproject.org, which is a geo-redirect
# to https: a transparent cache can only store plain http, so with the
# redirect every rpm is downloaded again on every test.
#
# Named here, and deliberately not picked by scripts/check-mirrors.sh the way
# Rawhide's is. mirror.fcix.net is nearer and far faster - 27-37 MB/s against
# this one's 0.7-1.4 MB/s on the 878MB install.img - but a full ELN run on it
# produced failures that this mirror does not produce, and we do not know why.
# The two serve byte-identical repodata and the same packages, so whatever it
# is, it is not visible from the outside. Until it is understood, ELN stays
# where it is known to pass, and selection is left off so that a failover
# cannot quietly put fcix back.
export KSTEST_URL='http://ftp-stud.hs-esslingen.de/pub/Mirrors/fedora-eln/1/BaseOS/x86_64/os/'
export KSTEST_MODULAR_URL='http://ftp-stud.hs-esslingen.de/pub/Mirrors/fedora-eln/1/AppStream/x86_64/os/'
# Still Esslingen: fcix serves no FTP, and it is the only ELN mirror that does.
# Slow, per the measurement above, but the tests using these are disabled
# anyway - outbound TCP/21 has no egress from the runners (INSTALLER-4942).
export KSTEST_FTP_URL='ftp://ftp-stud.hs-esslingen.de/pub/Mirrors/fedora-eln/1/BaseOS/x86_64/os/'
export KSTEST_FTP_APPSTREAM_URL='ftp://ftp-stud.hs-esslingen.de/pub/Mirrors/fedora-eln/1/AppStream/x86_64/os/'
export KSTEST_OSTREECONTAINER_URL='quay.io/fedora/eln:latest'
