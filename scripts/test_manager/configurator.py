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

import re
import os

from configparser import ConfigParser
from test_manager.errors import IncludeFileMissingError

GLOBAL_SECTION = "GLOBAL"


class TestConfigurator(object):

    def __init__(self, root_dir):
        """Collect all information about test environment and prepare test based on this.

        :param root_dir: Root directory of the tests.
        :type root_dir: str
        """
        super().__init__()
        self._config_loader = ConfigLoader()

        self._re_checker = re.compile(r'@.*@')
        self._root = root_dir
        self._re_ks_include = re.compile(r'@KSINCLUDE@\s+([^\s]*)')

    def load(self):
        """Load configuration from the configuration file"""
        self._config_loader.load_default_config()

    def prepare_tests(self, tests):
        """Prepare multiple tests by the loaded configuration.

        This will effectively only call self.prepare_test on all files.

        Result will be saved in the KickstartTest instance content.
        """
        for t in tests:
            self.prepare_test(t)

    def prepare_test(self, test):
        """Prepare test based on the configuration loaded.

        .. NOTE: You must load configuration before calling this method!

        Result will be stored in the KickstartTest object.

        :param test: Kickstart test object for processing.
        :type test: testmanager.kickstart_test.KickstartTest
        """
        self._do_substitutions(test)

    def _do_substitutions(self, test):
        substitutions = self._config_loader.substitutions()
        test.load_content()

        for key in substitutions.keys():
            pattern = r"@{}@".format(key.upper())
            test.content = re.sub(pattern, substitutions[key], test.content)

        try:
            test.content = self._include_kickstart_parts(test.content)
        except IncludeFileMissingError as ex:
            raise IncludeFileMissingError(str(ex) + " {}".format(test.name))

    def _include_kickstart_parts(self, content):
        match = self._re_ks_include.search(content)

        if not match:
            return content

        include_content = self._load_file_content(match[1])
        return self._re_ks_include.sub(include_content, content)

    def _load_file_content(self, file):
        file_path = os.path.join(self._root, file)

        if not os.path.exists(file_path):
            raise IncludeFileMissingError("KSINCLUDE file {} missing in test".format(file_path))

        with open(file_path, "rt") as f:
            res = f.read()

        return res

    def check_test(self, test):
        """Check if given test is prepared for use.

        :param test: Kickstart test object for processing.
        :type test: testmanager.kickstart_test.KickstartTest
        """
        if self._re_checker.search(test.content):
            return False
        else:
            return True


class ConfigLoader(ConfigParser):

    def __init__(self, config_path="~/.kstests-defaults.conf"):
        super().__init__()
        self._parser = ConfigParser()
        self._config_path = os.path.expanduser(config_path)

    def load_default_config(self):
        if not os.path.exists(self._config_path):
            raise ValueError("Configuration file {} doesn't exists!".format(self._config_path))

        with open(self._config_path, 'r') as f:
            self._parser.read_file(f)

    def substitutions(self):
        if self._parser.has_section(GLOBAL_SECTION):
            return self._parser[GLOBAL_SECTION]
