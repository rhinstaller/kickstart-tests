#
# Copyright (C) 2020  Red Hat, Inc.
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
# Red Hat Author(s): Vendula Poncova <vponcova@redhat.com>

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="payload ostree skip-on-rhel skip-on-centos skip-on-fedora-eln gh1023"

. ${KSTESTDIR}/functions.sh

kernel_args() {
    # Enforce the Fedora-IoT configuration.
    echo ${DEFAULT_BOOTOPTS} inst.profile=fedora-iot
}

validate() {
    # We are not able to copy files from the system.
    # Look for the result in the logs we have.
    local disksdir=$1
    cat "${disksdir}/virt-install.log" | grep -q "SUCCESS"

    if [[ $? != 0 ]]; then
        status=1
        echo '*** The test has failed.'
        return 1
    fi

    return 0
}
