# Common functions for %pre kickstart section of hard drive tests.

# Fail on errors and unassigned variables.
set -eux

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
    download_iso "${url}" "hdd-mount/dvd.iso"

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
    download_iso "${url}" "source.iso"
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


# Download the ISO and save it at the specified path.
# The URL of the ISO can contain regexes in the ISO name.
# For example: http://my-server/Fedora-.*?.iso
function download_iso() {
    local url_pattern="$1"
    local output_path="$2"

    local iso_pattern=""
    iso_pattern="$(basename "${url_pattern}")"

    local iso_location=""
    iso_location="$(dirname "${url_pattern}")"

    local iso_name=""
    iso_name="$(curl -L ${iso_location} | grep -Po "${iso_pattern}" | head -n 1)"

    if [ -z "${iso_name}" ]; then
      echo "Nothing matched \"${iso_pattern}\" at \"${iso_location}\"."
      exit 1
    fi

    curl -L "${iso_location}/${iso_name}" -o "${output_path}"
}
