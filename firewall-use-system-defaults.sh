#
# Copyright (C) 2019  Red Hat, Inc.
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
# Red Hat Author(s): Martin Kolman <mkolman@redhat.com>

TESTTYPE="network firewall"

. ${KSTESTDIR}/functions.sh

validate() {
    # check if installation journal contains the expected
    # "using system defaults" log message
    regexp="ks file instructs to use system defaults for firewall, skipping configuration"
    error="*** expected skipping-configuration message not found in installation journal"
    validate_journal_contains $1 "${regexp}" "${error}"
    if [[ $? != 0 ]]; then
        cat ${1}/RESULT
        return 1
    fi

    return $(validate_RESULT ${disksdir})
}
