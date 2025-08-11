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

import os
from glob import iglob

from test_manager.kickstart_test import KickstartTest
from test_manager.errors import KickstartTestPathError


class TestCollector(object):

    @classmethod
    def find_all(cls, root):
        """Find all scripts in the root directory.

        :param root: Root directory of tests.
        :type root: str

        :returns: Test object with path to the test.
        :rtype: Test instance
        """
        tests = cls._find_all(root)
        result = set()

        for t in tests:
            result.add(t)

        return result

    @classmethod
    def find_by_group(cls, root, group):
        """Find all tests belonging to a test group specified by group parameter.

        :param root: Root directory of tests.
        :type root: str

        :param group: Group of tests you are looking for.
        :type group: str

        :returns: Test object with path to the test.
        :rtype: Test instance
        """
        result = set()
        tests = cls._find_all(root)

        for t in tests:
            if group in t.metadata.groups:
                result.add(t)

        return result

    @classmethod
    def _find_all(cls, root):
        ret = set()
        find_pattern = os.path.join(root, "tests", "*.ks.in")
        for f in iglob(find_pattern):
            ret.add(KickstartTest(f))

        return ret

    @classmethod
    def find_by_paths(cls, test_paths):
        """Find tests by paths.

        Paths must point to a source kickstart file with extension .ks.in .

        :param test_paths: Test paths for processing.
        :type test_paths: Array of paths pointing to the tests.

        :returns: Test object with path to the test.
        :rtype: Test instance
        """
        ret = set()

        for t in test_paths:
            if not os.path.exists(t):
                raise KickstartTestPathError("Test path {} doesn't exists!".format(t))
            if ".ks.in" not in t[-6:]:
                raise KickstartTestPathError("Test file {} must have suffix .ks.in".format(t))
            ret.add(KickstartTest(t))

        return ret
