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
# Red Hat Author(s): Jiri Kortus <jikortus@redhat.com>

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="deprecated skip-on-rhel-8 skip-on-fedora skip-on-rhel-9 skip-on-centos-9 skip-on-fedora-eln rhel119216"

. ${KSTESTDIR}/functions.sh

prepare() {
    local ks=$1
    local tmpdir=$2

    # Extract content of a modular repository - some module is needed
    # in order to test the deprecation of 'module' command
    mkdir -p "${tmpdir}/http/modular-repo"
    tar xzf modular-repo.tar.gz -C "${tmpdir}/http/modular-repo"

    # Start HTTP server that will provide the repository
    start_httpd "${tmpdir}/http" "${tmpdir}"
    sed -i "s|@MODULAR-REPO-URL@|$(cat ${tmpdir}/httpd_url)|" "${ks}"

    echo "${ks}"
}

cleanup() {
    local tmpdir="${1}"
    stop_httpd "${tmp_dir}"
}

