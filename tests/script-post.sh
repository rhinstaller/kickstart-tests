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

. ${KSTESTDIR}/libs/functions.sh

validate() {
    local disksdir=$1
    local status=0

    # Check if the nochroot log file exists and contains expected output
    if [[ ! -f "${disksdir}/root/post-nochroot.log" ]]; then
        echo "*** ERROR: nochroot log file does not exist"
        status=1
    elif ! grep -q "Post-install (nochroot) script finished" "${disksdir}/root/post-nochroot.log"; then
        echo "*** ERROR: nochroot log does not contain expected 'finished' message"
        status=1
    fi

    # Check if the chroot log file exists and contains expected output
    if [[ ! -f "${disksdir}/root/post-chroot.log" ]]; then
        echo "*** ERROR: chroot log file does not exist"
        status=1
    elif ! grep -q "Post-install (chroot) script finished" "${disksdir}/root/post-chroot.log"; then
        echo "*** ERROR: chroot log does not contain expected 'finished' message"
        status=1
    fi

    validate_RESULT $1
    return $? || status
}

