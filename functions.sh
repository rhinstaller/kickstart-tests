#!/bin/bash
#
# Copyright (C) 2020  Red Hat, Inc.
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

source network-device-names.cfg

prereqs() {
    # No prereqs by default
    echo
}

inject_ks_to_initrd() {
    # Return true to inject kickstart to initrd. If false is specified than other way to
    # use kickstart must be used.
    # returns: "true" or "false"
    echo "true"
}

DEFAULT_BASIC_BOOTOPTS="debug=1 inst.debug ${KSTEST_EXTRA_BOOTOPTS}"

DEFAULT_DRACUT_BOOTOPTS="rd.shell=0 rd.emergency=poweroff"

DEFAULT_BOOTOPTS="${DEFAULT_BASIC_BOOTOPTS} ${DEFAULT_DRACUT_BOOTOPTS}"

# host IP with QEMU user mode network
USER_NET_HOST_IP=10.0.2.2

kernel_args() {
    echo $DEFAULT_BOOTOPTS
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

additional_runner_args() {
    echo ""
}


boot_args() {
    echo ""
}

run_with_timeout() {
    # Sends TERM after duration time and eventually KILL after 10s
    # to the process run by cmd.
    # Returns 124 status if timeout was reached.
    duration="$1"
    cmd="$2"
    timeout -k 10s ${duration} ${cmd}
}

copy_file() {
    disks="$1"
    file="$2"
    dir="$3"

    run_with_timeout 1000s "virt-copy-out ${disks} ${file} ${dir}"
}

copy_interesting_files_from_system() {
    args="$1"
    disksdir="$2"

    # Grab files out of the installed system while it still exists.
    # Grab these files:
    #
    # logs from Anaconda - whole /var/log/anaconda/ directory is copied out,
    #                      this can be used for saving specific test output
    # original-ks.cfg - the kickstart used for the test
    # anaconda-ks.cfg - the kickstart saved after installation, useful for
    #                   debugging
    # RESULT - file from the test
    for item in /root/original-ks.cfg \
                /root/anaconda-ks.cfg \
                /var/log/anaconda/    \
                /root/RESULT
    do
        copy_file "${args}" "${item}" "${disksdir}" 2>/dev/null
    done
}

validate_RESULT() {
    disksdir=$1
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)

    # Use also iscsi disk if there is any
    if [[ -n ${iscsi_disk_img} ]]; then
        args="${args} -a ${disksdir}/${iscsi_disk_img}"
    fi

    copy_interesting_files_from_system "${args}" "${disksdir}"

    # The /root/RESULT file was saved from the VM.  Check its contents
    # and decide whether the test finally succeeded or not.
    status=0
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
    validate_RESULT $1
    return $?
}

validate_journal_contains() {
    # Check if journal from the installation contains a regexp,
    # write error message and return with 1 if the message has
    # not been found.
    disksdir=$1
    regexp=$2
    error=$3
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)
    # Copy the journal.log file
    run_with_timeout 1000s "virt-copy-out ${args} /var/log/anaconda/journal.log ${disksdir}"
    egrep -i "${regexp}" ${disksdir}/journal.log
    if [[ $? != 0 ]]; then
        echo "${error}" >> ${disksdir}/RESULT
        return 1
    fi
}

cleanup() {
    tmpdir=$1
}

start_httpd() {
    local httpd_root=$1
    local tmpdir=$2

    # Starts a http server rooted in $httpd_root. The PID of the server will be
    # written to $tmpdir/httpd-pid, and the URL for the server will be set in
    # $httpd_url and also written to $tmpdir/httpd_url file.

    local scriptdir=${PWD}/scripts
    local httpd_info="$(${scriptdir}/httpd.py "${httpd_root}")"

    # Parse out the port and PID
    local httpd_port="$(echo "$httpd_info" | cut -d ' ' -f 1)"
    local httpd_pid="$(echo "$httpd_info" | cut -d ' ' -f 2)"

    # Save the PID
    echo "${httpd_pid}" > ${tmpdir}/httpd-pid

    # Construct a URL
    httpd_url="http://${USER_NET_HOST_IP}:${httpd_port}/"

    # Save the URL
    echo "${httpd_url}" > ${tmpdir}/httpd_url
}

start_proxy() {
    local proxy_root=$1
    local config="squid.conf"

    if [ -n "$2" ]; then
        config="$2"
    fi

    # Starts a proxy server rooted in $proxy_root. The PID of the server will be
    # written to $tmpdir/proxy-pid, and the URL for the server will be set in
    # $proxy_url

    # Proxy must have rights for its folder
    mkdir -p ${proxy_root}
    chmod 777 ${proxy_root}

    local scriptdir=${PWD}/scripts

    # Copy configuration file for squid from confs folder to proxy_root
    # and launch the proxy.
    cp $scriptdir/confs/$config $proxy_root/squid.conf
    local proxy_info="$(${scriptdir}/launch_proxy.sh "${proxy_root}")"

    # Parse out the port
    local proxy_port="$(echo "$proxy_info" | cut -d ' ' -f 2)"

    # Construct a URL
    proxy_url="http://${USER_NET_HOST_IP}:${proxy_port}/"
}

stop_proxy() {
    local proxy_root=$1

    # Stops a proxy server rooted in $proxy_root.
    kill -15 $(cat $proxy_root/squid.pid)
}

udev_escape() {
    local string="$1"
    local scriptdir=${PWD}/scripts
    local escaped_string="$(${scriptdir}/udev_escape.py "${string}")"
    echo ${escaped_string}
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
    local target_ip=${USER_NET_HOST_IP}
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
