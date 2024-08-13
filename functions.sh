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

# Network device names are defined in the defaults (KSTEST_NETDEV<X> values)
if [[ -e scripts/defaults.sh ]]; then
    . scripts/defaults.sh
fi

# Platform-specific defaults
if [[ -n "${PLATFORM_NAME}" ]]; then
    if [[ -e "scripts/defaults-${PLATFORM_NAME}.sh" ]]; then
        . "scripts/defaults-${PLATFORM_NAME}.sh"
    fi
fi

if [[ -e $HOME/.kstests.defaults.sh ]]; then
    . $HOME/.kstests.defaults.sh
fi


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

enable_uefi() {
    # Run the VM in the UEFI mode.
    # This will add '--boot uefi' argument to the virt-install script
    # returns: "true" or "false"
    echo "false"
}

EXTRA_BOOTOPTS=$(echo "${KSTEST_EXTRA_BOOTOPTS}" | tr ';' ' ')

DEFAULT_BASIC_BOOTOPTS="debug=1 inst.debug ${EXTRA_BOOTOPTS}"

DEFAULT_DRACUT_BOOTOPTS="rd.shell=0 rd.emergency=poweroff"

DEFAULT_BOOTOPTS="${DEFAULT_BASIC_BOOTOPTS} ${DEFAULT_DRACUT_BOOTOPTS}"

# host IP with QEMU user mode network
USER_NET_HOST_IP=10.0.2.2

COPY_FROM_IMAGE_TIMEOUT=300s

kernel_args() {
    echo $DEFAULT_BOOTOPTS
}

prepare() {
    ks=$1
    tmpdir=$2

    echo ${ks}
}

prepare_updates() {
    local tmp_dir=$1
    echo "${UPDATES}"
}

prepare_disks() {
    # This function has to 'echo' one of the following.
    #
    # echo '<disk_path>'                                    -- ',bus=virtio' will be added automatically
    # echo '<disk_path>,<virt_install_disk_arguments>'      -- ',bus=virtio' will be added automatically
    # echo 'path=<disk_path>,<virt_install_disk_arguments>' -- the string is taken in this form (nothing will be added)
    #
    # DISK NAME(S):
    # End of '<disk_path>' must match 'disk-*.img', where '*' is any string
    # (though a letter starting from 'a' is recommened for consistency). So
    # for a single disk use 'disk-a.img', and for additional disks use
    # 'disk-b.img', 'disk-c.img' etc.
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
    if [[ $? == 124 ]]; then
        echo "ERROR: run_with_timeout ${duration} ${cmd} timed out"
        return 124
    fi
}

copy_file() {
    disks="$1"
    file="$2"
    dir="$3"

    run_with_timeout ${COPY_FROM_IMAGE_TIMEOUT} "virt-copy-out ${disks} ${file} ${dir}"
}

copy_file_encrypted() {
    disks="$1"
    file="$2"
    dir="$3"

    echo "passphrase" | \
    run_with_timeout ${COPY_FROM_IMAGE_TIMEOUT} "guestfish --keys-from-stdin --ro ${disks} -i copy-out ${file} ${dir}"
}

copy_file_encrypted_raid() {
    disks="$1"
    file="$2"
    dir="$3"

    # we only assume 1 RAID device
    md_device=$(run_with_timeout ${COPY_FROM_IMAGE_TIMEOUT} "guestfish --ro ${disks} launch : list-md-devices" 2>&1)
    md_devices_count=$(wc -l <<< ${md_device})
    echo "copy_file_encrypted_raid: md_device: ${md_device}"
    if [ ${md_devices_count} -ne 1 ]; then
        echo "Only 1 RAID device supported by encrypted_file_encrypted_raid()" > ${dir}/RESULT
        echo -e "${md_devices_count} MD devices found:\n${md_device}" >> ${dir}/RESULT
        exit 1
    fi

    # the here-string is unindented on purpose, as the passphrase can't contain leading spaces;
    # it's not possible to use --key /dev/xyz:key:key_string, likely due to a bug?
    run_with_timeout ${COPY_FROM_IMAGE_TIMEOUT} "guestfish --ro --keys-from-stdin ${disks}" <<< "
launch
# the line following after cryptsetup-open contains a LUKS passphrase
cryptsetup-open ${md_device} encrypted-root
passphrase
mount /dev/mapper/encrypted-root /
copy_out ${file} ${dir}
"
}

copy_interesting_files_from_system() {
    local disksdir="$1"

    # Find disks.
    local args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)

    # Use also iscsi disk if there is any.
    if [[ -n ${iscsi_disk_img} ]]; then
        args="${args} -a ${disksdir}/${iscsi_disk_img}"
    fi

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
                /root/anabot.log \
                /var/log/anaconda/ \
                /root/RESULT
    do
        copy_file "${args}" "${item}" "${disksdir}" 2>/dev/null
    done
}

validate_RESULT() {
    local tmp_dir="${1}"
    copy_interesting_files_from_system "${tmp_dir}"
    check_result_file "${tmp_dir}"
    return $?
}

check_result_file() {
    local tmp_dir="${1}"
    local status=0
    local result=""

    # The /root/RESULT file was saved from the VM.  Check its contents
    # and decide whether the test finally succeeded or not.
    result=$(cat "${tmp_dir}/RESULT")

    if [[ $? != 0 ]]; then
        status=1
        echo '*** /root/RESULT does not exist in VM image.'
    elif [[ "${result%% *}" != SUCCESS ]]; then
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
    run_with_timeout ${COPY_FROM_IMAGE_TIMEOUT} "virt-copy-out ${args} /var/log/anaconda/journal.log ${disksdir}"
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

stop_httpd() {
    local tmpdir=$1

    if [ -f ${tmpdir}/httpd-pid ]; then
        kill $(cat ${tmpdir}/httpd-pid)
    fi
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

    # Save the URL
    echo "${proxy_url}" > ${tmpdir}/proxy_url
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

apply_updates_image() {
    local image_url="${1}"
    local updates_dir="${2}"

    # Create the updates directory.
    mkdir -p "${updates_dir}"

    # Check the updates image.
    if [[ -z "${image_url}" ]]; then
        return
    fi

    # Download and extract the updates image.
    ( cd "${updates_dir}" ; curl -f "${image_url}" | gzip -dc  | cpio -idu )
}

create_updates_image() {
    local updates_dir="${1}"
    local updates_img="${2}"

    ( cd "${updates_dir}" ; find . | cpio -co | gzip -9 ) >"${updates_img}"
}

upload_updates_image() {
    local tmp_dir="${1}"
    local updates_img="${2}"

    # Copy the updates image.
    mkdir ${tmpdir}/http
    cp "${updates_img}" ${tmpdir}/http/updates.img

    # Start the http server.
    start_httpd ${tmpdir}/http ${tmpdir}

    # Provide the URL of the updates image.
    echo "${httpd_url}updates.img"
}

export_additional_repo() {
    # Export additional RPM repository via localhost web server if found in the
    # /opt/kstest/data/additional_repo well known path. We expect the folder
    # to just contain a bunch of RPM files and will copy its contents to a tempdir
    # and then run createrepo on it to make sure all necessary metadata is in place.
    #
    # Address of the localhost web server can be sourced from ${tmpdir}/addrepo_url
    # for use in kernel_args(). Also as this starts a localhost web server do not
    # forget to shut the server down in cleanup().
    #
    # This function expects one argument - path to the tempdir.
    local tmpdir=$1

    # check if additional repo exists on well known path

    if [ -e /opt/kstest/data/additional_repo ]; then
        # Copy the repo to the tmpdir so
        # that the createrepo call odes not
        # mess up the directory on the host.
        # FIXME: /opt/kstest/data should either come from a env var or
        #        runner script should copy the additional_repo folder to the
        #        tempdir
        cp -R /opt/kstest/data/additional_repo ${tmpdir}/kstest_additional_repo

        # We expect just a bunch of RPMs, so create all the expected
        # metadata for it.
        createrepo_c -q ${tmpdir}/kstest_additional_repo

        # log repo content for debugging purposes
        ls ${tmpdir}/kstest_additional_repo > ${tmpdir}/additional_repo_content

        # start a http server to serve the repo
        start_httpd ${tmpdir}/kstest_additional_repo ${tmpdir}

        # Store the server address in file so that it can be sourced later
        # (eq. in kernel_args() and similar).
        echo addrepo_url=${httpd_url} > ${tmpdir}/addrepo_url
    fi
}

append_additional_repo_to_kernel_args() {
    # Append boot options needed for using the additional RPM repository to
    # the provided list of boot options and return the result.
    #
    # If no additional repo appears to be in use, just return the boot option
    # string.
    #
    # This function expects one argument - boot options string.
    local bootopts=$1

    if [ -e ${tmpdir}/addrepo_url ]; then
        . ${tmpdir}/addrepo_url
        echo $bootopts inst.addrepo=KSTEST_ADDITIONAL_REPO,${addrepo_url}
    else
        echo $bootopts
    fi
}

get_timeout() {
    echo "30"
}

stage2_from_ks() {
    # Return true to get stage2 location from kickstart (inst.stage2 option will not be supplied).
    # returns: "true" or "false"
    echo "false"
}

# RAM size of VM for the test in MiB
get_required_ram() {
    echo "2048"
}
