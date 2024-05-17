# Copyright (C) 2023  Red Hat, Inc.
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
# Red Hat Author(s): Petr Beranek <pberanek@redhat.com>

# Short summary:
#
# python-blivet hits an error when trying to use a device with an existing
# Btrfs file system. A typical use case might be installation of Fedora or
# RHEL on a device containing an existing installation of Fedora (uses Btrfs
# by default). For details see bugs covered by this test:
#   * https://bugzilla.redhat.com/show_bug.cgi?id=2139169
#   * https://bugzilla.redhat.com/show_bug.cgi?id=2139166
#
# Disk image was created via the following commands:
#   dd if=/dev/zero of=disk-a.img bs=1M seek=10240 count=1
#   sudo losetup -f disk-a.img
#   sudo parted --script /dev/<device> mklabel gpt  # use 'sudo losetup -l' to
#                                                   # discover actual <device> name
#   sudo parted --script /dev/<device> mkpart p1 btrfs 0% 100%
#   sudo mkfs.btrfs /dev/<device><partition>  # use 'lsblk' to discover actual
#                                             # <partition> name
#   sudo losetup -d /dev/<device>
#   tar caSf preexisting-btrfs.tar.xz disk-a.img

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="btrfs storage"

. ${KSTESTDIR}/functions.sh

prepare_disks() {
    local tmpdir="${1}"

    tar xJSf preexisting-btrfs.tar.xz -C "${tmpdir}"
    echo "${tmpdir}/disk-a.img"
}
