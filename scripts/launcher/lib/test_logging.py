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


import logging
import sys


def setup_logger(log_path):
    log = get_logger()
    log.setLevel(logging.DEBUG)

    # verbose output to file
    h_file = logging.FileHandler(log_path)
    h_file.setFormatter(logging.Formatter("%(asctime)s %(levelname)s: %(message)s"))
    log.addHandler(h_file)

    # output without debugging to console
    h_console = logging.StreamHandler(sys.stdout)
    h_console.setLevel(logging.INFO)
    h_console.setFormatter(logging.Formatter("%(asctime)s %(levelname)s: %(message)s"))
    log.addHandler(h_console)


def close_logger():
    log = get_logger()
    for h in log.handlers.copy():
        h.close()
        log.removeHandler(h)


def get_logger():
    return logging.getLogger("kstest-logger")
