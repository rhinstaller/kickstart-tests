#
# Copyright (C) 2015  Red Hat, Inc.
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

TESTTYPE="logs"

. ${KSTESTDIR}/functions.sh

# The content of /etc/sysconfig/anaconda without comments.
expected_config=\
"
[BlivetGuiSpoke]
visited = 1

[CustomPartitioningSpoke]
visited = 1

[DatetimeSpoke]
visited = 1

[FilterSpoke]
visited = 1

[KeyboardSpoke]
visited = 1

[LangsupportSpoke]
visited = 1

[NetworkSpoke]
visited = 1

[SoftwareSelectionSpoke]
visited = 1

[SourceSpoke]
visited = 1

[StorageSpoke]
visited = 1

[General]
post_install_tools_disabled = 1"

validate() {
    disksdir=$1
    args=$(for d in ${disksdir}/disk-*img; do echo -a ${d}; done)

    # Copy the user interaction configuration file.
    virt-copy-out ${args} /etc/sysconfig/anaconda ${disksdir}

    # Does it exist?
    if [ ! -f "${disksdir}/anaconda" ]; then
        echo '*** /etc/sysconfig/anaconda does not exist in VM image.'
        return 1
    else
        # Rename the file, so it does not conflict with anaconda directory.
        mv ${disksdir}/anaconda ${disksdir}/anaconda.sysconfig

        # Load the content without the comments.
        real_config=$(grep -vE "^#" "${disksdir}/anaconda.sysconfig")

        # Compare with the expected content.
        diff <( echo "$real_config" ) <( echo "$expected_config" ) >/dev/null

        # If it is different, then fail.
        if [[ $? != 0 ]]; then
            echo '*** /etc/sysconfig/anaconda is different.'

            echo "CONFIG:"
            echo "$real_config"
            echo ""
            echo "EXPECTED CONFIG:"
            echo "$expected_config"
            echo ""

            return 1
        fi
    fi

    return $(validate_RESULT ${disksdir})
}
