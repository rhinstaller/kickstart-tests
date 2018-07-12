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
# Red Hat Author(s): Radek Vykydal <rvykydal@redhat.com>

# This is actually testing application of kickstart network commands in
# anaconda (which would normally be triggered by defining networking in %pre
# and %including it into kickstart).  It is caused by network kickstart
# commands not being applied in dracut because for ks=file:/ks.cfg (kickstart
# injected in initrd) network devices are not found in sysfs in the time of
# parsing the kickstart.

# This test is relevant only for RHEL7, the legacy options are not supported
# in Fedora (as of now).
TESTTYPE="knownfailure network"

. ${KSTESTDIR}/functions.sh


ip_static_boot_config=""

kernel_args() {
    . ${tmpdir}/ip_static_boot_config
    . ${tmpdir}/ks_url
    echo vnc debug=1 inst.debug rd.break=cmdline ${ip_static_boot_config} ks=${ks_url}
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

    # Substitute IP ranges of created network in kickstart
    sed -i -e s#@KSTEST_STATIC_IP@#${ip}# -e s#@KSTEST_STATIC_NETMASK@#${netmask}# -e s#@KSTEST_STATIC_GATEWAY@#${gateway}# ${ks}
    #ip=10.34.102.233::10.34.102.254:255.255.255.0::ens9:none
    echo "ip_static_boot_config=\"ip=${ip} gateway=${gateway} netmask=${netmask} ksdevice=ens3\"" > ${tmpdir}/ip_static_boot_config

    ### Run http server serving kickstart

    # Copy the kickstart to a directory in tmpdir
    mkdir ${tmpdir}/http
    cp $ks ${tmpdir}/http/ks.cfg

    # Start a http server to serve the included file
    start_httpd ${tmpdir}/http $tmpdir

    echo ks_url=${httpd_url}ks.cfg > ${tmpdir}/ks_url
    echo "${ks}"
}

inject_ks_to_initrd() {
    echo "false"
}

# Arguments for virt-install --network options
prepare_network() {
    local tmpdir=$1
    local network=$(basename ${tmpdir})
    echo "network:${network}"
    echo "network:default"
}

cleanup() {
    local tmpdir=$1

    ### Destroy dedicated network
    local network=$(basename ${tmpdir})
    virsh net-destroy ${network}

    ### Kill the http server
    if [ -f ${tmpdir}/httpd-pid ]; then
        kill $(cat ${tmpdir}/httpd-pid)
    fi
}
