#!/usr/bin/python3

#
# Copyright (C) 2019  Red Hat, Inc.
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

from lib.utils import is_dry_run, disable_on_dry_run
from pylorax.monitor import LogMonitor as LoraxLogMonitor

from .log_handler import VirtualLogRequestHandler


class LogMonitor(object):
    def __init__(self, install_log, timeout, log_request_handler_class=None):
        """Monitor VM logs and reacts properly on what happens there.

        :param str install_log: path where to store installation log
        :param int timeout: set timeout in minutes before killing the VM
        :param log_request_handler_class: class compatible with
                                          pylorax.monitor.LogRequestHandler
                                          Use VirtualLogRequestHandler if not set.
        """
        self._install_log = install_log
        self._timeout = timeout

        if log_request_handler_class:
            self._log_request_handler_class = log_request_handler_class
        else:
            self._log_request_handler_class = VirtualLogRequestHandler

        if not is_dry_run():
            self._lorax_log_monitor = LoraxLogMonitor(
                self._install_log,
                timeout=self._timeout,
                log_request_handler_class=self._log_request_handler_class
            )

    @property
    def host(self):
        if is_dry_run():
            return "DRY_RUN_HOST"

        return self._lorax_log_monitor.host

    @property
    def port(self):
        if is_dry_run():
            return "DRY_RUN_PORT"

        return self._lorax_log_monitor.port

    @property
    def error_line(self):
        if is_dry_run():
            return None

        return self._lorax_log_monitor.server.error_line

    @disable_on_dry_run(False)
    def log_check(self):
        return self._lorax_log_monitor.server.log_check()

    @disable_on_dry_run
    def shutdown(self):
        self._lorax_log_monitor.shutdown()
