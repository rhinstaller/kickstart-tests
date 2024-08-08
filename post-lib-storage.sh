# Check the existence of mount points.
check_mount_point() {
    local device="$1" mount_point="$2" fstype="$3" options="$4" label="$5"

    found_mount_point="$( lsblk $device -o MOUNTPOINT --noheadings )"

    if [ "$mount_point" != "$found_mount_point" ]; then
        echo "${device} shouldn't be mounted at ${found_mount_point}" >>/root/RESULT
    fi

    found_fstype="$( lsblk $device -o FSTYPE --noheadings )"

    if [ "$fstype" != "$found_fstype" ]; then
        echo "${device} shouldn't have fstype ${found_fstype}" >>/root/RESULT
    fi

    found_label="$( lsblk $device -o LABEL --noheadings )"

    if [ "$label" != "$found_label" ]; then
        echo "${device} shouldn't have label ${found_label}" >>/root/RESULT
    fi

    found_options="$( findmnt --fstab $device -o OPTIONS --noheadings )"

    if [ "$options" != "$found_options" ]; then
        echo "${device} shouldn't have options ${found_options}" >>/root/RESULT
    fi

}
