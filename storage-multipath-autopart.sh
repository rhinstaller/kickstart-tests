#
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
# Red Hat Author(s): Jan Stodola <jstodola@redhat.com>

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="autopart storage rhbz1853668"

. ${KSTESTDIR}/functions.sh

additional_runner_args() {
    # Wait for reboot and shutdown of the VM,
    # but exit after the specified timeout.
    echo "--wait $(get_timeout)"
}

prepare_disks() {
    tmpdir=$1

    qemu-img create -q -f raw ${tmpdir}/disk-a.img 10G
    # define two paths pointing to the same image file
    echo path=${tmpdir}/disk-a.img,bus=scsi,shareable=on,serial=0001 \
         path=${tmpdir}/disk-a.img,bus=scsi,shareable=on,serial=0001
}
