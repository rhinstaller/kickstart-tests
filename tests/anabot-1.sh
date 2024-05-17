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
TESTTYPE="ui anabot skip-on-rhel-8 knownfailure"

. ${KSTESTDIR}/functions.sh

kernel_args() {
    local tmp_dir="${1}"

    # Provide an installation source.
    local repo_url="${KSTEST_URL}"

    # Provide the anabot recipe.
    cp ${KSTESTDIR}/${name}.xml ${tmp_dir}/http/example.xml
    local httpd_url="$(cat ${tmp_dir}/httpd_url)"
    local recipe_url="${httpd_url}/example.xml"

    echo "${DEFAULT_BOOTOPTS} inst.graphical  anabot=${recipe_url} inst.repo=${repo_url}"
}

prepare_updates() {
    local tmp_dir="${1}"
    local updates_dir="${tmp_dir}/updates"
    local updates_img="${tmp_dir}/updates.img"

    local anabot_branch="main"
    local anabot_url="https://pagure.io/anabot.git"
    local anabot_img="${tmp_dir}/anabot.tar.gz"

    # Create an updates image with anabot.
    (
      cd "${tmp_dir}" && \
      git clone --depth 1 --shallow-submodules -b "${anabot_branch}" "${anabot_url}" && \
      cd anabot && \
      git submodule --quiet update --init && \
      ./make_updates.sh "${anabot_img}"
    )

    # Apply the anabot updates image.
    apply_updates_image "file://${anabot_img}" "${updates_dir}"

    # Apply the provided updates image if any.
    apply_updates_image "${UPDATES}" "${updates_dir}"

    # Create a new updates image.
    create_updates_image "${updates_dir}" "${updates_img}"

    # Provide the image. The function prints the URL.
    upload_updates_image "${tmp_dir}" "${updates_img}"
}

inject_ks_to_initrd() {
    echo "false"
}

validate() {
    local tmp_dir="${1}"
    local errors=""

    # Copy logs.
    copy_interesting_files_from_system "${tmp_dir}"

    # Check the anabot logs.
    errors=$( grep 'ERROR\|FAIL' < "${tmp_dir}/anabot.log" )

    if [[ -n "${errors}" ]]; then
        echo "*** The anabot recipe has failed:" >> "${tmp_dir}/RESULT"
        echo "${errors}" >> "${tmp_dir}/RESULT"
    else
        echo "SUCCESS" > "${tmp_dir}/RESULT"
    fi

    check_result_file "${tmp_dir}"
}

cleanup() {
    local tmp_dir="${1}"
    stop_httpd "${tmp_dir}"
}
