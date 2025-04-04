#!/usr/bin/python3

import argparse
import itertools


def parse_args():
    _parser = argparse.ArgumentParser(
        description="Generate tplib testcase query from kickstart tests launcher "
                    "options --skip-testtypes, --testtype and a list of tests."
    )
    _parser.add_argument("--skip-testtypes", "-s", type=str, metavar="TYPE[,TYPE..]",
                         nargs=1, action="append", help="skip tests with TYPE (tag)")
    _parser.add_argument("--testtype", "-t", type=str, metavar="TYPE",
                         help="only run tests with TYPE (tag)")
    _parser.add_argument("--platform", "-p", type=str, metavar="PLATFORM", default="",
                         help="platform to be used for tests")
    _parser.add_argument("--print-platform", action="store_true",
                         help="print the platform option")
    _parser.add_argument("tests", nargs='*', metavar="TESTNAME",
                         help="names of test to be run")
    return _parser.parse_args()


if __name__ == "__main__":

    args = parse_args()

    if args.print_platform:
        if args.platform:
            print(args.platform)
            exit()
        else:
            exit(1)

    conditions = []
    if args.tests:
        conditions = [
            "("
            + " or ".join(['tc.name == "{}"'.format(test) for test in args.tests])
            + ")"
        ]
        if args.skip_testtypes:
            skiptypes = ','.join(itertools.chain(*args.skip_testtypes)).split(',')
            conditions.extend(['"{}" not in tc.tags'.format(skiptype) for skiptype in skiptypes])
    else:
        if args.testtype:
            conditions.extend(['"{}" in tc.tags'.format(args.testtype), '"knownfailure" not in tc.tags'])
        if args.skip_testtypes:
            skiptypes = ','.join(itertools.chain(*args.skip_testtypes)).split(',')
            conditions.extend(['"{}" not in tc.tags'.format(skiptype) for skiptype in skiptypes])

    if not conditions:
        query = "True"
    else:
        query = " and ".join(conditions)

    print(query)
