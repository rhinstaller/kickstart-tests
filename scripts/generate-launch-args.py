#!/usr/bin/python3

import argparse
import shlex
import subprocess
import re
import os

OS_VARIANT_TO_PLATFORM = {
    'daily-iso': 'fedora_rawhide',
    'rawhide': 'fedora_rawhide',
    'rhel8': 'rhel8',
    'rhel9': 'rhel9',
    'rhel10': 'rhel10',
}

OS_VARIANT_TO_DISABLED = {
    'daily-iso': 'SKIP_TESTTYPES_DAILY_ISO',
    'rawhide': 'SKIP_TESTTYPES_RAWHIDE',
    'rhel8': 'SKIP_TESTTYPES_RHEL8',
    'rhel9': 'SKIP_TESTTYPES_RHEL9',
    'rhel10': 'SKIP_TESTTYPES_RHEL10',
}

RE_MASTER = re.compile('^master$')
RE_FEDORA = re.compile('fedora-[0-9]+$')
RE_RHEL8 = re.compile('rhel-8(.[0-9]+)?$')
RE_RHEL9 = re.compile('rhel-9(.[0-9]+)?$')
RE_RHEL10 = re.compile('rhel-10(.[0-9]+)?$')

SKIP_FILE = "containers/runner/skip-testtypes"


def get_skip_testtypes(skip_file, variable):
    if not os.path.exists(skip_file):
        raise ValueError("Disabled tests file {} not found".format(skip_file))
    command = shlex.split("bash -c 'source {}; echo ${}'".format(skip_file, variable))
    taglist = subprocess.run(command, capture_output=True, check=False, encoding="utf8")
    return taglist.stdout.strip().split(',')


def get_arguments_for_branch(branch, skip_file):
    platform = None
    skip_testtypes = []

    if RE_MASTER.match(branch):
        platform = "fedora_rawhide"
        skipvar = 'SKIP_TESTTYPES_RAWHIDE'
    elif RE_FEDORA.match(branch):
        platform = "fedora_rawhide"
        skipvar = 'SKIP_TESTTYPES_RAWHIDE'
    elif RE_RHEL8.match(branch):
        platform = "rhel8"
        skipvar = 'SKIP_TESTTYPES_RHEL8'
    elif RE_RHEL9.match(branch):
        platform = "rhel9"
        skipvar = 'SKIP_TESTTYPES_RHEL9'
    elif RE_RHEL10.match(branch):
        platform = "rhel10"
        skipvar = 'SKIP_TESTTYPES_RHEL10'
    else:
        platform = None
        skipvar = None

    if skipvar:
        skip_testtypes = get_skip_testtypes(skip_file, skipvar)

    return (platform, skip_testtypes)


def parse_args():
    _parser = argparse.ArgumentParser(
        description="Generate kickstart tests launch script arguments for given os variant or git branch. "
                    "Determines the platform and updates the skipped tests."
    )
    _parser.add_argument("--skip-testtypes", "-s", type=str, metavar="TYPE[,TYPE..]",
                         help="skip tests with TYPE (tag)")
    _parser.add_argument("--testtype", "-t", type=str, metavar="TYPE",
                         help="only run tests with TYPE (tag)")
    _parser.add_argument("tests", nargs='*', metavar="TESTNAME",
                         help="names of test to be run")
    group = _parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--branch", "-b", type=str, metavar="GIT-BRANCH",
                       help="Anaconda git branch (for example rhel-10)")
    group.add_argument("--os-variant", "-r", type=str, metavar="OS_VARIANT",
                       help="os variant of the boot.iso to be tested (for example rhel9)")
    _parser.add_argument("--force", "-f", action="store_true",
                         help="do not skip any tests based on os variant or branch")
    _parser.add_argument("--skip-file", type=str, metavar="PATH",
                         help="file containing data about disabled tests")
    return _parser.parse_args()


if __name__ == "__main__":

    args = parse_args()

    skip_file = args.skip_file or SKIP_FILE

    launch_args = []
    platform_args = []
    testtype_args = []
    skip_testtypes_args = []

    platform = None
    disabled_testtypes = []
    if args.os_variant:
        platform = OS_VARIANT_TO_PLATFORM[args.os_variant]
        disabled_testtypes = get_skip_testtypes(skip_file, OS_VARIANT_TO_DISABLED[args.os_variant])
    elif args.branch:
        platform, disabled_testtypes = get_arguments_for_branch(args.branch, skip_file)
        if not platform:
            raise ValueError("Platform for branch {} is not defined".format(args.branch))

    if platform:
        platform_args = ["--platform", platform]

    if args.testtype:
        testtype_args = ["--testtype", args.testtype]

    skip_testtypes = [] if args.force else disabled_testtypes
    if args.skip_testtypes:
        skip_testtypes.extend(args.skip_testtypes.split(','))
    if skip_testtypes:
        skip_testtypes_args = ["--skip-testtypes", ",".join(skip_testtypes)]

    launch_args = platform_args + skip_testtypes_args + testtype_args + args.tests

    print(
        " ".join(launch_args)
    )
