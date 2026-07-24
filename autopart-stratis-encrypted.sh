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
# Red Hat Author(s): Vojtech Trefny <vtrefny@redhat.com>

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="autopart storage stratis skip-on-rhel skip-on-centos"

. ${KSTESTDIR}/functions.sh

validate() {
    disksdir=$1
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)

    # results are stored on the /boot partition
    local boot_dev
    boot_dev=$(run_with_timeout ${COPY_FROM_IMAGE_TIMEOUT} \
        "guestfish --ro ${args} run : list-filesystems" \
        | grep "ext\|xfs" | awk -F: '{ print $1 }')

    if [[ -z "$boot_dev" ]]; then
        echo '*** could not find boot partition in VM image.'
        return 1
    fi

    # copy logs from boot partition
    run_with_timeout ${COPY_FROM_IMAGE_TIMEOUT} \
        "guestfish --ro ${args} run : mount-ro ${boot_dev} / : copy-out /kstest-results ${disksdir}/" 2>/dev/null

    # move files to the normal location
    if [[ -d ${disksdir}/kstest-results ]]; then
        mv ${disksdir}/kstest-results/* ${disksdir}/ 2>/dev/null
        rm -rf ${disksdir}/kstest-results
    fi

    check_result_file "${disksdir}"
    return $?
}
