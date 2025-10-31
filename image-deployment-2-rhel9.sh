#
# Copyright (C) 2021  Red Hat, Inc.
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
TESTTYPE="image-deployment skip-on-fedora skip-on-rhel-8 skip-on-rhel-10 skip-on-centos-10 skip-on-fedora-eln"
KICKSTART_NAME=image-deployment-2

. ${KSTESTDIR}/functions.sh

prepare_updates() {
    local tmp_dir="${1}"
    local updates_dir="${tmp_dir}/updates"
    local updates_img="${tmp_dir}/updates.img"
    local conf_dir="${updates_dir}/etc/anaconda/conf.d/"

    # Define a configuration snippet.
    mkdir -p "${conf_dir}"
    cat > "${conf_dir}/10-bare-metal.conf" <<EOF

[Anaconda]
# List of enabled Anaconda DBus modules.
activatable_modules =
     org.fedoraproject.Anaconda.Modules.Network
     org.fedoraproject.Anaconda.Modules.Payloads
     org.fedoraproject.Anaconda.Modules.Storage

[Installation Target]
# Should we install the network configuration?
can_configure_network = False

EOF

    # Apply the provided updates image if any.
    apply_updates_image "${UPDATES}" "${updates_dir}"

    # Create a new updates image.
    create_updates_image "${updates_dir}" "${updates_img}"

    # Provide the image. The function prints the URL.
    upload_updates_image "${tmp_dir}" "${updates_img}"
}

cleanup() {
    local tmp_dir="${1}"
    stop_httpd "${tmp_dir}"
}
