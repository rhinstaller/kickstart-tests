# Default settings for testing Fedora ELN.

# This is a reasonable default used until the new release is detected by osinfo library.
export KSTEST_OSINFO_NAME=fedora-eln
source ./network-device-names.cfg
# Pinned to one mirror, over plain http, rather than download.fedoraproject.org,
# which is a geo-redirect to https. A transparent cache can only store plain
# http, so with the redirect every rpm is downloaded again on every test. See
# the longer note in defaults.sh.
#
# mirror.fcix.net is the only mirror outside dl.fedoraproject.org that carries
# ELN and is not in Europe - MirrorManager lists exactly two for repo
# eln-baseos-1 in the US, and the FCIX regional nodes do not mirror ELN.
# Measured from a runner, fetching the 878MB install.img: fcix completed in
# 22-31s at 27-37 MB/s, while ftp-stud.hs-esslingen.de managed 0.7-1.4 MB/s and
# did not finish inside five minutes on either attempt.
export KSTEST_URL='http://mirror.fcix.net/fedora-eln/1/BaseOS/x86_64/os/'
export KSTEST_MODULAR_URL='http://mirror.fcix.net/fedora-eln/1/AppStream/x86_64/os/'
# Still Esslingen: fcix serves no FTP, and it is the only ELN mirror that does.
# Slow, per the measurement above, but the tests using these are disabled
# anyway - outbound TCP/21 has no egress from the runners (INSTALLER-4942).
export KSTEST_FTP_URL='ftp://ftp-stud.hs-esslingen.de/pub/Mirrors/fedora-eln/1/BaseOS/x86_64/os/'
export KSTEST_FTP_APPSTREAM_URL='ftp://ftp-stud.hs-esslingen.de/pub/Mirrors/fedora-eln/1/AppStream/x86_64/os/'
export KSTEST_OSTREECONTAINER_URL='quay.io/fedora/eln:latest'
