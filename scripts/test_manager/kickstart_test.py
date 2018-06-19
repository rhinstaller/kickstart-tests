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

from test_manager.errors import MissingMetadataError, MissingMetadataTestGroupError


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

        self._metadata = TestMetadata(path)

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

    @property
    def metadata(self):
        """Get metadata object instance.

        :returns: TestMetadata instance.
        """
        return self._metadata

    def load_content(self):
        with open(self._path, "r") as f:
            self._content = f.read()


class TestMetadata(object):

    def __init__(self, test_path):
        """Create kickstart test metadata object.

        This object will load metadata and store all the relevant information for the test.

        :param test_path: Path to the test.
        :type test_path: str
        """
        super().__init__()

        metadata_file = self._get_metadata_file_name(test_path)

        if not os.path.exists(metadata_file):
            raise MissingMetadataError("Can't find metadata {} for {}".format(metadata_file,
                                                                              test_path))

        self._path = metadata_file
        self._groups = None

    @staticmethod
    def _get_metadata_file_name(test_path):
        metadata_file = os.path.splitext(test_path)[0]  # remove .in
        metadata_file = os.path.splitext(metadata_file)[0]  # remove .ks
        metadata_file = metadata_file + ".sh"

        return metadata_file

    @property
    def path(self):
        """Get metadata file path.

        :returns: str
        """
        return self._path

    @property
    def name(self):
        """Get name of this metadata file.

        :returns: str
        """
        return os.path.basename(self._path)

    @property
    def groups(self):
        """Get list of groups where this test belongs.

        :returns: [str]
        """
        if self._groups is None:
            self.find_groups()

        return self._groups

    def find_groups(self):
        """Find groups of this test.

        This method will be called automatically with the first call of groups property.
        """
        with open(self._path, 'rt') as f:
            for line in f:
                if "#TESTTYPE=" in line:
                    continue
                elif "TESTTYPE=" in line:
                    groups = line.split("=")[1]
                    groups = groups.strip("'\" \n")
                    self._groups = groups.split(" ")
                    return

        raise MissingMetadataTestGroupError("Missing test group for test {}".format(self.name))
