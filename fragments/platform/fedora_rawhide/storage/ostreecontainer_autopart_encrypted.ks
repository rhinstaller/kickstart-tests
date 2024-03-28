# Default storage configuration with LUKS and lvm type enforced
zerombr
clearpart --all
autopart --encrypted --passphrase=passphrase --type=lvm
