#!/bin/bash
#
# Copyright (C) 2014, 2015  Red Hat, Inc.
#
# This copyrighted material is made available to anyone wishing to use,
# modify, copy, or redistribute it subject to the terms and conditions of
# the GNU General Public License v.2, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY expressed or implied, including the implied warranties of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.  You should have received a copy of the
# GNU General Public License along with this program; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301, USA.  Any Red Hat trademarks that are incorporated in the
# source code or documentation are not subject to the GNU General Public
# License and may only be used or replicated with the express permission of
# Red Hat, Inc.
#
# Red Hat Author(s): Jiri Konecny <jkonecny@redhat.com>
#
# Probe boot.iso and grab useful information for kickstart tests. Output of
# this script is returned to stdout as `KEY=value`. Every key-value will be
# printed on a separate line.
# You need to run this script as the root user, this is because of usage of
# mount and umount commands inside of the script.
#
# This script returns:
# NAME=name of the system in boot.iso. (e.g. "fedora", "rhel")
# VERSION=version number of this system. (e.g. "7.3", "25")
#


function clean_and_exit() {
    local msg="$1"
    local root_dir="$2"

    echo "$msg" >&2
    echo "Cleaning mounted directories" >&2
    umount $root_dir/stage2 $root_dir/image $root_dir/iso &>>/dev/null
    rm -rf $root_dir
    exit 3
}

if [[ $# -ne 1 ]];then
    echo "Exactly one parameter is required" >&2
    echo "" >&2
    echo "Usage: ./probe_boot_iso.sh path/to/boot.iso" >&2
    exit 1
fi

IMAGE="$1"

# Probe stage 2 in the input boot.iso and dig useful information from it.

# Mount boot.iso -> install.img -> stage2
ISO_TMP=$(mktemp -d /tmp/kstest-iso-mount.XXXXXXX)
if [[ -n $ISO_TMP ]]; then

    # 1) Mount boot.iso
    mkdir $ISO_TMP/iso
    mount -o loop,ro $IMAGE $ISO_TMP/iso
    if [[ $? -ne 0 ]]; then
        clean_and_exit "Error: Can't mount boot iso" $ISO_TMP
    fi

    # 2) Mount install.img
    mkdir $ISO_TMP/image
    # Try Fedora directory structure
    mount $ISO_TMP/iso/images/install.img $ISO_TMP/image 2>/dev/null
    if [[ $? -ne 0 ]]; then
        # Try RHEL-7 directory structure
        mount $ISO_TMP/iso/LiveOS/squashfs.img $ISO_TMP/image
        if [[ $? -ne 0 ]]; then
            clean_and_exit "Error: Can't mount image from boot iso" $ISO_TMP
        fi
    fi

    # 3) Mount stage2
    mkdir $ISO_TMP/stage2
    mount $ISO_TMP/image/LiveOS/rootfs.img $ISO_TMP/stage2
    if [[ $? -ne 0 ]]; then
        clean_and_exit "Error: Can't mount stage2 from install.img" $ISO_TMP
    fi
fi

# Take required information from stage2
ISO_OS_NAME=$(egrep -h "^ID=" $ISO_TMP/stage2/etc/*-release)
ISO_OS_NAME=$(echo ${ISO_OS_NAME#ID=} | tr -d \")
ISO_OS_VERSION=$(egrep -h "^VERSION_ID=" $ISO_TMP/stage2/etc/*-release)
ISO_OS_VERSION=$(echo ${ISO_OS_VERSION#VERSION_ID=} | tr -d \")

# Return useful information to the stdout
echo "NAME=$ISO_OS_NAME"
echo "VERSION=$ISO_OS_VERSION"

# Clean when work is done
umount $ISO_TMP/stage2 $ISO_TMP/image $ISO_TMP/iso
rm -rf $ISO_TMP
