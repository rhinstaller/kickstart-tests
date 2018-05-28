#!/bin/bash
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
# Red Hat Author(s): Chris Lumens <clumens@redhat.com>
#                    Jiri Konecny <jkonecny@redhat.com>

# This script runs a single kickstart test on a single system.  It takes
# command line arguments instead of environment variables because it is
# designed to be driven by run_kickstart_tests.sh via parallel.  It is
# not for direct use.

# Possible return values:
# 0  - Everything worked
# 1  - Test failed for unspecified reasons
# 2  - Test failed due to time out
# 3  - Test failed due to kernel panic
# 77 - Something needed by the test doesn't exist, so skip

IMAGE=
KEEPIT=0

cleanup_tmp() {
    d=$1

    # Always remove the copy of the boot.iso.
    rm ${d}/$(basename ${IMAGE})

    if [[ ${KEEPIT} == 2 ]]; then
        return
    elif [[ ${KEEPIT} == 1 ]]; then
        rm -f ${d}/disk-*.img ${d}/*ks
    elif [[ ${KEEPIT} == 0 ]]; then
        rm -rf ${d}
    fi
}

runone() {
    t=$1

    export KSTESTDIR=$(pwd)

    ks=${t/.sh/.ks}
    . $t

    name=$(basename ${t%.sh})

    echo
    echo ===========================================================================
    echo ${ks} on $(hostname)
    echo ===========================================================================

    # qemu user needs to be able to read the directory and the boot.iso, so put that
    # into this directory as well.  It will get deleted later, regardless of the
    # KEEPIT setting.
    tmpdir=$(mktemp -d --tmpdir=/var/tmp kstest-${name}.XXXXXXXX)
    chmod 755 ${tmpdir}
    cp ${IMAGE} ${tmpdir}

    ksfile=$(prepare ${ks} ${tmpdir})
    if [[ $? != 0 ]]; then
        echo RESULT:${name}:FAILED:Test prep failed: ${ksfile}
        cleanup ${tmpdir}
        cleanup_tmp ${tmpdir}
        return 99
    fi

    # Check that the prepared kickstart is free of substitution markers. Normally
    # the substitutions are run by run_kickstart_tests.sh, but prepare has a chance
    # to run them too. If both of those left any @STUFF@ strings behind, fail.
    if [[ "${ksfile}" != "" ]]; then
        unmatched="$(grep -o '@[^[:space:]]\+@' ${ksfile} | head -1)"
        if [[ -n "$unmatched" ]]; then
            echo "RESULT:${name}:FAILED:Unsubstituted pattern ${unmatched}"
            cleanup ${tmpdir}
            cleanup_tmp ${tmpdir}
            return 99
        fi
        ks_args="--ks ${ksfile}"
    fi

    # set kernel arguments
    kargs=$(kernel_args)

    # add additional boot options
    if [[ "${BOOT_ARGS}" != "" ]]; then
        kargs="$kargs ${BOOT_ARGS}"
    fi

    # set updates image link if -u parameter was used
    if [[ "${UPDATES}" != "" ]]; then
        kargs="$kargs inst.updates=${UPDATES}"
    fi

    if [[ "${kargs}" != "" ]]; then
        kargs="--kernel-args \"$kargs\""
    fi

    disks=$(prepare_disks ${tmpdir})
    disk_args=$(for d in $disks; do echo "--disk $d,cache=unsafe"; done)

    nics=$(prepare_network ${tmpdir})
    network_args=$(for n in $nics; do echo "--nic $n"; done)

    add_args=$(additional_runner_args)

    echo "PYTHONPATH=$PYTHONPATH"
    eval ${KSTESTDIR}/scripts/kstest-runner ${kargs} \
                       --iso "${tmpdir}/$(basename ${IMAGE})" \
                       ${ks_args} \
                       ${add_args} \
                       --tmp ${tmpdir} \
                       --logfile ${tmpdir}/livemedia.log \
                       --ram 2048 \
                       --vnc vnc \
                       --timeout 60 \
                       ${disk_args} \
                       ${network_args}
    cp ${tmpdir}/virt-install.log ${tmpdir}/virt-install-human.log
    sed -i 's/#012/\n/g' ${tmpdir}/virt-install-human.log
    echo

    RESULT=""
    RET_CODE=0
    if [[ -f ${tmpdir}/virt-install.log ]]; then
        # Ignore rsyslogd CRIT error, this doesn't block the installation
        if [[ "$(grep -e 'CRIT systemd-coredump:[^\n]*rsyslogd' ${tmpdir}/virt-install.log)" != "" ]]; then
            echo "CRIT error in test:$(grep CRIT ${tmpdir}/virt-install.log \
                  | sed 's/#012/\n/g')"
        # Anaconda CRIT error blocking the installation
        elif [[ "$(grep CRIT ${tmpdir}/virt-install.log)" != "" ]]; then
            RESULT="FAILED:$(grep CRIT ${tmpdir}/virt-install.log | sed 's/#012/\n/g')"
            RET_CODE=1
        fi

        if [[ ${RET_CODE} -eq 0 ]]; then
            # TIME OUT error
            if [[ "$(grep 'due to timeout' ${tmpdir}/livemedia.log)" != "" ]]; then
                RESULT="FAILED:Test timed out."
                RET_CODE=2
            # Kernel Call Trace error
            elif [[ "$(grep 'Call Trace' ${tmpdir}/livemedia.log)" != "" ]]; then
                RESULT="FAILED:Kernel panic."
                RET_CODE=0
            fi
        fi
    fi

    if [[ -z "${RESULT}" ]]; then
        ret=$(validate ${tmpdir})
        if [[ $? != 0 ]]; then
            RESULT="FAILED:${ret}"
            RET_CODE=1
        fi
    fi

    if [[ -z "${RESULT}" ]]; then
        RESULT="SUCCESS"
    fi

    echo RESULT:${name}:${RESULT}
    cleanup ${tmpdir}
    cleanup_tmp ${tmpdir}
    return ${RET_CODE}
}

# Have to be root to run this test, as it requires creating disk images.
if [[ ${EUID} != 0 ]]; then
    echo "You must be root to run this test."
    exit 77
fi

while getopts ":i:k:u:b:" opt; do
    case $opt in
        i)
            IMAGE=$OPTARG
            ;;
        k)
            KEEPIT=$OPTARG
            ;;
        u)
            UPDATES=$OPTARG
            ;;
        b)
            BOOT_ARGS=$OPTARG
            ;;
        *)
            echo "Usage: run_one_ks.sh -i ISO [-k KEEPIT] [-u UPDATES_IMG] [-b ADDITIONAL_BOOT_OPTIONS] ks-test.sh"
            exit 1
            ;;
    esac
done

shift $((OPTIND - 1))

if [[ ! -e "${IMAGE}" ]]; then
    echo "Required boot.iso does not exist."
    exit 77
fi

if [[ $# == 0 || ! -x $1 ]]; then
    echo "Test not provided or is not executable."
    exit 1
fi

runone $1
