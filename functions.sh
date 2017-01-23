#!/bin/bash
#
# Copyright (C) 2015  Red Hat, Inc.
# # This copyrighted material is made available to anyone wishing to use,
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
# Red Hat Author(s): Chris Lumens <clumens@redhat.com>

prereqs() {
    # No prereqs by default
    echo
}

kernel_args() {
    echo vnc debug=1 inst.debug
}

prepare() {
    ks=$1
    tmpdir=$2

    echo ${ks}
}

prepare_disks() {
    tmpdir=$1

    qemu-img create -q -f qcow2 ${tmpdir}/disk-a.img 10G
    echo ${tmpdir}/disk-a.img
}

prepare_network() {
    echo ""
}

validate_RESULT() {
    disksdir=$1
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)

    # Use also iscsi disk if there is any
    if [[ -n ${iscsi_disk_img} ]]; then
        args="${args} -a ${disksdir}/${iscsi_disk_img}"
    fi

    # Grab files out of the installed system while it still exists.
    # Grab these files:
    #
    # logs from Anaconda - whole /var/log/anaconda/ directory is copied out,
    #                      this can be used for saving specific test output
    # anaconda.coverage
    # RESULT file from the test
    for item in /root/anaconda.coverage \
                /var/log/anaconda/      \
                /root/RESULT
    do
        virt-copy-out ${args} ${item} ${disksdir}
    done

    # The /root/RESULT file was saved from the VM.  Check its contents
    # and decide whether the test finally succeeded or not.
    result=$(cat ${disksdir}/RESULT)
    if [[ $? != 0 ]]; then
        status=1
        echo '*** /root/RESULT does not exist in VM image.'
    elif [[ "${result}" != SUCCESS* ]]; then
        status=1
        echo "${result}"
    fi

    return ${status}
}

validate() {
    return $(validate_RESULT $1)
}

cleanup() {
    tmpdir=$1
}

start_httpd() {
    local httpd_root=$1
    local tmpdir=$2

    # Starts a http server rooted in $httpd_root. The PID of the server will be
    # written to $tmpdir/httpd-pid, and the URL for the server will be set in
    # $httpd_url

    local scriptdir=${PWD}/scripts
    local httpd_info="$(${scriptdir}/httpd.py "${httpd_root}")"

    # Parse out the port and PID
    local httpd_port="$(echo "$httpd_info" | cut -d ' ' -f 1)"
    local httpd_pid="$(echo "$httpd_info" | cut -d ' ' -f 2)"

    # Save the PID
    echo "${httpd_pid}" > ${tmpdir}/httpd-pid

    # Construct a URL
    httpd_url="http://$(${scriptdir}/find-ip):${httpd_port}/"
}

create_iscsi_target() {
    local wwn=$1
    local backstore=$2
    local imgfile=$3
    local logfile=$4

    targetcli backstores/fileio create ${backstore} ${imgfile} 10G &>> ${logfile}
    # we assume adding portal by targetcli by default
    targetcli iscsi/ create ${wwn} &>> ${logfile}
    targetcli iscsi/${wwn}/tpg1/luns create /backstores/fileio/${backstore} &>> ${logfile}
    # ACLs - disable, use demo mode
    targetcli /iscsi/${wwn}/tpg1/ set attribute authentication=0 demo_mode_write_protect=0 generate_node_acls=1 cache_dynamic_acls=1 &>> ${logfile}

    local scriptdir=${PWD}/scripts
    local target_ip=$(${scriptdir}/find-ip)
    echo ${target_ip}
}

remove_iscsi_target() {
    local wwn=$1
    local backstore=$2
    local imgfile=$3
    local logfile=$4

    targetcli /iscsi/ delete ${wwn} &>> ${logfile}
    targetcli /backstores/fileio/ delete ${backstore} &>> ${logfile}
    if [[ ${KEEPIT} == 1 ]]; then
        rm ${imgfile}
    fi
}
