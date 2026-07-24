# Storage for bootc: reqpart (ESP at /boot/efi) and a single root partition.
zerombr
clearpart --all --initlabel
reqpart
part / --size=1024 --grow --label=rootfs
