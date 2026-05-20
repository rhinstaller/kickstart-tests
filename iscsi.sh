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

. ${KSTESTDIR}/functions.sh

kernel_args() {
    # net.ifnames=0: predictable ethN naming for ip= boot arg
    # On q35 (Fedora default), the mcast NIC at PCI addr=0x10 on bus 0 enumerates
    # before the libvirt NIC on bus 1, so eth0 = mcast NIC.
    echo ${DEFAULT_BOOTOPTS} net.ifnames=0 \
        ip=10.10.10.2:::255.255.255.0::eth0:none
}

prepare_network() {
    echo "user"
}

prepare_disks() {
    # No local disk — the iSCSI disk is the sole installation target
    echo ""
}

prepare() {
    local ks=$1
    local tmpdir=$2

    local test_id=$(basename ${tmpdir})
    local lc_test_id=$(echo "${test_id,,}" | tr -c 'a-z0-9\n' '-')
    local wwn=iqn.2003-01.kickstart.test:${lc_test_id}
    local initiator=iqn.2009-02.com.example:${lc_test_id}
    local logfile=${tmpdir}/iscsi-target.log

    create_iscsi_target_vm ${wwn} ${initiator} ${tmpdir} ${logfile} || return 1

    sed -i \
        -e "s#@KSTEST_ISCSI_IP@#10.10.10.1#g" \
        -e "s#@KSTEST_ISCSI_PORT@#3260#g" \
        -e "s#@KSTEST_ISCSI_TARGET@#${wwn}#g" \
        -e "s#@KSTEST_ISCSINAME@#${initiator}#g" \
        ${ks}

    echo ${ks}
}

additional_runner_args() {
    local mcast_port=$(cat ${tmpdir}/iscsi-mcast-port 2>/dev/null)
    if [ -n "${mcast_port}" ]; then
        echo "--qemu-commandline=-netdev"
        echo "--qemu-commandline=socket,id=iscsi0,mcast=230.0.0.1:${mcast_port},localaddr=127.0.0.1"
        echo "--qemu-commandline=-device"
        echo "--qemu-commandline=virtio-net-pci,netdev=iscsi0,addr=0x10"
    fi
    echo "--seclabel"
    echo "type=none"
}

validate() {
    local disksdir=$1

    local ssh_port=$(cat ${disksdir}/iscsi-ssh-port 2>/dev/null)
    if [ -z "${ssh_port}" ]; then
        echo '*** No SSH port file — cannot extract RESULT from iSCSI target VM'
        return 1
    fi

    local ssh_cmd="sshpass -p testcase ssh ${ISCSI_TARGET_SSH_OPTS} -p ${ssh_port} root@127.0.0.1"
    local scp_cmd="sshpass -p testcase scp ${ISCSI_TARGET_SSH_OPTS} -P ${ssh_port}"

    # Stop target VM cleanly so its disk image contains flushed data,
    # then extract /root/RESULT from the iSCSI backing store using guestfish
    # on the host side (no SSH needed after shutdown).
    ${ssh_cmd} 'sync; poweroff' &>/dev/null

    # Wait for target VM to fully shut down (max 60s)
    local domain=$(cat ${disksdir}/iscsi-target-domain 2>/dev/null)
    local target_disk=$(cat ${disksdir}/iscsi-target-disk 2>/dev/null)
    for i in $(seq 1 60); do
        virsh domstate "${domain}" 2>/dev/null | grep -q "shut off" && break
        virsh dominfo "${domain}" &>/dev/null || break
        sleep 1
    done
    virsh destroy "${domain}" &>/dev/null || true
    virsh undefine "${domain}" &>/dev/null || true

    if [ ! -f "${target_disk}" ]; then
        echo "*** Target VM disk not found at ${target_disk}"
        return 1
    fi

    # Extract the iSCSI backing store from the target VM's disk
    local backing_store=${disksdir}/iscsi-backing.img
    LIBGUESTFS_BACKEND=direct guestfish --ro -a "${target_disk}" -i \
        download /root/disk "${backing_store}" 2>>${disksdir}/guestfish.log

    if [ ! -f "${backing_store}" ] || [ ! -s "${backing_store}" ]; then
        echo "*** Failed to extract iSCSI backing store from target VM (see guestfish.log)"
        return 1
    fi

    # Extract RESULT and logs from the backing store
    LIBGUESTFS_BACKEND=direct virt-cat -a "${backing_store}" /root/RESULT \
        > ${disksdir}/RESULT.tmp 2>/dev/null \
        && mv ${disksdir}/RESULT.tmp ${disksdir}/RESULT \
        || echo "*** Failed to extract /root/RESULT from iSCSI backing store"

    LIBGUESTFS_BACKEND=direct virt-copy-out -a "${backing_store}" \
        /var/log/anaconda/ ${disksdir}/ 2>/dev/null

    rm -f "${backing_store}"

    check_result_file ${disksdir}
    return $?
}

cleanup() {
    local tmpdir=$1
    # Target VM may already be destroyed by validate(); handle gracefully
    local domain=$(cat ${tmpdir}/iscsi-target-domain 2>/dev/null)
    local disk=$(cat ${tmpdir}/iscsi-target-disk 2>/dev/null)
    local logfile=${tmpdir}/iscsi-target.log
    remove_iscsi_target_vm "${domain}" "${disk}" "${logfile}"
}
