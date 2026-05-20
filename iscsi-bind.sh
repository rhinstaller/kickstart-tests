#
# Copyright (C) 2015  Red Hat, Inc.
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
TESTTYPE=${TESTTYPE:-"iscsi"}

. ${KSTESTDIR}/iscsi.sh

prepare() {
    local ks=$1
    local tmpdir=$2

    local test_id
    test_id=$(basename "${tmpdir}")
    local lc_test_id
    lc_test_id=$(echo "${test_id,,}" | tr -c 'a-z0-9\n' '-')
    local wwn=iqn.2003-01.kickstart.test:${lc_test_id}
    local initiator=iqn.2009-02.com.example:${lc_test_id}
    local logfile=${tmpdir}/iscsi-target.log

    create_iscsi_target_vm ${wwn} ${initiator} ${tmpdir} ${logfile} || return 1

    # eth0 is the mcast NIC (PCI addr=0x10, iSCSI network)
    sed -i \
        -e "s#@KSTEST_ISCSI_IP@#10.10.10.1#g" \
        -e "s#@KSTEST_ISCSI_PORT@#3260#g" \
        -e "s#@KSTEST_ISCSI_TARGET@#${wwn}#g" \
        -e "s#@KSTEST_ISCSINAME@#${initiator}#g" \
        -e "s#@KSTEST_NETDEV1@#eth0#g" \
        ${ks}

    echo ${ks}
}
