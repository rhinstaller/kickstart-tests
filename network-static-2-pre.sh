#
# Copyright (C) 2016  Red Hat, Inc.
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

TESTTYPE="network"

. ${KSTESTDIR}/functions.sh

kernel_args() {
    echo ${DEFAULT_BOOTOPTS} ip=${KSTEST_NETDEV1}:dhcp ip=${KSTEST_NETDEV2}:dhcp ip=${KSTEST_NETDEV3}:dhcp
}

prepare() {
    local ks=$1
    local tmpdir=$2

    ### Create dedicated network to prevent IP address conflicts for parallel tests

    local network=$(basename ${tmpdir})

    local scriptdir=${PWD}/scripts
    local ips="$(${scriptdir}/create-network.py "${network}")"
    local ip="$(echo "$ips" | cut -d ' ' -f 1)"
    local netmask="$(echo "$ips" | cut -d ' ' -f 2)"
    local gateway="$(echo "$ips" | cut -d ' ' -f 3)"
    # Create 4 static IP addresses for 4 devices by incrementing the last octet
    local oct123="$(echo ${ip} | cut -d '.' -f 1,2,3)"
    local oct4="$(echo ${ip} | cut -d '.' -f 4)"
    local ip1="${oct123}.${oct4}"
    local ip2="${oct123}.$((oct4+1))"
    local ip3="${oct123}.$((oct4+2))"
    local ip4="${oct123}.$((oct4+3))"

    # Substitute IP ranges of created network in kickstart
    sed -i -e s#@KSTEST_STATIC_IP1@#${ip1}#g -e s#@KSTEST_STATIC_IP2@#${ip2}#g -e s#@KSTEST_STATIC_IP3@#${ip3}#g -e s#@KSTEST_STATIC_IP4@#${ip4}#g -e s#@KSTEST_STATIC_NETMASK@#${netmask}#g -e s#@KSTEST_STATIC_GATEWAY@#${gateway}#g ${ks}

    echo ${ks}
}

# Arguments for virt-install --network options
prepare_network() {
    local tmpdir=$1
    local network=$(basename ${tmpdir})
    echo "user"
    echo "network:${network}"
    echo "network:${network}"
    echo "network:${network}"
    echo "network:${network}"
}

cleanup() {
    local tmpdir=$1

    ### Destroy dedicated network
    local network=$(basename ${tmpdir})
    virsh net-destroy ${network}
}
