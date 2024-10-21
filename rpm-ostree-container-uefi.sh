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
TESTTYPE="payload uefi ostree bootc keyboard reboot skip-on-rhel-8 skip-on-rhel-9 skip-on-rhel-10"

. ${KSTESTDIR}/functions.sh

enable_uefi() {
    echo "true"
}

copy_interesting_files_from_system() {
    local disksdir
    disksdir="${1}"

    # Find disks.
    local args
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)

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
    #
    # The location of aforementioned files is different in an ostree system

    root_device=$(guestfish ${args} <<< "
        launch
        lvs" | \
        grep root)

    for item in /ostree/deploy/test-stateroot/var/roothome/original-ks.cfg \
                /ostree/deploy/test-stateroot/var/roothome/anaconda-ks.cfg \
                /ostree/deploy/test-stateroot/var/roothome/anabot.log \
                /ostree/deploy/test-stateroot/var/log/anaconda/ \
                /ostree/deploy/test-stateroot/var/roothome/RESULT
    do
        guestfish ${args} <<< "
            launch
            mount ${root_device} /
            copy-out '${item}' '${disksdir}'
            " 2>/dev/null
    done
}

additional_runner_args() {
   # Wait for reboot and shutdown of the VM,
   # but exit after the specified timeout.
   echo "--wait $(get_timeout)"
}
