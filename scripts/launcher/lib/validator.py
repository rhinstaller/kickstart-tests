#!/usr/bin/python3
#
# Set of validator objects for kickstart tests.
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

import re

from .test_logging import get_logger

log = get_logger()


def replace_new_lines(line):
        line.replace("#012", "\n")
        return line


class ResultFormatter(object):

    def __init__(self, test_name):
        super().__init__()

        self._test_name = test_name

    def format_result(self, result, msg):
        text_result = "SUCCESS" if result else "FAILED"
        msg = "RESULT:{name}:{result}:{message}".format(name=self._test_name,
                                                        result=text_result,
                                                        message=msg)
        return msg

    def report_result(self, result, msg):
        msg = self.format_result(result, msg)
        log.info(msg)


class Validator(object):

    def __init__(self, name):
        super(). __init__()

        self._return_code = 0
        self._result_msg = ""
        self._result_formatter = ResultFormatter(name)

    @property
    def result(self):
        return self._return_code == 0

    @property
    def return_code(self):
        return self._return_code

    @property
    def result_message(self):
        return self._result_msg

    def report_result(self):
        msg = self._result_formatter.format_result(self.result,
                                                   self._result_msg)
        if self._return_code != 0:
            log.error(msg)
        else:
            log.info(msg)


class KickstartValidator(Validator):

    def __init__(self, test_name, kickstart_path):
        super().__init__(test_name)

        self._kickstart_path = kickstart_path
        self._check_subs_re = re.compile(r'@\w*@')

    @property
    def kickstart_path(self):
        return self._kickstart_path

    def check_ks_substitution(self):
        with open(self._kickstart_path, 'rt') as f:
            for num, line in enumerate(f):
                subs = self._check_subs_re.search(line)
                if subs is not None:
                    self._result_msg = "Substitution '{}' failed on line '{}'".format(subs[0], num)
                    self._return_code = 1
                    return

        self._return_code = 0


class LogValidator(Validator):

    def __init__(self, test_name):
        super().__init__(test_name)

    def check_install_errors(self, install_log):
        ret_code = 0

        with open(install_log, 'rt') as log_f:
            for line in log_f:

                # non critical error blocking the installation
                if "CRIT systemd-coredump:" in line:
                    log.info("Non critical error: {}".format(replace_new_lines(line)))
                    continue
                elif "CRIT" in line:
                    self._result_msg = replace_new_lines(line)
                    self._return_code = 1
                    break

        return ret_code

    def check_virt_errors(self, virt_log_path):
        with open(virt_log_path, 'rt') as virt_log:
            for line in virt_log:
                if "due to timeout" in line:
                    self._result_msg = "Test timed out"
                    self._return_code = 2
                    break
                elif "Call Trace" in line:
                    self._result_msg = "Kernel panic"
                    self._return_code = 0
