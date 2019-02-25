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

import os
from abc import ABC, abstractmethod
from argparse import ArgumentParser, RawDescriptionHelpFormatter

from lib.conf.configuration import RunnerConfiguration, KeepLevel, GlobalConfiguration


class BaseParser(ABC):

    def __init__(self, parser_description):
        """Base configuration for parser implementing common options"""
        self._parser = ArgumentParser(description=parser_description,
                                      formatter_class=RawDescriptionHelpFormatter)
        self._configure_parser()
        self._add_dry_run()

    @abstractmethod
    def _configure_parser(self):
        pass

    @abstractmethod
    def get_configuration(self):
        """Return configuration object based on BaseConfiguration"""
        pass

    def _add_dry_run(self):
        self._parser.add_argument("--dry-run", default=False, action="store_true",
                                  dest="dry_run",
                                  help="prepare everything for the run but do not start the VM")

    def _parse_args(self):
        ns = self._parser.parse_args()

        if ns.dry_run:
            GlobalConfiguration.set_dry_run(ns.dry_run)

        return ns


class RunnerParser(BaseParser):
    """Parse arguments for the run_one_test script and return back RunnerConfiguration."""

    def __init__(self):
        super().__init__("""
        Run one kickstart test.

        This should be run in parallel by main script. It is not supposed to be invoked manually.
        """)

    def _configure_parser(self):
        self._parser.add_argument("kickstart_test", metavar="KS test controller",
                                  type=str, help="Kickstart test to run")
        self._parser.add_argument("-i", metavar="Image path", type=str, required=True,
                                  dest="image", help="Image used to run specified kickstart test")
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
        self._parser.add_argument("--append-host-id", default=False, action="store_true",
                                  dest="append_host_id",
                                  help="append an id of the host running the test to the result")

    def get_configuration(self):
        """Parse arguments and return configuration object.

        :returns: RunnerConfiguration object.
        """
        ns = self._parse_args()
        conf = RunnerConfiguration()

        conf.shell_test_path = os.path.abspath(ns.kickstart_test)
        conf.boot_image_path = os.path.abspath(ns.image)

        base_path = os.path.splitext(conf.shell_test_path)[0]
        conf.ks_test_path = "{}{}".format(base_path, ".ks")

        conf.ks_test_name = os.path.basename(base_path)

        if ns.keep is not None:
            conf.keep_level = KeepLevel(ns.keep)
        else:
            conf.keep_level = KeepLevel.NOTHING

        if ns.updates_path:
            conf.updates_img_path = ns.updates_path

        if ns.append_host_id:
            conf.append_host_id = ns.append_host_id

        self._check_arguments(conf)

        return conf

    @staticmethod
    def _check_arguments(conf):
        if not os.path.exists(conf.shell_test_path):
            raise IOError("Kickstart test shell file '{}' does not exists!".format(
                conf.shell_test_path))

        if not os.path.exists(conf.ks_test_path):
            raise IOError("Kickstart file '{}' does not exists!".format(conf.ks_test_path))

        if not os.path.exists(conf.boot_image_path):
            raise IOError("Boot iso file '{}' does not exists!".format(conf.boot_image_path))
