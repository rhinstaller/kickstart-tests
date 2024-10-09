#!/bin/bash
#
# Copyright (C) 2024  Red Hat, Inc.
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
# Red Hat Author(s): Adam Kankovsky <akankovs@redhat.com>

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="ksscript"

. ${KSTESTDIR}/functions.sh

validate() {
    # The test is looking for two conditions:
    # 1. SUCCESS must be found in the logs to confirm that the pre-script executed until exit 1.
    # 2. Ensure that no code after exit 1 was executed by checking if the "ERROR" message was written.

    local disksdir=$1
    local status=0

    # Look for the "SUCCESS" message in the logs to confirm pre-script started correctly.
    cat "${disksdir}/virt-install.log" | grep -q "SUCCESS"
    if [[ $? != 0 ]]; then
        echo '*** The pre-install script did not write "SUCCESS" as expected.'
        status=1
    fi

    # Ensure that the "ERROR: Pre-install script did not fail as expected." message is NOT present.
    cat "${disksdir}/virt-install.log" | grep -q "ERROR: Pre-install script did not fail as expected."
    if [[ $? == 0 ]]; then
        echo '*** The test has failed because code after "exit 1" was executed.'
        status=1
    fi

    # Return the final status
    return ${status}
}

