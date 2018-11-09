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

# TODO:
# - tests for one / more network devices
# - checking grub boot options (ip=ibft, iscsi_firmware)
# - modifying test results by actually booting into system (eg boot works, default route)
#   - just use sanboot in ipxe script:
#     sanboot iscsi:${target_ip}:::0:${wwn}

TESTTYPE="knownfailure iscsi"

. ${KSTESTDIR}/functions.sh

iscsi_disk_img=iscsi-disk.img
ipxe_image="/usr/share/ipxe/ipxe.lkrn"
ipxe_script="ibft.ipxe"

# Kernel arguments will go into ipxe script
kernel_args() {
    echo ""
}

real_kernel_args() {
    local tmpdir=$1
    . ${tmpdir}/httpd_url
    # Get the label of the iso
    # Volume id: Fedora-S-dvd-x86_64-25
    # Volume id: RHEL-7.3 x86_64
    iso=${tmpdir}/$(basename ${IMAGE})
    local label_line="$(isoinfo -d -i ${iso} | egrep "Volume id:")"
    local iso_label=$(udev_escape "${label_line:11}")
    echo ${DEFAULT_BOOTOPTS} ip=ibft inst.ks=${httpd_url}ks.cfg stage2=hd:CDLABEL=${iso_label}
}

# arguments for virt-install --network options
prepare_network() {
    echo "network:default"
    echo "network:default"
}

# diskless installation
prepare_disks() {
    echo ""
}

additional_runner_args() {
#--boot 'kernel=/usr/share/ipxe/ipxe.lkrn,kernel_args=ifconf -c dhcp net0 && chain http://10.34.39.2/trees/rv/ibft-tests/test2-m2/install.ipxe
    . ${tmpdir}/httpd_url
    ipxe_script_url="${httpd_url}${ipxe_script}"
    echo "--boot kernel=${ipxe_image},kernel_args='ifconf -c dhcp net0 && chain ${ipxe_script_url}'"
}

boot_args() {
    . ${tmpdir}/httpd_url
    ipxe_script_url="${httpd_url}${ipxe_script}"
    echo "--boot kernel=${ipxe_image},kernel_args='ifconf -c dhcp net0 && chain ${ipxe_script_url}'"
}

prepare() {
    ks=$1
    tmpdir=$2

    ### Bring up iscsi target

    if ! type targetcli &> /dev/null; then
        echo "ENVIRONMENT: missing targetcli tools required by the test"
        exit 1
    fi

    if [ ! -f ${ipxe_image} ]; then
        echo "ENVIRONMENT: missing ${ipxe_image} (ipxe-bootimgs package)"
    fi

    if ! type isoinfo &> /dev/null; then
        # This would be pulled in by lorax
        echo "ENVIRONMENT: missing isoinfo tool (genisoimage package)"
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

    ### Run http server serving kickstart

    # Copy the kickstart to a directory in tmpdir
    local http_dir=${tmpdir}/http
    mkdir ${http_dir}
    cp $ks ${http_dir}/ks.cfg

    # Start a http server to serve the included file
    start_httpd ${http_dir} $tmpdir

    echo httpd_url=${httpd_url} > ${tmpdir}/httpd_url

    ### Serve also installer image, kernel and initrd for ipxe
    # copy from boot.iso
    mnt_iso_dir=${tmpdir}/mntiso
    mkdir ${mnt_iso_dir}
    mount ${tmpdir}/$(basename ${IMAGE}) ${mnt_iso_dir}
    # kernel
    cp ${mnt_iso_dir}/images/pxeboot/vmlinuz ${http_dir}
    # initrd
    cp ${mnt_iso_dir}/images/pxeboot/initrd.img ${http_dir}
    umount ${mnt_iso_dir}
    rmdir ${mnt_iso_dir}

    ### Create ipxe script to be chainloaded via http
    # sanhook command creates the ibft table

    local kargs=$(real_kernel_args $tmpdir)
    # set updates image link if -u parameter was used
    if [[ "${UPDATES}" != "" ]]; then
        kargs="$kargs inst.updates=${UPDATES}"
    fi

    cat << EOF > ${http_dir}/${ipxe_script}
#!ipxe

## CASE: using separate device (net1) for ibft
#ifconf -c dhcp net1
#ifopen net1
#ifclose net0
#sanhook iscsi:${target_ip}:::0:${wwn}
#ifopen net0

## CASE: using separate device (net1) for ibft
##       with static configuration and vlan id configuration
#vcreate --tag 222 net1
#ifopen net1-222
#set net1-222/ip 192.168.111.1
#set net1-222/gateway 192.168.111.222
#set net1-222/netmask 255.255.255.0
#ifclose net0
#sanhook iscsi:${target_ip}:::0:${wwn}
#ifopen net0

## CASE: using single device (net0) both to fetch ks, kernel, intird and ibft
sanhook iscsi:${target_ip}:::0:${wwn}

kernel ${httpd_url}vmlinuz ${kargs}
initrd ${httpd_url}initrd.img

boot
EOF

    echo "${ks}"
}

inject_ks_to_initrd() {
    echo "false"
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
    local http_dir=${tmpdir}/http

    # Remove images fetched by ipxe
    rm -f ${http_dir}/vmlinuz
    rm -f ${http_dir}/initrd.img

    ### Kill the http server
    if [ -f ${tmpdir}/httpd-pid ]; then
        kill $(cat ${tmpdir}/httpd-pid)
    fi

}
