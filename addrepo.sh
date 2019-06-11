#
# Copyright (C) 2019  Red Hat, Inc.
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

TESTTYPE="packaging"

. ${KSTESTDIR}/functions.sh

prepare() {
    ks=$1
    tmpdir=$2

    scriptdir=$PWD/scripts

    # Create the test repo
    PYTHONPATH=${KSTESTDIR}/lib:$PYTHONPATH ${scriptdir}/make-addon-pkgs.py $tmpdir

    # Start a http server and proxy server to serve the repos
    start_httpd ${tmpdir}/http $tmpdir

    echo "${ks}"
}

kernel_args() {
    tmpdir="$1"

    httpd_url="$(cat ${tmpdir}/httpd_url)"

    echo ${tmpdir} -- ${httpd_url} > /tmp/addrepo-test.log

    echo "${DEFAULT_BOOTOPTS} inst.addrepo=LOCAL,${httpd_url}"
}

cleanup() {
    ### Kill the http server
    if [ -f ${tmpdir}/httpd-pid ]; then
        kill $(cat ${tmpdir}/httpd-pid)
    fi
}
