# Default settings for testing RHEL 8 daily boot.iso. This requires being inside the Red Hat VPN.

source scripts/defaults-rhel8.sh

# FIXME: .github/workflows/daily-boot-iso-rhel8.yml generated images use a different
# network naming schema than the official nightly images
# See https://github.com/rhinstaller/kickstart-tests/issues/448
export KSTEST_NETDEV1=ens3
export KSTEST_NETDEV2=ens4
export KSTEST_NETDEV3=ens5
export KSTEST_NETDEV4=ens6
export KSTEST_NETDEV5=ens7
export KSTEST_NETDEV6=ens8
