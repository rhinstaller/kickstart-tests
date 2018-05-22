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
# 99 - Test preparation failed

from argparse import ArgumentParser, RawDescriptionHelpFormatter
from enum import Enum
from contextlib import AbstractContextManager
from tempfile import mkdtemp
from glob import glob

import os
import re
import shutil
import subprocess

SHELL_INTERFACE_PATH = "launcher_interface.sh"


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

        self._ks_test_name = ""
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
    def ks_test_name(self):
        return self._ks_test_name

    @property
    def boot_image(self):
        return self._image_path

    @property
    def keep_level(self):
        return self._keep_option

    @property
    def update_img_path(self):
        return self._updates_img_path

    @property
    def script_path(self):
        return os.path.dirname(os.path.realpath(__file__))

    def process_argument(self):
        ns = self._parser.parse_args()

        self._sh_path = ns.kickstart_test
        self._image_path = ns.image

        base_path = os.path.splitext(self._sh_path)[0]
        self._ks_path = "{}{}".format(base_path, ".ks")

        self._ks_test_name = os.path.basename(base_path)

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


class TempManager(AbstractContextManager):

    def __init__(self, keep_type, test_name):
        super().__init__()

        self._tmp_dir = None
        self._keep_type = keep_type
        self._test_name = test_name

    def __enter__(self):
        prefix = "kstest-{}.".format(self._test_name)
        self._tmp_dir = mkdtemp(prefix=prefix, dir="/var/tmp")

        return self._tmp_dir

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._keep_type is KeepLevel.NOTHING:
            shutil.rmtree(self._tmp_dir)
        elif self._keep_type is KeepLevel.LOGS_ONLY:
            images_path = self._tmp_join_path("disk-*.img")
            ks_path = self._tmp_join_path("*.ks")

            for f in glob(images_path):
                os.remove(f)

            for f in glob(ks_path):
                os.remove(f)

    def _tmp_join_path(self, file_path):
        return os.path.join(self._tmp_dir, file_path)


class ShellLauncher(object):

    def __init__(self, configuration, tmp_dir):
        super().__init__()
        self._conf = configuration
        self._tmp_dir = tmp_dir

    def run_prepare(self):
        ret = self._run_shell_func("prepare")
        return ret.stdout.decode()

    def run_cleanup(self):
        ret = self._run_shell_func("cleanup")
        return ret.stdout.decode()

    def _run_shell_func(self, func_name):
        cmd_args = []
        script_path = os.path.join(self._conf.script_path, SHELL_INTERFACE_PATH)

        cmd_args.append(script_path)
        cmd_args.append("-i")
        cmd_args.append(self._conf.boot_image)
        cmd_args.append("-k")
        cmd_args.append(str(self._conf.keep_level.value))

        if self._conf.update_img_path:
            cmd_args.append("-u")
            cmd_args.append(self._conf.update_img_path)

        cmd_args.append("-w")
        cmd_args.append(self._tmp_dir)
        cmd_args.append("-t")
        cmd_args.append(self._conf.shell_test_path)

        cmd_args.append(func_name)

        out = subprocess.run(cmd_args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        try:
            out.check_returncode()
            return out
        except subprocess.CalledProcessError as e:
            self._report_error(e)
            raise e

    @staticmethod
    def _report_error(exc):
        print("Failed to run subprocess:")
        print("stderr:")
        print(exc.stderr)
        print("stdout:")
        print(exc.stdout)


class Runner(object):

    def __init__(self, configuration, tmp_dir):
        super().__init__()
        self._conf = configuration
        self._tmp_dir = tmp_dir
        self._ks_file = None

        self._check_subs_re = re.compile(r'@\w*@')

        self._shell = ShellLauncher(configuration, tmp_dir)

    def prepare_test(self):
        self._copy_image_to_tmp()

        try:
            self._shell.run_prepare()
        except subprocess.CalledProcessError as e:
            self._print_result(result=False, msg="Test prep failed", description=e.stdout.decode())
            self._shell.run_cleanup()
            exit(99)

        ok, reason = self._check_ks_test()
        if ok is False:
            self._print_result(result=False, msg="Unsubstituted pattern", description=reason)
            self._shell.run_cleanup()
            exit(99)

    def _print_result(self, result, msg, description):
        text_result = "SUCCESS" if result else "FAILED"
        msg = "RESULT:{name}:{result}:{message}: {desc}".format(name=self._conf.ks_test_name,
                                                                result=text_result,
                                                                message=msg,
                                                                desc=description)
        print(msg)

    def _copy_image_to_tmp(self):
        print("Copying image to temp directory {}".format(self._tmp_dir))
        shutil.copy2(self._conf.boot_image, self._tmp_dir)

    def _check_ks_test(self):
        with open(self._conf.ks_test_path, 'rt') as f:
            for num, line in enumerate(f):
                subs = self._check_subs_re.search(line)
                if subs is not None:
                    return False, "{} on line {}".format(subs[0], num)

        return True, None


if __name__ == '__main__':
    config = RunnerConfiguration()

    config.process_argument()

    with TempManager(config.keep_level, config.ks_test_name) as temp_dir:
        runner = Runner(config, temp_dir)
        runner.prepare_test()
