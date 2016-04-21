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
# Red Hat Author(s): David Shea <dshea@redhat.com>

TESTTYPE="method packaging"

. ${KSTESTDIR}/functions.sh

prepare() {
    ks=$1
    tmpdir=$2

    scriptdir=$PWD/scripts

    # Create the test repo
    PYTHONPATH=${KSTESTDIR}/lib:$PYTHONPATH ${scriptdir}/make-addon-pkgs.py $tmpdir

    # Start a http server to serve the test repo
    start_httpd ${tmpdir}/http ${tmpdir}

    sed -e "s|@KSTEST_HTTP_ADDON_REPO@|${httpd_url}|" ${ks} > ${tmpdir}/kickstart.ks

    # if NFS_ADDON_REPO isn't specified export it from the local system
    if [ -z "$KSTEST_NFS_ADDON_REPO" ]; then
        local scriptdir=${PWD}/scripts

        systemctl status nfs >/dev/null
        nfs_running=$?
        nfs_exported=0

        if [ "$nfs_running" == "0" ]; then
            nfs_exported=`showmount -e --no-headers | grep -c "$tmpdir/nfs"`
        fi

        if [ "$nfs_exported" == "0" ]; then
            cp /etc/exports /etc/exports.backup
            echo "$tmpdir/nfs   *(ro)" >> /etc/exports
            systemctl restart nfs >/dev/null
        fi

        nfs_url="nfs://$($scriptdir/find-ip):$tmpdir/nfs"
        sed -i "s|@KSTEST_NFS_ADDON_REPO@|$nfs_url|" $tmpdir/kickstart.ks
    fi

    echo ${tmpdir}/kickstart.ks
}

cleanup() {
    mv /etc/exports.backup /etc/exports
    systemctl restart nfs >/dev/null

    tmpdir=$1

    if [ -f ${tmpdir}/httpd-pid ]; then
        kill $(cat ${tmpdir}/httpd-pid)
    fi
}
