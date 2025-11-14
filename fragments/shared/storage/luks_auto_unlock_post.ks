%post
# Automatically unlock the encrypted filesystems on boot; code
# borrowed from Anabot's profiles/default/hooks/95-add_luks_key-post.hook
keyfile="/root/keyfile"
echo -n "passphrase" > ${keyfile} # actual passphrase
chmod 0400 ${keyfile}
# modify /etc/crypttab, set key file in the third column of the file
# /root is a bind mount to /var/roothome, so dracut includes it as /var/roothome/keyfile
awk -v KEYFILE="/var/roothome/keyfile" '{$3=KEYFILE; print $0}' /etc/crypttab > /tmp/crypttab_mod
mv -Z /tmp/crypttab_mod /etc/crypttab
chmod 0600 /etc/crypttab
kernel_version=$(rpm -q kernel | sed 's/^kernel-//')
initrd_file=$(find /boot -name initramfs-${kernel_version}.img 2>/dev/null | head -1)
boot_device=$(findmnt -n -o SOURCE /boot 2>/dev/null || mount | grep " /boot " | awk '{print $1}')
mount -o remount,rw ${boot_device} /boot
dracut -f --tmpdir /tmp -I "${keyfile} /etc/crypttab" ${initrd_file} ${kernel_version}
%end

