#
# Copyright (C) 2026  Red Hat, Inc.
#
# This copyrighted material is made available to anyone wishing to use,
# modify, copy, or redistribute it subject to the terms and conditions
# of the GNU General Public License v.2, or (at your option) any later
# version.  This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY expressed or implied, including the
# implied warranties of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU General Public License for more details.  You
# should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
# Any Red Hat trademarks that are incorporated in the source code or
# documentation are not subject to the GNU General Public License and
# may only be used or replicated with the express permission of Red
# Hat, Inc.
#
# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="ui skip-on-rhel-8 skip-on-rhel-9"

. ${KSTESTDIR}/functions.sh

validate() {
    local disksdir=$1
    local args
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)

    # Copy the output kickstart.
    run_with_timeout 1000s "virt-copy-out ${args} /root/anaconda-ks.cfg ${disksdir}"

    # Check that the rdp command with both options is present in the
    # output kickstart (round-trip of the kickstart data).
    grep -E "^rdp --username=user --password=12345$" ${disksdir}/anaconda-ks.cfg
    if [[ $? != 0 ]]; then
        echo '*** rdp command with username and password not present in output kickstart' >> ${disksdir}/RESULT
        cat ${disksdir}/RESULT
        return 1
    fi

    validate_RESULT ${disksdir}
    return $?
}
