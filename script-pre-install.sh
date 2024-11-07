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

# Define the path to the config file (must match the path in log_handler.py)
CONFIG_FILE_PATH="/tmp/ignored_simple_tests.conf"

# Write the messages to ignore into the config file
# In this example, we're adding "Traceback" to be ignored
echo "Traceback" > "${CONFIG_FILE_PATH}"

validate() {
    local disksdir=$1
    local status=0

    # Check for exactly two "SUCCESS" messages in the log file
    local success_count
    success_count=$(grep -c "SUCCESS" "${disksdir}/virt-install.log")

    if [[ $success_count -lt 2 ]]; then
        echo "*** ERROR: Expected 2 SUCCESS messages, but found ${success_count}."
        status=1
    fi

    # Check for the specific error message in the virt-install.log
    if ! grep -q "Error code 1 running the kickstart script" "${disksdir}/virt-install.log"; then
        echo '*** ERROR: Expected error message "Error code 1 running the kickstart script" not found in virt-install.log.'
        status=1
    fi

    # Ensure that the "Unreachable code" message is NOT present.
    grep -q "Unreachable code" "${disksdir}/virt-install.log"
    if [[ $? == 0 ]]; then
        echo '*** ERROR: The test failed because unreachable code was executed after "exit 1".'
        status=1
    fi

    return ${status}
}
