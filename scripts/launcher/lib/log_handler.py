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
# Red Hat Author(s): Vendula Poncova <vponcova@redhat.com>
#
from pylorax.monitor import LogRequestHandler


class VirtualLogRequestHandler(LogRequestHandler):

    # Specify the error lines you want to ignore.
    ignored_simple_tests = [
        # "Call Trace:"
    ]

    # Specify error lines you want to add on top
    # of the default ones contained in Lorax
    simple_tests = LogRequestHandler.simple_tests + [
        "Payload setup error:",
        "Out of memory:",
        "The following group or module is missing:",
        "Stream was not specified for a module",
        "The following problem occurred on line",  # kickstart parsing error
        "storage configuration failed:",
    ]

    def iserror(self, line):

        # Skip ignored simple tests.
        for t in self.ignored_simple_tests:
            if t in line:
                return

        super().iserror(line)
