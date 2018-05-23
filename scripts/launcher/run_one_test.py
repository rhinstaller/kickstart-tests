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


import os
import re
import shutil
import subprocess

from lib.temp_manager import TempManager
from lib.configuration import RunnerConfiguration
from lib.shell_launcher import ShellLauncher
from lib.virtual_controller import VirtualManager, VirtualConfiguration


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
            self._ks_file = self._shell.run_prepare()
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

    def run_test(self):
        self.prepare_test()

        kernel_args = self._shell.run_kernel_args().split(" ")

        if self._conf.updates_img_path:
            kernel_args.append("inst.updates={}".format(self._conf.updates_img_path))

        if kernel_args:
            kernel_args = '--kernel-args "{}"'.format(kernel_args)

        disk_args = self._collect_disks()
        nics_args = self._collect_network()
        boot_args = self._shell.run_boot_args()

        v_conf = VirtualConfiguration(self._conf.boot_image, self._ks_file)
        v_conf.kernel_args = kernel_args
        v_conf.temp_dir = self._tmp_dir
        v_conf.log_path = os.path.join(self._tmp_dir, "livemedia.log")
        v_conf.ram = 1024
        v_conf.vnc = "vnc"
        v_conf.boot_image = boot_args
        v_conf.timeout = 60
        v_conf.disk_paths = disk_args
        v_conf.networks = nics_args

        virt_manager = VirtualManager(v_conf)
        ret = virt_manager.run()

    def _check_ks_test(self):
        with open(self._ks_file, 'rt') as f:
            for num, line in enumerate(f):
                subs = self._check_subs_re.search(line)
                if subs is not None:
                    return False, "{} on line {}".format(subs[0], num)

        return True, None

    def _collect_disks(self):
        ret = []

        disks = self._shell.run_prepare_disks()
        for d in disks.split(" "):
            ret.append("--disk")
            ret.append("{},cache=unsafe;".format(d))

        return ret

    def _collect_network(self):
        ret = []

        networks = self._shell.run_prepare_network()
        for n in networks.split(" "):
            ret.append("--nic")
            ret.append(n)

        return ret

    def _get_runner_args(self):
        ret = []

        args = self._shell.run_additional_runner_args()
        for arg in args.split(" "):
            ret.append(arg)

        return ret


if __name__ == '__main__':
    config = RunnerConfiguration()

    config.process_argument()

    with TempManager(config.keep_level, config.ks_test_name) as temp_dir:
        runner = Runner(config, temp_dir)
        runner.prepare_test()
