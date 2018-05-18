#!/usr/bin/python3

#
# Copyright (C) 2018  Red Hat, Inc.
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

# This script runs a single kickstart test on a single system.  It takes
# command line arguments instead of environment variables because it is
# designed to be driven by run_kickstart_tests.sh via parallel.  It is
# not for direct use.

# Possible return values:
# 0  - Everything worked
# 1  - Test failed for unspecified reasons
# 2  - Test failed due to time out
# 3  - Test failed due to kernel panic
# 77 - Something needed by the test doesn't exist, so skip

from argparse import ArgumentParser, RawDescriptionHelpFormatter
from enum import Enum

import os


class KeepLevel(Enum):
    NOTHING = 0
    LOGS_ONLY = 1
    EVERYTHING = 2


class RunnerConfiguration(object):

    def __init__(self):
        super().__init__()

        self._parser = ArgumentParser(description="""
        Run one kickstart test.

        This should be run in parallel by main script. It is not supposed to be invoked manually.
        """, formatter_class=RawDescriptionHelpFormatter)
        self._confiure_parser()

        self._sh_path = ""
        self._ks_path = ""
        self._image_path = ""
        self._keep_option = KeepLevel.NOTHING
        self._updates_img_path = ""

    def _confiure_parser(self):
        self._parser.add_argument("kickstart_test", metavar="KS test controller",
                                  type=str, help="Kickstart test to run")
        self._parser.add_argument("image", metavar="Image path", type=str,
                                  help="Image used to run specified kickstart test")
        self._parser.add_argument("--keep", '-k', metavar="0,1,2", type=int,
                                  dest="keep", help="""
                                  Set the level of what should be kept after a test

                                  Valid potions:
                                  0 - Remove everything
                                  1 - Remove disk image and kickstart test
                                  2 - Keep everything
                                  """)
        self._parser.add_argument("--updates", '-u', metavar="Path",
                                  type=str, dest="updates_path",
                                  help="Updates image path used in the test")

    @property
    def shell_test_path(self):
        return self._sh_path

    @property
    def ks_test_path(self):
        return self._ks_path

    @property
    def boot_image(self):
        return self._image_path

    @property
    def keep_level(self):
        return self._keep_option

    @property
    def update_img_path(self):
        return self._updates_img_path

    def process_argument(self):
        ns = self._parser.parse_args()

        self._sh_path = ns.kickstart_test
        self._image_path = ns.image

        base_name = os.path.splitext(self._sh_path)[0]
        self._ks_path = "{}{}".format(base_name, ".ks")

        if ns.keep and ns.keep not in [0, 1, 2]:
            raise ValueError("keep parameter can contain only numbers: 0, 1 or 2 !")
        elif ns.keep is not None:
            self._keep_option = KeepLevel(ns.keep)

        if ns.updates_path:
            self._updates_img_path = ns.updates_path

        self._check_arguments()

    def _check_arguments(self):
        if not os.path.exists(self._sh_path):
            raise IOError("Kickstart test shell file '{}' does not exists!".format(self._sh_path))
        elif not os.path.exists(self._ks_path):
            raise IOError("Kickstart file '{}' does not exists!".format(self._ks_path))
        elif not os.path.exists(self._image_path):
            raise IOError("Boot iso file '{}' does not exists!".format(self._image_path))
        elif self._updates_img_path and not os.path.exists(self._updates_img_path):
            raise IOError("Updates image '{}' does not exists!".format(self._updates_img_path))


if __name__ == '__main__':
    configuration = RunnerConfiguration()

    configuration.process_argument()
