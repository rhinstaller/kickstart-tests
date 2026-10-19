#
# Copyright (C) 2026  Red Hat, Inc.
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
# Red Hat Author(s): Radek Vykydal <rvykydal@redhat.com>

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="security skip-on-rhel-9 skip-on-rhel-10 skip-on-centos"

. ${KSTESTDIR}/functions.sh

prepare_disks() {
    local diskdir="$1"
    # main disk
    qemu-img create -q -f qcow2 ${diskdir}/disk-a.img 10G
    echo "${diskdir}/disk-a.img"

    # image with certificate
    mkdir -p ${diskdir}/iso_root/cert
    cp ${KSTESTDIR}/fragments/shared/data/rtt1.anaconda.redhat.com.crt ${diskdir}/iso_root/cert/server.crt
    genisoimage -R -J -V TEST_CERT_ISO -o ${diskdir}/cert.iso ${diskdir}/iso_root > /dev/null
    echo "path=${diskdir}/cert.iso,device=cdrom,readonly=on"
}

kernel_args() {
   echo ${DEFAULT_BOOTOPTS} inst.cert=hd:LABEL=TEST_CERT_ISO:/cert/server.crt
}

additional_runner_args() {
    # Wait for reboot and shutdown of the VM,
    # but exit after the specified timeout.
    echo "--wait $(get_timeout)"
}
