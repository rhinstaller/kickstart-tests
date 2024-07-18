#!/bin/bash
#
# Copyright (C) 2018  Red Hat, Inc.
# # This copyrighted material is made available to anyone wishing to use,
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
#
# This script only works as a gate for the kickstart test sh files.
# Functions from the sh file will be called by this script which will be
# controlled by the python.

while getopts ":i:k:u:w:t:" opt; do
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
        w)
            tmpdir=$OPTARG
            ;;
        t)
            t=$OPTARG
            ;;
        *)
            echo "Usage: run_one_ks.sh -i ISO -k KEEPIT -w WORK_DIR -t ks-test.sh [-u UPDATES] function"
            echo ""
            echo "The function argument will be called from the kickstart test shell script."
            exit 1
            ;;
    esac
done

shift $((OPTIND - 1))

if [[ ! -e "${IMAGE}" ]]; then
    echo "Missing boot image required argument." >&2
    exit 2
fi

if [[ -z "${KEEPIT}" ]]; then
    echo "Missing keepit required argument." >&2
    exit 2
fi

if [[ ! -d "${tmpdir}" ]]; then
    echo "Missing work_dir required argument." >&2
    exit 2
fi

if [[ ! -e "${t}" ]]; then
    echo "Missing shell test file required argument." >&2
    exit 2
fi

if [[ $# -ne 1 || -z $1 ]]; then
    echo "Function not provided!" >&2
    exit 1
fi

export KSTESTDIR="$(pwd)"

ks=${t/.sh/.ks}
. $t

name="$(basename ${t%.sh})"
ret=0
msg=""

case $1 in
    cleanup)
        cleanup ${tmpdir}
        ret=$?
        ;;
    inject_ks_to_initrd)
        msg="$(inject_ks_to_initrd)"
        ret=$?
        ;;
    enable_uefi)
        msg="$(enable_uefi)"
        ret=$?
        ;;
    stage2_from_ks)
        msg="$(stage2_from_ks)"
        ret=$?
        ;;
    prepare)
        msg="$(prepare ${ks} ${tmpdir})"
        ret=$?
        ;;
    prepare_updates)
        msg="$(prepare_updates ${tmpdir})"
        ret=$?
        ;;
    prepare_disks)
        msg="$(prepare_disks ${tmpdir})"
        ret=$?
        ;;
    prepare_network)
        msg="$(prepare_network ${tmpdir})"
        ret=$?
        ;;
    kernel_args)
        msg="$(kernel_args ${tmpdir})"
        ret=$?
        ;;
    boot_args)
        msg="$(boot_args)"
        ret=$?
        ;;
    additional_runner_args)
        msg="$(additional_runner_args)"
        ret=$?
        ;;
    get_timeout)
        msg="$(get_timeout)"
        ret=$?
        ;;
    get_required_ram)
        msg="$(get_required_ram)"
        ret=$?
        ;;
    validate)
        msg="$(validate ${tmpdir})"
        ret=$?
        ;;
    *)
        echo "Bad function name \'$1\' !"
        exit 3
        ;;
esac

echo "${msg}"
exit ${ret}
