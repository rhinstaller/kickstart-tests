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

TESTTYPE="iscsi"

. ${KSTESTDIR}/functions.sh

iscsi_disk_img=iscsi-disk.img

kernel_args() {
    echo vnc debug=1 inst.debug ip=dhcp
}

# Arguments for virt-install --network options
prepare_network() {
    echo "network:default"
    echo "network:default"
}

prepare() {
    ks=$1
    tmpdir=$2

    ### Bring up iscsi target

    if ! type targetcli &> /dev/null; then
        echo "ENVIRONMENT: missing targetcli tools required by the test"
        exit 1
    fi

    local imgfile=${tmpdir}/${iscsi_disk_img}
    local test_id=$(basename ${tmpdir})
    # use only lower case in target name
    local lc_test_id=${test_id,,}
    local backstore=${lc_test_id}
    local wwn=iqn.2003-01.kickstart.test:${lc_test_id}

    local target_port=3260
    local logfile=${tmpdir}/targetcli.log
    local target_ip=$(create_iscsi_target ${wwn} ${backstore} ${imgfile} ${logfile})
    local initiator=iqn.2009-02.com.example:${lc_test_id}

    # Substitute values of created target in kickstart
    sed -i -e s#@KSTEST_ISCSI_IP@#${target_ip}# -e s#@KSTEST_ISCSI_PORT@#${target_port}# -e s#@KSTEST_ISCSI_TARGET@#${wwn}# -e s#@KSTEST_ISCSINAME@#${initiator}# ${ks}

    echo ${ks}
}

cleanup() {
    tmpdir=$1

    ### Tear down iscsi target
    local imgfile=${tmpdir}/${iscsi_disk_img}
    local test_id=$(basename ${tmpdir})
    # use only lower case in target name
    local lc_test_id=${test_id,,}
    local backstore=${lc_test_id}
    local wwn=iqn.2003-01.kickstart.test:${lc_test_id}
    local logfile=${tmpdir}/targetcli.log
    remove_iscsi_target $wwn $backstore $imgfile $logfile
}
