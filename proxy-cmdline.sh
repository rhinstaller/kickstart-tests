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

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="payload proxy"

. ${KSTESTDIR}/functions.sh
. ${KSTESTDIR}/functions-proxy.sh

kernel_args() {
    proxy_url="$(cat ${tmpdir}/proxy_url)"
    echo ${DEFAULT_BOOTOPTS} inst.proxy=${proxy_url}
}

prepare() {
    ks=$1
    tmpdir=$2

    # Start a proxy server
    start_proxy ${tmpdir}/proxy

    cp ${ks} ${tmpdir}/kickstart.ks
    echo ${tmpdir}/kickstart.ks
}

validate() {
    tmpdir=$1
    validate_RESULT $tmpdir
    if [ ! -f $tmpdir/RESULT ]; then
        return 1
    fi

    check_proxy_settings $tmpdir

    check_result_file "${tmpdir}"
    return $?
}
