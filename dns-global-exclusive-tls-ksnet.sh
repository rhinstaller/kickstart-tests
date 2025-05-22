#
# Copyright (C) 2025  Red Hat, Inc.
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

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE=${TESTTYPE:-"network dns stage2-from-compose"}

. ${KSTESTDIR}/functions.sh

kernel_args() {
    echo ${DEFAULT_BOOTOPTS} rd.net.dns=dns+tls://10.0.196.143#edns-idmops.psi.redhat.com rd.net.dns-resolve-mode=exclusive rd.net.dns-backend=dnsconfd
}

prepare() {
    local ks=$1

    # This is a private slirp network, so we can pick any config we like
    sed -i -e 's#@KSTEST_STATIC_IP@#10.0.2.200#g' -e 's#@KSTEST_STATIC_NETMASK@#255.255.255.0#g' -e 's#@KSTEST_STATIC_GATEWAY@#10.0.2.2#g' ${ks}

    echo ${ks}
}

additional_runner_args() {
    # Wait for reboot and shutdown of the VM,
    # but exit after the specified timeout.
    echo "--wait $(get_timeout)"
}

# Installer image is defined in kickstart via url command
stage2_from_ks() {
    echo "true"
}

# The test needs more RAM because installer image is downloaded from network
get_required_ram() {
    echo ${STAGE2_FROM_COMPOSE_RAM_SIZE}
}
