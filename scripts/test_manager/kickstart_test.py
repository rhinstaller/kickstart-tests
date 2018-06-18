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


class KickstartTest(object):

    def __init__(self, path):
        """Create test object.

        This object will hold all important information about test.

        :param path: Path to the test.
        :type path: str
        """
        super().__init__()
        self._path = path
        self._name = os.path.basename(path)
        self._content = ""

    def __repr__(self):
        return "<test_manager.KickstartTest path: {}>".format(self._path)

    @property
    def path(self):
        return self._path

    @property
    def target_path(self):
        return os.path.splitext(self.path)[0]

    @property
    def dir(self):
        return os.path.dirname(self._path)

    @property
    def name(self):
        return self._name

    @property
    def content(self):
        return self._content

    @content.setter
    def content(self, value):
        self._content = value

    def load_content(self):
        with open(self._path, "r") as f:
            self._content = f.read()
