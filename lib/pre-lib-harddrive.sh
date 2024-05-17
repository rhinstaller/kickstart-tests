# Common functions for %pre kickstart section of hard drive tests.

# A temporary mount directory.
MOUNT_DIR="/var/tmp/prep-mount"

# Download the ISO on a hard drive.
function prepare_iso() {
    local url="$1"
    local disk="$2"

    wipefs -a "${disk}"
    mkfs.ext4 -F "${disk}"
    mkdir "${MOUNT_DIR}"
    pushd "${MOUNT_DIR}"

    # Mount the new source
    mkdir hdd-mount
    mount "${disk}" hdd-mount

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
    local disk="$2"
    local directory="$3"

    wipefs -a "${disk}"
    mkfs.ext4 -F "${disk}"
    mkdir "${MOUNT_DIR}"

    # Mount the new source
    mount "${disk}" "${MOUNT_DIR}"
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
