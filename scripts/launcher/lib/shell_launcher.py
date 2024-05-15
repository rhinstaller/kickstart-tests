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
#
# This is a library to control the shell scripts in the test.

import os
import subprocess

from .test_logging import get_logger

log = get_logger()

SHELL_INTERFACE_PATH = "launcher_interface.sh"


class ShellProcessError(Exception):
    pass


class ShellOutput(object):

    def __init__(self, subprocess_out):
        super().__init__()

        self._out = subprocess_out

    @property
    def stdout(self):
        return self._out.stdout.decode().rstrip()

    @property
    def stdout_as_array(self):
        ret = self.stdout

        if ret:
            return ret.split()
        else:
            return []

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


class ProcessLauncher(object):

    def __init__(self, print_errors=True):
        super().__init__()
        self._print_errors = print_errors
        self._cmd = None

    def _report_result(self, subprocess_out):
        if not subprocess_out.check_ret_code():
            msg = "Failed to run subprocess: '{}'\n".format(self._cmd)
            msg += self._format_result(subprocess_out)

            if self._print_errors:
                print(msg)

            log.debug(msg)
        else:
            msg = self._format_result(subprocess_out)
            log.debug(msg)

    def _format_result(self, subprocess_out):
        msg = ""

        if subprocess_out.stderr:
            msg += "stderr:\n"
            msg += subprocess_out.stderr + "\n"
        if subprocess_out.stdout:
            msg += "stdout:\n"
            msg += subprocess_out.stdout + "\n"

        return msg

    def run_process(self, args):
        self._cmd = args
        log.debug("Running command: {}".format(args))
        out = subprocess.run(args, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        s_out = ShellOutput(out)
        self._report_result(s_out)
        return s_out


class ShellLauncher(ProcessLauncher):

    def __init__(self, configuration, tmp_dir):
        super().__init__()
        self._conf = configuration
        self._tmp_dir = tmp_dir

    def prepare(self):
        out = self._run_shell_func("prepare")
        out.check_ret_code_with_exception()
        return out.stdout

    def cleanup(self):
        return self._run_shell_func("cleanup")

    def prepare_updates(self):
        out = self._run_shell_func("prepare_updates")
        out.check_ret_code_with_exception()
        return out.stdout

    def prepare_disks(self):
        out = self._run_shell_func("prepare_disks")
        ret = []

        out.check_ret_code_with_exception()

        for d in out.stdout_as_array:
            ret.append("{},cache=unsafe".format(d))

        return ret

    def prepare_network(self):
        out = self._run_shell_func("prepare_network")
        ret = []

        out.check_ret_code_with_exception()

        for n in out.stdout_as_array:
            ret.append(n)

        return ret

    def kernel_args(self):
        out = self._run_shell_func("kernel_args")

        out.check_ret_code_with_exception()
        return out.stdout

    def additional_runner_args(self):
        out = self._run_shell_func("additional_runner_args")
        ret = []

        out.check_ret_code_with_exception()
        for arg in out.stdout_as_array:
            ret.append(arg)

        return ret

    def boot_args(self):
        out = self._run_shell_func("boot_args")
        out.check_ret_code_with_exception()
        return out.stdout_as_array

    def get_timeout(self):
        """Per test timeout override.

        The value returned by the get_timeout() function should be
        a string representing an integer value that sets how long
        should we wait for a test to finish in minutes.
        """
        out = self._run_shell_func("get_timeout")

        out.check_ret_code_with_exception()
        return out.stdout

    def get_required_ram(self):
        """Per test timeout override.

        The value returned by the get_required_ram() function should be
        a string representing an integer value of the size of RAM (in MiB)
        of the VM used for the test.
        """
        out = self._run_shell_func("get_required_ram")

        out.check_ret_code_with_exception()
        return out.stdout

    def validate(self):
        return self._run_shell_func("validate")

    def _run_bool_shell_func(self, name):
        out = self._run_shell_func(name)

        out.check_ret_code_with_exception()

        if out.stdout == "true":
            return True
        elif out.stdout == "false":
            return False
        else:
            raise ShellProcessError("Shell function {} must return 'true' or "
                                    "'false' but returned {}".format(name, out.stdout))

    def inject_ks_to_initrd(self):
        return self._run_bool_shell_func("inject_ks_to_initrd")

    def stage2_from_ks(self):
        return self._run_bool_shell_func("stage2_from_ks")

    def _run_shell_func(self, func_name):
        cmd_args = []
        script_path = os.path.join(self._conf.script_path, SHELL_INTERFACE_PATH)

        cmd_args.append(script_path)
        cmd_args.append("-i")
        cmd_args.append(self._conf.boot_image_path)
        cmd_args.append("-k")
        cmd_args.append(str(self._conf.keep_level.value))

        if self._conf.updates_img_path:
            cmd_args.append("-u")
            cmd_args.append(self._conf.updates_img_path)

        cmd_args.append("-w")
        cmd_args.append(self._tmp_dir)
        cmd_args.append("-t")
        cmd_args.append(self._conf.shell_test_path)

        cmd_args.append(func_name)

        return self.run_process(cmd_args)
