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

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="payload ostree bootc luks reboot skip-on-rhel-8 gh1533"

. ${KSTESTDIR}/functions.sh

copy_interesting_files_from_system() {
    local disksdir args luks_partition root_lv
    disksdir="${1}"

    # Find disks.
    args=$(echo "--ro"; for d in ${disksdir}/disk-*img; do echo -a ${d}; done)

    # Use also iscsi disks if there are any.
    # (this has been just copied over from the original function)
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
    #
    # The location of aforementioned files is different in an ostree system
    #
    # Please note that all of the 'passphrase' strings should be retained
    # UNINDENTED, because they represent the actual passphrase that is
    # read by guestfish from standard input

    file_list=(
        /ostree/deploy/test-stateroot/var/roothome/original-ks.cfg
        /ostree/deploy/test-stateroot/var/roothome/anaconda-ks.cfg
        /ostree/deploy/test-stateroot/var/roothome/anabot.log
        /ostree/deploy/test-stateroot/var/log/anaconda
        /ostree/deploy/test-stateroot/var/roothome/RESULT
    )

    luks_partition=$(
        for p in $(guestfish ${args} launch : list-partitions)
        do guestfish ${args} --keys-from-stdin &> /dev/null <<< "
            launch
            cryptsetup-open ${p} encrypted-lv
passphrase
            " && echo ${p} && break
        done
    )

    if [ -z "${luks_partition}" ]; then
        echo "Couldn't find LUKS-encrypted partition!"
        return 1
    fi
    root_lv=$(
        guestfish ${args} --keys-from-stdin <<< "
        launch
        cryptsetup-open ${luks_partition} encrypted_lv
passphrase
        lvs
        " | grep /root
    )

    guestfish ${args} --keys-from-stdin <<< "
        launch
        cryptsetup-open ${luks_partition} encrypted_lv
passphrase
        lvm-scan true
        mount ${root_lv} /
        $(for f in "${file_list[@]}"; do echo "-copy-out ${f} ${disksdir}"; done)
        "
}

additional_runner_args() {
   # Wait for reboot and shutdown of the VM,
   # but exit after the specified timeout.
   echo "--wait $(get_timeout)"
}
