#
# Copyright (C) 2022  Red Hat, Inc.
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
# Red Hat Author(s): David Shea <dshea@redhat.com>

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="packaging payload repo"

. ${KSTESTDIR}/functions.sh

prepare() {
    local ks=$1
    local tmp_dir=$2
    local httpd_url=""
    mkdir "${tmp_dir}/http"

    # Create the repositories 'addon-a' and 'addon-b'.
    "${PWD}/scripts/generate-repository.py" "${tmp_dir}/http/a" "addon-a"
    "${PWD}/scripts/generate-repository.py" "${tmp_dir}/http/b" "addon-b"

    # Start a http server to serve the test repo
    start_httpd "${tmp_dir}/http" "${tmp_dir}"

    # Substitute variables in the kickstart file.
    sed -e "s|REPO_A_URL|${httpd_url}/a|" \
        -e "s|REPO_B_URL|${httpd_url}/b|" \
        "${ks}" > "${tmp_dir}/ks.cfg"

    echo "${tmp_dir}/ks.cfg"
}


cleanup() {
    local tmp_dir="${1}"
    stop_httpd "${tmp_dir}"
}
