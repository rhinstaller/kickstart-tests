# Default storage configuration with LUKS
zerombr
clearpart --all
autopart --encrypted --passphrase=passphrase
