#
# Copyright (C) 2017  Red Hat, Inc.
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
# Red Hat Author(s): Jiri Konecny <jkonecny@redhat.com>

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="payload proxy"

. ${KSTESTDIR}/functions.sh
. ${KSTESTDIR}/functions-proxy.sh

prepare() {
    local ks=$1
    local tmp_dir=$2
    local httpd_url=""
    local proxy_url=""
    httpd_url=$(cat ${tmpdir}/httpd_url)
    proxy_url=$(cat ${tmpdir}/proxy_url)
    mkdir "${tmp_dir}/http"

    # Create the addon repository.
    "${PWD}/scripts/generate-repository.py" "${tmp_dir}/http" "addon"

    # Prepare configuration file for squid authentication
    mkdir "${tmp_dir}/proxy"
    cp "${PWD}/scripts/../lib/basic_squid_auth.py" "${tmp_dir}/proxy/"
    echo "anaconda:qweqwe" > "${tmp_dir}/proxy/squid_auth.pass"

    # Start a http and proxy server that will provide the repository.
    start_httpd "${tmp_dir}/http" "${tmp_dir}"
    start_proxy "${tmp_dir}/proxy" "squid-pass.conf"

    # The test runs in a VM with user mode networking (10.0.0.0/24). Networking
    # inside the container also uses the 10.0.0.0/24 (or /16) subnet. Both proxy
    # and http servers run inside the container, accessible at IP address 10.0.2.2
    # from the VM. A problem appears when the VM requests repodata from the http
    # server at 10.0.2.2 via proxy running at 10.0.2.2 - the request is routed
    # outside of the container.
    # As a not-so-nice solution/workaround, use the container's loopback device
    # instead of the IP address 10.0.2.2 to access the http server via proxy.
    local httpd_local_url="$(echo $httpd_url | sed -r 's|([0-9]+\.){3}[0-9]+|127.0.0.1|')"

    # Get the proxy IP:PORT to replace in the kickstart file
    local proxy_ip_port="$(echo $proxy_url | grep -oE '([0-9]+\.){3}[0-9]+:[0-9]+')"

    # Substitute variables in the kickstart file.
    sed -e  "/^repo/ s|HTTP-ADDON-REPO|${httpd_local_url}|" \
        -e  "/^[^#]/ s|PROXY-ADDON|${proxy_ip_port}|" \
        "${ks}" > "${tmp_dir}/ks.cfg"

    echo "${tmp_dir}/ks.cfg"
}

validate() {
    tmpdir=$1
    validate_RESULT $tmpdir
    if [ ! -f $tmpdir/RESULT ]; then
        return 1
    fi

    check_proxy_settings $tmpdir

    # HTTPS direct mirror; we don't need to capture hostname here
    httpsdir=$(echo "$KSTEST_URL" | grep -e 'https:')

    # unless direct https URL was used, also check for:
    if [ ! "$httpsdir" ]; then
        # mandatory-package-from-addon from the addon repo
        grep -q 'mandatory-package-from-addon.*\.rpm' $tmpdir/proxy/access.log
        if [[ $? -ne 0 ]]; then
            echo 'addon repo package requests were not proxied' >> $tmpdir/RESULT
        fi

        # Finally, check that the repoquery used the proxy
        grep -q 'repodata/repomd.xml' $tmpdir/proxy/access.log
        if [[ $? -ne 0 ]]; then
            echo 'repoquery on installed system was not proxied' >> $tmpdir/RESULT
        fi
    fi

    check_result_file "${tmpdir}"
    return $?
}

cleanup() {
    tmpdir=$1

    if [ -f ${tmpdir}/httpd-pid ]; then
        kill $(cat ${tmpdir}/httpd-pid)
    fi

    stop_proxy ${tmpdir}/proxy
}
