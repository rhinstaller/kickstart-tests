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

HTTP_SERVER_KS_SCP=fedorapeople.org:public_html/dns-global-exclusive-ks-tls-2.ks
HTTP_SERVER_KS_GET=rvykydal.fedorapeople.org/dns-global-exclusive-ks-tls-2.ks

if [ "$1" == "manual" ]; then
    # Create kickstart from templates by running the test in dry run
    sudo containers/runner/launch --dry-run dns-global-exclusive-ks-tls-2
    # Post the kickstart to the URL resolvable by 1.1.1.1
    scp data/logs/kstest-list-substituted/dns-global-exclusive-ks-tls-2.ks ${HTTP_SERVER_KS_SCP}
    # Run the test with kickstart fetched from the URL
    sudo containers/runner/launch dns-global-exclusive-ks-tls-2
    exit 0
fi

# Ignore unused variable parsed out by tooling scripts as test tags metadata
# shellcheck disable=SC2034
TESTTYPE=${TESTTYPE:-"network dns skip-on-rhel manual"}
KICKSTART_NAME=dns-global-exclusive-tls-2

. ${KSTESTDIR}/functions.sh

kernel_args() {
    . ${tmpdir}/ks_url
    echo ${DEFAULT_BOOTOPTS} rd.net.dns=dns+tls://1.1.1.1#one.one.one.one rd.net.dns-resolve-mode=exclusive rd.net.dns-backend=dnsconfd ip=10.0.2.200::10.0.2.2:255.255.255.0:::none inst.ks=${ks_url}
}

prepare() {
    ks=$1
    tmpdir=$2

    # Copy the kickstart to a unique remote location
    #scp $ks ${UNIQUE_HTTP_SERVER_KS_SCP}

    echo ks_url=http://${HTTP_SERVER_KS_GET} > ${tmpdir}/ks_url
    echo "${ks}"
}

inject_ks_to_initrd() {
    echo "false"
}

additional_runner_args() {
    # Wait for reboot and shutdown of the VM,
    # but exit after the specified timeout.
    echo "--wait $(get_timeout)"
}
