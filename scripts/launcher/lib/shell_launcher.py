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


class ShellOutput(object):

    def __init__(self, subprocess_out):
        super().__init__()

        self._out = subprocess_out

    @property
    def stdout(self):
        return self._out.stdout.decode().rstrip()

    @property
    def stderr(self):
        return self._out.stderr.decode().rstrip()

    @property
    def return_code(self):
        return self._out.returncode

    def check_ret_code_with_exception(self):
        return self._out.check_returncode()

    def check_ret_code(self):
        return self._out.returncode == 0


class ShellLauncher(object):

    def __init__(self, configuration, tmp_dir):
        super().__init__()
        self._conf = configuration
        self._tmp_dir = tmp_dir

    def run_prepare(self):
        return self._run_shell_func("prepare")

    def run_cleanup(self):
        return self._run_shell_func("cleanup")

    def run_prepare_disks(self):
        return self._run_shell_func("prepare_disks")

    def run_prepare_network(self):
        return self._run_shell_func("prepare_network")

    def run_kernel_args(self):
        return self._run_shell_func("kernel_args")

    def run_additional_runner_args(self):
        return self._run_shell_func("additional_runner_args")

    def run_boot_args(self):
        return self._run_shell_func("boot_args")

    def run_validate(self):
        return self._run_shell_func("validate")

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

        if out.returncode != 0:
            self._report_error(out)

        return ShellOutput(out)

    @staticmethod
    def _report_error(subprocess_out):
        print("Failed to run subprocess:")
        print("stderr:")
        print(subprocess_out.stderr)
        print("stdout:")
        print(subprocess_out.stdout)
