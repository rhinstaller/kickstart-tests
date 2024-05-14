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

from abc import ABC
from collections import namedtuple

from test_manager.errors import TestManagerError

Filter = namedtuple("Filter", ["name", "func"])


class BaseFilter(ABC):
    """Base class to manage tests.

    This class will handle filters which will be run on the tests and collect errors raised.
    """
    def __init__(self):
        super().__init__()
        self._filters = []

    def add_filter(self, name, func):
        """Add filter to the top of the stack.

        :param name: Name of the filter.
        :type name: str

        :param func: Callable which will be called on every valid test.
        :type func: Any callable with one argument KickstartTest instance.
        """
        self._filters.append(Filter(name, func))

    def get_filter(self, name):
        """Get filter with given name.

        :param name: Name of the filter we are looking for.
        :type name: str

        :returns: Tuple (name, filtering function).
        :rtype: namedtuple(str, callable)
        """
        for f in self._filters:
            if f.name == name:
                return f

        raise KeyError(f"Filter with name: {name} doesn't present")

    def get_filters(self):
        """Return list of all filters."""
        return self._filters

    def remove_filter(self, name):
        """Remove filter by name.

        :param name: Name of the filter we want to remove.
        :type name: str
        """
        f = self.get_filter(name)
        self._filters.remove(f)

    def run(self, tests):
        """Run all filters on every test.

        Save errors to tests if raised.
        """
        for t in tests:

            if not t.valid:
                continue

            try:
                for f in self._filters:
                    f.func(t)
            except TestManagerError as e:
                t.add_error(e)
