#!/usr/bin/python3
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
# Red Hat Author(s): Jiri Konecny <jkonecny@redhat.com>
#

import sys
import argparse

from test_manager.collector import TestCollector
from test_manager.configurator import TestConfigurator


class ArgumentParser(object):

    def __init__(self):
        super().__init__()
        self._parser = argparse.ArgumentParser(description="""
        Find tests and prepare them for running.
        """)

        self._tests = ()
        self._root_dir = ""
        self._test_group = ""

        self._configure_parser()

    @property
    def tests(self):
        return self._tests

    @property
    def root_directory(self):
        return self._root_dir

    @property
    def test_group(self):
        return self._test_group

    def _configure_parser(self):
        self._parser.add_argument("--root", "-r", required=False, type=str, default=".",
                                  help="""Set root directory of the tests. This will be used
                                  when looking for all existing tests or group of tests.""")
        self._parser.add_argument("--group", "-g", required=False, type=str, default="",
                                  help="""Specify test type, only tests with this type will be
                                  used.""")
        self._parser.add_argument("tests", type=str, nargs='*', default=(),
                                  metavar="/path/to/test1.ks.in /path/to/test2.ks.in ...",
                                  help="""Specify path to kickstart tests. 
                                  If not specified all tests will be used.""")

    def parse(self):
        ns = self._parser.parse_args()

        self._root_dir = ns.root
        self._tests = ns.tests
        self._test_group = ns.group


if __name__ == "__main__":
    parser = ArgumentParser()
    parser.parse()

    collector = TestCollector()
    tests = []
    if parser.tests:
        tests = collector.find_by_paths(parser.tests)
    elif parser.test_group:
        tests = collector.find_by_group(parser.root_directory, parser.test_group)
    else:
        tests = collector.find_all(parser.root_directory)

    if not tests:
        print("No tests found!", file=sys.stderr)
        exit(1)

    configurator = TestConfigurator(parser.root_directory)
    configurator.load_configuration()

    if parser.tests:
        configurator.process_known_failure = True

    configurator.run(tests)

    for t in tests:
        if not t.valid:
            print(t.error_message)
            continue
        else:
            print("Writing {} as {}".format(t.name, t.target_path))

        with open(t.target_path, 'w') as f:
            f.write(t.content)
