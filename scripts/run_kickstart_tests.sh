#!/bin/bash
#
# Copyright (C) 2014, 2015  Red Hat, Inc.
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

# This script runs the entire kickstart_tests suite.  It is an interface
# between "make check" (which is why it takes environment variables instead
# of arguments) and livemedia-creator.  Each test consists of a kickstart
# file that specifies most everything about the installation, and a shell
# script that does validation and specifies kernel boot parameters.  lmc
# then fires up a VM and watches for tracebacks or stuck installs.
#
# A boot ISO is required, which should be specified with TEST_BOOT_ISO=.
#
# The number of jobs corresponds to the number of VMs that will be started
# simultaneously.  Each one wants about 1 GB of memory.  The default is
# four simultaneous jobs, but you can control this with TEST_JOBS=.  It is
# suggested you not run out of memory.
#
# You can control what logs are held onto after the test is complete via the
# KEEPIT= variable, explained below.  By default, nothing is kept.
#
# Finally, you can run tests across multiple computers at the same time by
# putting all the hostnames into TEST_REMOTES= as a space separated list.
# Do not add localhost manually, as it will always be added for you.  You
# must create a user named kstest on each remote system, allow that user to
# sudo to root for purposes of running livemedia-creator, and have ssh keys
# set up so that the user running this script can login to the remote systems
# as kstest without a password.  TEST_JOBS= applies on a per-system basis.
# KEEPIT= controls how much will be kept on the master system (where "make
# check" is run).  All results will be removed from the slave systems.

# The boot.iso location can come from one of two different places:
# (1) $TEST_BOOT_ISO, if this script is being called from "make check"
# (2) The command line, if this script is being called directly.  That will
#     be checked below.
IMAGE="${TEST_BOOT_ISO}"

# Possible values for this parameter:
# 0 - Keep nothing (the default)
# 1 - Keep log files
# 2 - Keep log files and disk images (will take up a lot of space)
KEEPIT=${KEEPIT:-0}

# Link to a server where an updates image is stored. Use on your own
# responsibility, this can break tests.
UPDATES_IMG=""

TESTTYPE=""

while getopts ":i:k:t:u:" opt; do
    case $opt in
       i)
           # If this wasn't set from the environment, set it from the command line
           # here.  If it never gets set, we'll catch that later and error out.
           IMAGE=$OPTARG
           ;;

       k)
           # This overrides either the $KEEPIT environment variable, or the default
           # setting from above.
           KEEPIT=$OPTARG
           ;;

       t)
           # Only run tests that have TESTTYPE=<this value> in them.  Tests can have
           # more than one type.  We'll do a pretty stupid test for it.
           TESTTYPE=$OPTARG
           ;;
       u)
           # Link to an updates image on a server. This will be added as a kernel
           # parameter inst.updates=<server> to the VM boot options.
           # This may not be compatible with all the tests.
           UPDATES_IMG=$OPTARG
           ;;
       *)
           echo "Usage: run_kickstart_tests.sh [-i boot.iso] [-k 0|1|2] [-u link_to_updates.img] [tests]"
           exit 1
           ;;
    esac
done

if [[ ! -e "${IMAGE}" ]]; then
    echo "Required boot.iso does not exist; skipping."
    exit 77
fi

# Check for required programs and exit if missing.
for p in livemedia-creator parallel scp; do
    hash ${p} 2>/dev/null || { echo "Required program ${p} missing; aborting." ; exit 1; }
done

shift $((OPTIND - 1))

# Get default settings from a couple different places - under the source
# directory for settings that are potentially useful to everyone, and then
# in the user's home directory for settings that are site-specific and thus
# can't be put into source control.
if [[ -e scripts/defaults.sh ]]; then
    . scripts/defaults.sh
fi

if [[ -e $HOME/.kstests.defaults.sh ]]; then
    . $HOME/.kstests.defaults.sh
fi

# Grab useful data from boot.iso
output="$(sudo ./scripts/probe_boot_iso.sh $IMAGE)"
if [[ $? -ne 0 ]]; then
    echo "Can't run probe_boot_iso" >&2
    exit 3
fi
ISO_OS_NAME=$(echo "${output}" | grep 'NAME=')
ISO_OS_NAME="${ISO_OS_NAME##NAME=}"
ISO_OS_VERSION=$(echo "${output}" | grep 'VERSION=')
ISO_OS_VERSION="${ISO_OS_VERSION##VERSION=}"


# Append sed args to substitute
sed_args=" -e s#@KSTEST_OS_NAME@#${ISO_OS_NAME}# -e s#@KSTEST_OS_VERSION@#${ISO_OS_VERSION}#"

# Build up a list of substitutions to perform on kickstart files.
sed_args+=$(printenv | while read line; do
    key="$(echo $line | cut -d'=' -f1)"
    val="$(echo $line | cut -d'=' -f2-)"

    [[ "${key}" =~ ^KSTEST_ ]] && echo -n " -e s#@${key}@#${val}#"
 done)

# Find all tests in the . folder. These tests will be filtered by TESTTYPE parameter
# if specified.
function find_tests() {
    local tests=$(find . -maxdepth 1 -name '*sh' -a -perm -o+x)

    local newtests=""
    for f in ${tests}; do
        if [[ "$TESTTYPE" != "" && "$(grep TESTTYPE= ${f})" =~ "${TESTTYPE}" ]]; then
            newtests+="${f} "
        elif [[ "$TESTTYPE" == "" && ! "$(grep TESTTYPE= ${f})" =~ knownfailure ]]; then
            # Skip any test with the type "knownfailure".  If you want to run these (to
            # see if they are still failing, for instance) you can add "-t knownfailure"
            # on the command line.
            newtests+="${f} "
        else
            continue
        fi
    done

    echo "${newtests}"
}

# We get the list of tests from one of several places:
# (1) From the command line, all the other arguments.
# (2) If ${ghprbActualCommit} is in the environment, the tests changed by
#     that commit.
#     If no tests are changed in commit, run all tests. When TESTTYPE parameter
#     is specified, use this parameter to filter tests.
# (3) By applying any TESTTYPE given on the command line.
# (4) From finding all scripts in . that are executable and are not support
#     files.
if [[ $# != 0 ]]; then
    tests=""

    # Allow people to leave off the .sh.
    for t in $*; do
        if [[ "${t}" == *.sh ]]; then
            tests+="${t} "
        else
            tests+="${t}.sh "
        fi
    done
elif [[ "${ghprbActualCommit}" != "" ]]; then
    files="$(git show --pretty=format: --name-only ${ghprbActualCommit})"
    tests=""

    candidates="$(for f in ${files}; do
        # Only accept files that are .sh or .ks.in files in this top-level directory.
        # Those are the tests.  If either file for a particular test changed, we want
        # to run the test.  The first step of figuring this out is stripping off
        # the file extension.
        if [[ ! "${f}" == */* && ("${f}" == *sh || "${f}" == *ks.in) ]]; then
            echo "${f%%.*} "
        fi
     done | uniq)"

    # And then add the .sh suffix back on to everything in $candidates.  That will
    # give us the list of tests to be run.
    for c in ${candidates}; do

        # Skip files that are not executable.
        if [[ ! -x "${c}.sh" ]]; then
            continue
        fi

        tests+="${c}.sh "
    done

    # Nothing find, find all tests and use TESTTYPE if specified.
    if [ -z "${tests}" ]; then
        tests=$(find_tests)
    fi
else
    # The find_tests function will find all tests and use TESTTYPE if specified.
    tests=$(find_tests)
fi

if [[ "${tests}" == "" ]]; then
    echo "No tests provided; skipping."
    exit 77
fi

if [[ -z "${sed_args}" ]]; then
    echo "No substitutions provided, tests will fail; skipping."
    exit 77
fi

export KSTESTDIR=$(pwd)

# Now do all the substitutions on the kickstart files matching up with one of
# the test cases we are going to run.
for t in ${tests}; do
    ks=${t/.sh/.ks.in}
    sed ${sed_args} ${ks} > ${t/.sh/.ks}
done

# And now, include common stuff with @KSINCLUDE@ <FILE>
# For example libraries for post scripts gathering the result
for t in ${tests}; do
    inclks=${t/.sh/.ks}
    # First normalize the @KSINCLUDE@ lines a bit
    sed -i -e 's/\s*@KSINCLUDE@\s*\(.*\)/@KSINCLUDE@\1/' ${inclks}
    # Include the files
    for iline in $(grep "^@KSINCLUDE@.*" ${inclks}); do
        sfile=${iline:11}
        echo "Including $sfile into ${inclks}"
        sed -i -e '\_'${iline}'_ { r'${sfile} -e 'd }' ${inclks}
    done
done

# collect the prerequisite list for the requested tests. If there is
# anything in the list, build it.

# Run the prereq functions in a subshell so nothing weird gets into the
# environment just yet. Print each item one per line and remove duplicates.
prereq_list=$(
for t in ${tests} ; do
    . ${t}
    for p in $(prereqs) ; do
        echo $p
    done
done | sort | uniq)

if [ -n "$prereq_list" ] ; then
    make IMAGE="${IMAGE}" KSTESTDIR="${KSTESTDIR}" \
        -C scripts -f Makefile.prereqs $prereq_list
fi

# set updates image argument for parallel
UPDATES_ARG=""
if [[ -n "$UPDATES_IMG" ]]; then
    UPDATES_ARG="-u ${UPDATES_IMG}"
fi

if [[ "$TEST_REMOTES" != "" ]]; then
    _IMAGE=$(basename ${IMAGE})

    # (1) Copy everything to the remote systems.  We do this ourselves because
    # parallel doesn't like globs, and we need to put the boot image somewhere
    # that qemu on the remote systems can read.
    for remote in ${TEST_REMOTES}; do
        ssh kstest@${remote} mkdir kickstart-tests
        scp -r . kstest@${remote}:kickstart-tests/
        scp ${IMAGE} kstest@${remote}:kickstart-tests/
    done

    # (1a) We also need to copy the provided image to under kickstart_tests/ on
    # the local system too.  This is because parallel will attempt to run the
    # same command line on every system and that requires the image to also be
    # in the same location.
    cp ${IMAGE} ${_IMAGE}

    # (2) Run parallel.  We always add the local system to the list of machines
    # being passed to parallel.  Don't add it yourself.
    remote_args="--sshlogin :"
    for remote in ${TEST_REMOTES}; do
        remote_args="${remote_args} --sshlogin kstest@${remote}"
    done

    parallel --no-notice ${remote_args} --jobs ${TEST_JOBS:-4} \
             sudo PYTHONPATH=$PYTHONPATH scripts/run_one_ks.sh -i ${_IMAGE} \
                                                               -k ${KEEPIT} \
                                                               ${UPDATES_ARG} {} ::: ${tests}
    rc=$?

    # (3) Get all the results back from the remote systems, which will have already
    # applied the KEEPIT setting.  However if KEEPIT is 0 (meaning, don't save
    # anything) there's no point in trying.  We do this ourselves because, again,
    # parallel doesn't like globs.
    #
    # We also need to clean up the stuff we copied over in step 1, and then clean up
    # the results from the remotes too.  We don't want to keep things scattered all
    # over the place.
    for remote in ${TEST_REMOTES}; do
        if [[ ${KEEPIT} > 0 ]]; then
            scp -r kstest@${remote}:/var/tmp/kstest-\* /var/tmp/
        fi

        ssh kstest@${remote} sudo rm -rf kickstart-tests /var/tmp/kstest-\*
    done

    # (3a) And then also remove the copy of the image we made earlier.
    rm ${_IMAGE}
else
    parallel --no-notice --jobs ${TEST_JOBS:-4} \
        sudo PYTHONPATH=$PYTHONPATH scripts/run_one_ks.sh -i ${IMAGE} \
                                                          -k ${KEEPIT} \
                                                          ${UPDATES_ARG} {} ::: ${tests}
    rc=$?
fi

# Return exit code from above.  This is structure for future improvement,
# you can do a cleaning here.

exit ${rc}
