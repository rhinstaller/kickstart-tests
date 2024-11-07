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
# Red Hat Author(s): Vendula Poncova <vponcova@redhat.com>
#
import os

from pylorax.monitor import LogRequestHandler


class VirtualLogRequestHandler(LogRequestHandler):

    # Specify the error lines you want to ignore.
    ignored_simple_tests = [
        # shadow-utils CRIT messages, gh1061 BZ2265291
        ":shadow: unknown configuration item ",

        # Non critical error blocking the installation.
        "CRIT systemd-coredump:",

        # Based on the bug #1886809, it is a non critical error.
        "CRIT mdadm:DegradedArray event detected",

        # Ignore deprecated kernel drivers
        "CRIT kernel:Warning: Deprecated Driver is detected: ",

        # Ignore a call trace during debugging.
        # Ignoring permanently for gh768.
        # https://github.com/rhinstaller/kickstart-tests/issues/768
        "Call Trace:"
    ]

    # Path to the config file
    CONFIG_FILE_PATH = '/tmp/ignored_simple_tests.conf'

    if os.path.isfile(CONFIG_FILE_PATH):
        with open(CONFIG_FILE_PATH, 'r') as config_file:
            extra_ignored_tests = [line.strip() for line in config_file if line.strip()]
            # Extend the ignored_simple_tests list
            ignored_simple_tests.extend(extra_ignored_tests)

        # Remove the config file after reading
        os.remove(CONFIG_FILE_PATH)

    # Specify error lines you want to add on top
    # of the default ones contained in Lorax
    simple_tests = LogRequestHandler.simple_tests + [
        "CRIT",
        "Payload setup error:",
        "Out of memory:",
        "Would you like to ignore this and continue with installation?",
        "Some packages, groups or modules are broken, the installation will be aborted.",
        "Error in POSTIN scriptlet in rpm package",
        "Error in POSTTRANS scriptlet in rpm package"
        "Error in <unknown> scriptlet in rpm package"
        "Transaction check error:",
        "Stream was not specified for a module",
        "Modular dependency problem:",  # broken module
        "The following problem occurred on line",  # kickstart parsing error
        "storage configuration failed:",
        "Not enough space in file systems for the current software selection.",
        "anabot.service: Failed with result 'exit-code'.",
    ]

    def iserror(self, line):

        # Skip ignored simple tests.
        for t in self.ignored_simple_tests:
            if t in line:
                return

        super().iserror(line)
