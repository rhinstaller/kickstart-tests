# Check the existence of mount points.
check_mount_point() {
    local device="$1" mount_point="$2" fstype="$3" options="$4" label="$5"

    # FIXME: this finds only the first mountpont (for example for btrfs devices)
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

check_mount_point_fstab() {
    local device="$1" mount_point="$2" fstype="$3" options="$4" label="$5"

    uuid="$( lsblk $device -o UUID --noheadings )"

    found_label="$( lsblk $device -o LABEL --noheadings )"

    if [ "$label" != "$found_label" ]; then
        echo "${device} shouldn't have label ${found_label}" >>/root/RESULT
    fi

    show_fstab=false
    if [ "x" == "x$mount_point" ]; then

        found_mount_point_of_uuid="$(findmnt --fstab --json | jq -r --arg uuid "UUID=$uuid" \
                '.filesystems[] | select(.source==$uuid).target')"
        if [ "x" != "x$found_mount_point_of_uuid" ]; then
            echo "${device} is mounted to ${found_mount_point_of_uuid}" >>/root/RESULT
            show_fstab=true
        else
           return
        fi
    fi

    # NOTE: there can be multiple mount points on a device
    found_uuid_of_mount_point="$(findmnt --fstab --json | jq -r --arg mp $mount_point \
        '.filesystems[] | select(.target==$mp).source')"
    if [ "UUID=$uuid" != "$found_uuid_of_mount_point" ]; then
        echo "${mount_point} is not mounted at ${device}" >>/root/RESULT
        show_fstab=true
    fi

    found_fstype_of_mount_point="$(findmnt --fstab --json | jq -r --arg mp $mount_point \
        '.filesystems[] | select(.target==$mp).fstype')"
    if [ "$fstype" != "$found_fstype_of_mount_point" ]; then
        echo "${mount_point} is not of type ${fstype}" >>/root/RESULT
        show_fstab=true
    fi

    found_options_of_mount_point="$(findmnt --fstab --json | jq -r --arg mp $mount_point \
        '.filesystems[] | select(.target==$mp).options')"
    if [ "$options" != "$found_options_of_mount_point" ]; then
        echo "${mount_point} does not have options ${options}" >>/root/RESULT
        show_fstab=true
    fi

    if [ $show_fstab == "true" ]; then
        cat /etc/fstab >> /root/RESULT
    fi
}
