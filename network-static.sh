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
# Red Hat Author(s): Radek Vykydal <rvykydal@redhat.com>

# This is actually testing application of kickstart network commands in
# anaconda (which would normally be triggered by defining networking in %pre
# and %including it into kickstart).  It is caused by network kickstart
# commands not being applied in dracut because for ks=file:/ks.cfg (kickstart
# injected in initrd) network devices are not found in sysfs in the time of
# parsing the kickstart.

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE="network"

. ${KSTESTDIR}/functions.sh


kernel_args() {
    echo ${DEFAULT_BOOTOPTS} ip=dhcp
}

prepare() {
    local ks=$1

    # This is a private slirp network, so we can pick any config we like
    sed -i -e 's#@KSTEST_STATIC_IP@#10.0.2.200#g' -e 's#@KSTEST_STATIC_NETMASK@#255.255.255.0#g' -e 's#@KSTEST_STATIC_GATEWAY@#10.0.2.2#g' ${ks}

    echo ${ks}
}

# Arguments for virt-install --network options
prepare_network() {
    echo "user"
    echo "user"
}
