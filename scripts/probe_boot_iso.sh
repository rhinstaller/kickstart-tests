#!/bin/sh
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
#
# This script returns:
# NAME=name of the system in boot.iso. (e.g. "fedora", "rhel")
# VERSION=version number of this system. (e.g. "7.3", "25")
#

set -eu

if [[ $# -ne 1 ]];then
    echo "Exactly one parameter is required" >&2
    echo "" >&2
    echo "Usage: ./probe_boot_iso.sh path/to/boot.iso" >&2
    exit 1
fi

IMAGE="$1"

# Probe boot.iso → install.img → stage 2 and dig out useful information from it.
ISO_TMP=$(mktemp -d /tmp/kstest-iso.XXXXXXX)
trap "rm -rf '$ISO_TMP'" EXIT INT QUIT PIPE

# Extract install.img
# Try Fedora directory structure (isoinfo does not fail on nonexisting files)
isoinfo -R -i "$IMAGE" -x /images/install.img > "$ISO_TMP/install.img"
if [ ! -s "$ISO_TMP/install.img" ]; then
    # Try RHEL-7 directory structure
    isoinfo -R -i "$IMAGE" -x /LiveOS/squashfs.img > "$ISO_TMP/install.img"
    if [ ! -s "$ISO_TMP/install.img" ]; then
        echo "Error: Did not find install image inside $IMAGE" >&2
        exit 3
    fi
fi


# Extract files from stage2
OS_RELEASE=/etc/os-release
ROOTFS=/LiveOS/rootfs.img
LORAX_PACKAGES=/root/lorax-packages.log

unsquashfs -no-xattrs -follow -no-progress -d "$ISO_TMP/stage2" "$ISO_TMP/install.img" $OS_RELEASE $ROOTFS $LORAX_PACKAGES
rm "$ISO_TMP/install.img"
chmod -R a+w $ISO_TMP

# Extract required information from stage2
if [ -e "$ISO_TMP/stage2$OS_RELEASE" ]; then
    cp "$ISO_TMP/stage2$OS_RELEASE" "$ISO_TMP/os-release"
    cp "$ISO_TMP/stage2$LORAX_PACKAGES" "$ISO_TMP/lorax-packages.log"
else
    # On RHEL-8 and RHEL-9 the filesystem is packed in ext4 image (ENGCMP-766)
    timeout -k 10s 30s virt-cat -a "$ISO_TMP/stage2$ROOTFS" $OS_RELEASE > "$ISO_TMP/os-release"
    timeout -k 10s 30s virt-cat -a "$ISO_TMP/stage2$ROOTFS" $LORAX_PACKAGES > "$ISO_TMP/lorax-packages.log"
    if [ $? -eq 124 ]; then
        echo "Error: virt-cat timed out" >&2
        exit 4
    fi
fi

echo "PACKAGES=$(cat $ISO_TMP/lorax-packages.log | tr '\n' ' ')"

# Fast path to get version if ./discinfo is present (for Fedora); if it exists, it looks like this:
#    1587584254.021611
#    32
#    x86_64
DISCINFO_VER=$(isoinfo -R -x /.discinfo -i "$IMAGE" | sed -n '2 p')
if [ -n "$DISCINFO_VER" ]; then
    # make sure it looks like a Fedora version name/number, however we have a separate platform for ELN
    if [ "$DISCINFO_VER" = "Rawhide" ] || \
        grep -q "^[0-9]$" <<< "${DISCINFO_VER}" && \
        [ "$(echo $DISCINFO_VER | cut -d. -f1)" -gt 30 ]
    then
        echo "NAME=fedora"
        echo "VERSION=$DISCINFO_VER"
        exit 0
    fi
fi


# Return useful information to stdout
if [ "$DISCINFO_VER" = "eln" ]; then
    echo "NAME=fedora-eln"
else
    echo "NAME=$(. "$ISO_TMP/os-release"; echo "$ID")"
fi
echo "VERSION=$(. "$ISO_TMP/os-release"; echo "$VERSION_ID")"
