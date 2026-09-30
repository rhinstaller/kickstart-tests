# Default settings for testing Fedora ELN.

# This is a reasonable default used until the new release is detected by osinfo library.
export KSTEST_OSINFO_NAME=fedora-eln
source ./network-device-names.cfg
# Pinned to one mirror, over plain http, rather than download.fedoraproject.org,
# which is a geo-redirect to https. A transparent cache can only store plain
# http, so with the redirect every rpm is downloaded again on every test. Same
# host as the FTP URLs below. See the longer note in defaults.sh.
export KSTEST_URL='http://ftp-stud.hs-esslingen.de/pub/Mirrors/fedora-eln/1/BaseOS/x86_64/os/'
export KSTEST_MODULAR_URL='http://ftp-stud.hs-esslingen.de/pub/Mirrors/fedora-eln/1/AppStream/x86_64/os/'
export KSTEST_FTP_URL='ftp://ftp-stud.hs-esslingen.de/pub/Mirrors/fedora-eln/1/BaseOS/x86_64/os/'
export KSTEST_FTP_APPSTREAM_URL='ftp://ftp-stud.hs-esslingen.de/pub/Mirrors/fedora-eln/1/AppStream/x86_64/os/'
export KSTEST_OSTREECONTAINER_URL='quay.io/fedora/eln:latest'
