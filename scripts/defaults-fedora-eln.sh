# Default settings for testing Fedora ELN.

# This is a reasonable default used until the new release is detected by osinfo library.
export KSTEST_OSINFO_NAME=fedora-eln
source ./network-device-names.cfg
export KSTEST_URL='https://download.fedoraproject.org/pub/eln/1/BaseOS/x86_64/os/'
export KSTEST_MODULAR_URL='https://download.fedoraproject.org/pub/eln/1/AppStream/x86_64/os/'
export KSTEST_FTP_URL='ftp://ftp-stud.hs-esslingen.de/pub/Mirrors/fedora-eln/1/BaseOS/x86_64/os/'
export KSTEST_FTP_APPSTREAM_URL='ftp://ftp-stud.hs-esslingen.de/pub/Mirrors/fedora-eln/1/AppStream/x86_64/os/'
export KSTEST_OSTREECONTAINER_URL='quay.io/fedora/eln:latest'
