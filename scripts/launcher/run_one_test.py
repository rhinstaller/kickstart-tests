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
import subprocess
import socket

from lib.utils import TempManager, disable_on_dry_run
from lib.conf.configuration import VirtualConfiguration
from lib.conf.runner_parser import RunnerParser
from lib.shell_launcher import ShellLauncher
from lib.virtual_controller import VirtualManager, InstallError
from lib.validator import KickstartValidator, LogValidator, ResultFormatter, Validator
from lib.test_logging import setup_logger, get_logger

log = get_logger()


class Runner(object):

    def __init__(self, configuration, tmp_dir):
        super().__init__()
        self._conf = configuration
        self._tmp_dir = tmp_dir
        self._ks_file = None

        self._shell = ShellLauncher(configuration, tmp_dir)
        self._result_formatter = ResultFormatter(self._conf.ks_test_name, host_id=self.host_id)
        # test prepare function can change place of the kickstart test
        # so the validator will be set later
        self._validator = None

    @property
    def host_id(self):
        """Return a show string identifying the host where the test is running.

        This is currently simply the hostname.

        :return: a test runner describing string
        :rtype: str
        """
        return socket.gethostname()

    def _prepare_test(self):
        log.debug("Preparing test")
        self._link_image_to_tmp()

        try:
            self._ks_file = self._shell.prepare()
        except subprocess.CalledProcessError:
            self._result_formatter.report_result(result=False, msg="Test prep failed")
            self._shell.cleanup()
            return False

        self._validator = KickstartValidator(self._conf.ks_test_name, self._ks_file)
        self._validator.check_ks_substitution()
        if not self._validator.result:
            self._validator.report_result()
            self._shell.cleanup()
            return False

        return True

    def _link_image_to_tmp(self):
        log.info("Linking image to temp directory {}".format(self._tmp_dir))
        os.symlink(os.path.abspath(self._conf.boot_image_path), os.path.join(self._tmp_dir, "boot.iso"))

    def run_test(self):
        if not self._prepare_test():
            return 99

        v_conf = self._create_virtual_conf()

        virt_manager = VirtualManager(v_conf)

        try:
            virt_manager.run()
        except InstallError as e:
            self._result_formatter.report_result(False, str(e))
            return 1

        ret = self._validate_all(v_conf)

        self._cleanup()
        return ret.return_code

    @disable_on_dry_run
    def _cleanup(self):
        self._shell.cleanup()

    def _create_virtual_conf(self) -> VirtualConfiguration:
        kernel_args = self._shell.kernel_args()

        if self._conf.updates_img_path:
            kernel_args += " inst.updates={}".format(self._conf.updates_img_path)

        if self._conf.hung_task_timeout_secs:
            kernel_args += " inst.kernel.hung_task_timeout_secs={}".format(
                self._conf.hung_task_timeout_secs)

        disk_args = self._shell.prepare_disks()
        nics_args = self._shell.prepare_network()
        boot_args = self._shell.boot_args()

        target_boot_iso = os.path.join(self._tmp_dir, self._conf.boot_image_name)

        ks = []
        if self._shell.inject_ks_to_initrd():
            ks.append(self._ks_file)

        v_conf = VirtualConfiguration(target_boot_iso, ks)

        v_conf.kernel_args = kernel_args
        v_conf.test_name = self._conf.ks_test_name
        v_conf.temp_dir = self._tmp_dir
        v_conf.log_path = os.path.join(self._tmp_dir, "livemedia.log")
        v_conf.vnc = "vnc"
        v_conf.boot_image = boot_args
        v_conf.timeout = 120
        v_conf.disk_paths = disk_args
        v_conf.networks = nics_args

        return v_conf

    @disable_on_dry_run(returns=Validator("dry-run validator"))
    def _validate_all(self, v_conf):
        validator = self._validate_logs(v_conf)

        if validator and not validator.result:
            validator.report_result()
            return validator

        ret = self._validate_result()
        if ret.check_ret_code():
            self._result_formatter.report_result(True, "test done")

        return ret

    def _validate_logs(self, virt_configuration):
        validator = LogValidator(self._conf.ks_test_name)
        validator.check_install_errors(virt_configuration.install_logpath)

        if validator.result:
            validator.check_virt_errors(virt_configuration.log_path)

        return validator

    def _validate_result(self):
        output = self._shell.validate()

        if not output.check_ret_code():
            msg = "Validation failed with return code {}".format(output.return_code)
            self._result_formatter.report_result(False, msg)

        return output


def run_test_in_temp(config):
    with TempManager(config.keep_level, config.ks_test_name) as temp_dir:
        setup_logger(temp_dir)
        runner = Runner(config, temp_dir)
        rc = runner.run_test()

    return rc


if __name__ == '__main__':
    parser = RunnerParser()
    config = parser.get_configuration()

    print("================================================================")
    ret_code = run_test_in_temp(config)

    exit(ret_code)
