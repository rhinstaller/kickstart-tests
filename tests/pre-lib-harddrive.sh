# Common functions for %pre kickstart section of hard drive tests.

# A temporary mount directory.
MOUNT_DIR="/var/tmp/prep-mount"

# Download the ISO on a hard drive.
function prepare_iso() {
    local url="$1"
    local device="$2"

    mkdir "${MOUNT_DIR}"
    pushd "${MOUNT_DIR}"

    # Mount the new source
    mkdir hdd-mount
    mount "${device}" hdd-mount

    # Download iso to the DVD
    curl -L "${url}" -o hdd-mount/dvd.iso

    # Clean up
    umount hdd-mount
    popd
    rm -rf "${MOUNT_DIR}"
}

# Download the content of the ISO on a hard drive.
function prepare_tree() {
    local url="$1"
    local device="$2"
    local directory="$3"

    mkdir "${MOUNT_DIR}"

    # Mount the new source
    mount "${device}" "${MOUNT_DIR}"
    pushd "${MOUNT_DIR}"

    # Mount the ISO
    curl -L "${url}" -o source.iso
    mkdir iso-mount
    mount -oro source.iso iso-mount

    # Copy ISO content inside
    mkdir -p "${directory}"
    rsync -ahHvS --stats --inplace \
      --exclude=/isolinux --exclude=/images \
      --exclude=/EFI iso-mount/ "${directory}/"

    # Clean up
    umount iso-mount
    rm source.iso
    rm -rf iso-mount
    popd
    umount "${MOUNT_DIR}"
    rm -rf "${MOUNT_DIR}"
}

# Format a complete disk for hdd payload source
function format_whole_disk () {
    local disk="$1"

#    wipefs -a "${disk}"
    sgdisk --zap-all ${disk}
    mkfs.ext4 -F "${disk}"
}


# Format single partition on a disk for hdd payload source
function format_single_partition () {
    local disk="$1"
    # for example 12GiB
    local size="$2"

    sgdisk --zap-all ${disk}
    sgdisk --new=0:0:+${size} ${disk}
    mkfs.ext4 ${disk}1
}
