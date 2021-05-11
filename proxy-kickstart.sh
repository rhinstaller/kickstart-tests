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
# Red Hat Author(s): David Shea <dshea@redhat.com>
#                    Jiri Konecny <jkonecny@redhat.com>

# FIXME: Anaconda crashes with "InvalidValueError: Proxy URL does not have valid format: malformed URL, cannot parse it."
TESTTYPE="method proxy knownfailure"

. ${KSTESTDIR}/functions.sh
. ${KSTESTDIR}/functions-proxy.sh

prepare() {
    ks=$1
    tmpdir=$2

    scriptdir=$PWD/scripts

    # Create the test repo
    PYTHONPATH=${KSTESTDIR}/lib:$PYTHONPATH ${scriptdir}/make-addon-pkgs.py $tmpdir

    # Start a http and proxy server to serve the test repo
    start_httpd ${tmpdir}/http ${tmpdir}
    start_proxy ${tmpdir}/proxy

    sed -e  "/^repo/ s|HTTP-ADDON-REPO|${httpd_url}|" \
        -re "/^(repo|url)/ s|PROXY-ADDON|${proxy_url}|" \
        -e  "/'proxy=/ s|PROXY-ADDON|${proxy_url%%/*}|" \
        ${ks} > ${tmpdir}/kickstart-repo.ks
    echo ${tmpdir}/kickstart-repo.ks
}

validate() {
    tmpdir=$1
    validate_RESULT $tmpdir
    if [ ! -f $tmpdir/RESULT ]; then
        return 1
    fi

    check_proxy_settings $tmpdir

    # HTTPS direct mirror; we don't need to capture hostname here
    httpsdir=$(echo "$KSTEST_URL" | grep -e '--url="\?https:')

    # unless direct https URL was used, also check for:
    if [ ! "$httpsdir" ]; then
        # testpkg-http-core from the addon repo
        grep -q 'testpkg-http-core.*\.rpm' $tmpdir/proxy/access.log
        if [[ $? -ne 0 ]]; then
            echo 'addon repo package requests were not proxied' >> $tmpdir/RESULT
        fi

        # Finally, check that the repoquery used the proxy
        tail -1 $tmpdir/proxy/access.log | grep -q repodata
        if [[ $? -ne 0 ]]; then
            echo 'repoquery on installed system was not proxied' >> $tmpdir/RESULT
        fi
    fi

    result=$(cat ${disksdir}/RESULT)
    if [[ $? != 0 ]]; then
        echo '*** /root/RESULT does not exist in VM image.'
        return 1
    elif [[ "${result}" != SUCCESS* ]]; then
        echo "${result}"
        return 1
    else
        return 0
    fi
}

cleanup() {
    local tmp_dir="${1}"
    stop_httpd "${tmp_dir}"
    stop_proxy "${tmp_dir}/proxy"
}
