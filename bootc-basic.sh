#!/bin/bash
#
# Copyright (C) 2025  Red Hat, Inc.
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
# Red Hat Author(s): Paweł Poławski <ppolawsk@redhat.com>

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="skip-on-rhel-9 payload bootc"

. ${KSTESTDIR}/functions.sh

copy_interesting_files_from_system() {
    local disksdir
    disksdir="${1}"

    # Find disks.
    local args
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)

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

    # Find root device - use list-filesystems to find filesystem mounted at /
    root_device="$(guestfish ${args} <<< "
        launch
        list-filesystems
        " 2>/dev/null | awk -F'[:/]' '/btrfsvol:.*root/ {print "/" $3 "/" $4}')"

    # List directories and find the one ending in .0, then construct full path
    deployname=$(guestfish ${args} <<< "
        launch
        mount ${root_device} /
        ls /root/ostree/deploy/test-stateroot/deploy
        " 2>/dev/null | grep '\.0$' | head -1)

    deploydir="/root/ostree/deploy/test-stateroot/deploy/${deployname}"

    for item in /var/roothome/original-ks.cfg \
                /var/roothome/anaconda-ks.cfg \
                /var/roothome/anabot.log \
                /var/log/anaconda/ \
                /var/roothome/RESULT
    do
        guestfish ${args} <<< "
            launch
            mount ${root_device} /
            copy-out '${deploydir}${item}' '${disksdir}'
            "
    done
}
