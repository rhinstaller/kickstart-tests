#
# Copyright (C) 2018  Red Hat, Inc.
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
# Red Hat Author(s): Martin Kolman <mkolman@redhat.com>

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="packaging skip-on-rhel payload"

. ${KSTESTDIR}/functions.sh

prepare_disks() {
    tmpdir=$1

    qemu-img create -q -f qcow2 ${tmpdir}/disk-a.img 20G
    echo ${tmpdir}/disk-a.img
}

# This rest effectively builds a Fedora live image, which
# among other things installs 1600+ packages and does various
# fairly resource intensive tasks. So bump the timeout
# to give it more time to do what's needed.
get_timeout() {
    echo "60"
}
