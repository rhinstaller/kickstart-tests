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

#TESTTYPE="packaging"

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="skip-on-fedora payload manual"

. ${KSTESTDIR}/libs/functions.sh


# This test is created for manual testing mainly.
# You have to set unified server in the inst.repo here but we don't have
# a reasonable way how to do that in the shell file.

kernel_args() {
    # Enable to test the boot option.
    # HTTP
    # echo inst.repo=http://<unified-server>
    # FTP
    # echo inst.repo=ftp://<unified-server>
    # NFS
    # echo inst.repo=nfs:<server>:<path>
    # CDROM (have to be booted with unified ISO)
    # echo inst.repo=cdrom:<device>

    # Enable for manual testing.
    # echo vnc=0 debug=1 inst.nokill

    # Choose UI for manual testing.
    # echo inst.text
    # echo inst.graphical
}
