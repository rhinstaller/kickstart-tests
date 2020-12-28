## common commands without payload configuration ##
shutdown
# network
network --bootproto=dhcp
# storage & bootloader
bootloader --timeout=1
zerombr
clearpart --all
autopart
# l10n
keyboard us
lang en
timezone America/New_York
# user confguration
rootpw testcase
## common commands without payload configuration - end ##
