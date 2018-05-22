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

# This is a library to control the shell scripts in the test.

import os
import subprocess

SHELL_INTERFACE_PATH = "launcher_interface.sh"


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

    def run_prepare_disks(self):
        ret = self._run_shell_func("prepare_disks")
        return ret.stdout.decode()

    def run_prepare_network(self):
        ret = self._run_shell_func("prepare_network")
        return ret.stdout.decode()

    def run_kernel_args(self):
        ret = self._run_shell_func("kernel_args")
        return ret.stdout.decode()

    def run_additional_runner_args(self):
        ret = self._run_shell_func("additional_runner_args")
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
