#!/usr/bin/python3

import argparse
import itertools


def parse_args():
    _parser = argparse.ArgumentParser(
        description="Generate tclib testcase query from kickstart tests launcher "
                    "options --skip-testtypes, --testtype and a list of tests."
    )
    _parser.add_argument("--skip-testtypes", "-s", type=str, metavar="TYPE[,TYPE..]",
                         nargs=1, action="append", help="skip tests with TYPE (tag)")
    _parser.add_argument("--testtype", "-t", type=str, metavar="TYPE",
                         help="only run tests with TYPE (tag)")
    _parser.add_argument("tests", nargs='*', metavar="TESTNAME",
                         help="names of test to be run")
    return _parser.parse_args()


if __name__ == "__main__":

    args = parse_args()

    conditions = []
    if args.tests:
        conditions = [
            "("
            + " or ".join(['tc.name == "{}"'.format(test) for test in args.tests])
            + ")"
        ]
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
