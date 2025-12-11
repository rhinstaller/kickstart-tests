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
    'centos10': 'centos10',
    'fedora-eln': 'fedora-eln',
}

OS_VARIANT_TO_SKIPPED = {
    'daily-iso': 'SKIPPED_TESTTYPES_DAILY_ISO',
    'rawhide': 'SKIPPED_TESTTYPES_RAWHIDE',
    'rhel8': 'SKIPPED_TESTTYPES_RHEL8',
    'rhel9': 'SKIPPED_TESTTYPES_RHEL9',
    'rhel10': 'SKIPPED_TESTTYPES_RHEL10',
    'centos10': 'SKIPPED_TESTTYPES_CENTOS10',
    'fedora-eln': 'SKIPPED_TESTTYPES_FEDORA_ELN',
}

OS_VARIANT_TO_DISABLED = {
    'daily-iso': 'DISABLED_TESTTYPES_DAILY_ISO',
    'rawhide': 'DISABLED_TESTTYPES_RAWHIDE',
    'rhel8': 'DISABLED_TESTTYPES_RHEL8',
    'rhel9': 'DISABLED_TESTTYPES_RHEL9',
    'rhel10': 'DISABLED_TESTTYPES_RHEL10',
    'centos10': 'DISABLED_TESTTYPES_CENTOS10',
    'fedora-eln': 'DISABLED_TESTTYPES_FEDORA_ELN',
}

RE_MASTER = re.compile('^main$')
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
    disabled_testtypes = []

    if RE_MASTER.match(branch):
        platform = "fedora_rawhide"
        os_variant = "rawhide"
    elif RE_FEDORA.match(branch):
        platform = "fedora_rawhide"
        os_variant = "rawhide"
    elif RE_RHEL8.match(branch):
        platform = "rhel8"
        os_variant = "rhel8"
    elif RE_RHEL9.match(branch):
        platform = "rhel9"
        os_variant = "rhel9"
    elif RE_RHEL10.match(branch):
        platform = "rhel10"
        os_variant = "rhel10"
    else:
        platform = None
        os_variant = None

    if platform:
        skip_testtypes = get_skip_testtypes(skip_file, OS_VARIANT_TO_SKIPPED[os_variant])
        disabled_testtypes = get_skip_testtypes(skip_file, OS_VARIANT_TO_DISABLED[os_variant])

    return (platform, skip_testtypes, disabled_testtypes)


def parse_args():
    _parser = argparse.ArgumentParser(
        description="Generate kickstart tests launch script arguments for given os variant or git branch. "
    )
    _parser.add_argument("--skip-testtypes", "-s", type=str, metavar="TYPE[,TYPE..]",
                         help="skip tests with TYPE (tag)")
    _parser.add_argument("--testtype", "-t", type=str, metavar="TYPE",
                         help="only run tests with TYPE (tag)")
    _parser.add_argument("--testtypes", "-T", type=str, metavar="TYPE[,TYPE..]",
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
    _parser.add_argument("--anaconda-pr", "-p", action="store_true",
                         help="skip tests not working on anaconda PR")
    _parser.add_argument("--disabled", "-d", action="store_true",
                         help="run disabled tests")
    return _parser.parse_args()


if __name__ == "__main__":

    args = parse_args()

    skip_file = args.skip_file or SKIP_FILE

    launch_args = []
    platform_args = []
    testtype_args = []
    skip_testtypes_args = []
    testtypes_args = []

    platform = None
    skipped_testtypes = []
    disabled_testtypes = []
    if args.os_variant:
        platform = OS_VARIANT_TO_PLATFORM[args.os_variant]
        skipped_testtypes = get_skip_testtypes(skip_file, OS_VARIANT_TO_SKIPPED[args.os_variant])
        disabled_testtypes = get_skip_testtypes(skip_file, OS_VARIANT_TO_DISABLED[args.os_variant])
    elif args.branch:
        platform, skipped_testtypes, disabled_testtypes = get_arguments_for_branch(args.branch, skip_file)
        if not platform:
            raise ValueError("Platform for branch {} is not defined".format(args.branch))

    if args.anaconda_pr:
        skipped_testtypes.extend(get_skip_testtypes(skip_file, "SKIPPED_TESTTYPES_ANACONDA_PR"))

    if platform:
        platform_args = ["--platform", platform]

    if args.testtype:
        testtype_args = ["--testtype", args.testtype]

    testtypes = disabled_testtypes if args.disabled else []
    if args.testtypes:
        testtypes.extend(args.testtypes.split(','))
    if testtypes:
        testtypes_args = ["--testtypes", ",".join(testtypes)]

    skip_testtypes = skipped_testtypes
    if not args.disabled:
        skip_testtypes.extend(disabled_testtypes)
    if args.force:
        skip_testtypes = []
    if args.skip_testtypes:
        skip_testtypes.extend(args.skip_testtypes.split(','))
    if skip_testtypes:
        skip_testtypes_args = ["--skip-testtypes", ",".join(skip_testtypes)]

    launch_args = platform_args + skip_testtypes_args + testtype_args + args.tests + testtypes_args

    print(
        " ".join(launch_args)
    )
