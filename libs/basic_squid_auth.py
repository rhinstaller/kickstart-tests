#!/usr/bin/python3
#
# Copyright (C) 2017  Red Hat, Inc.
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
#
# Helper script for squid for basic proxy authentication.
# To run this script you need to have file with username and password
# in format:
#
# username:password
#
# This script should be used with squid configuration file
# scripts/confs/squid-pass.conf .

import sys
import os
import argparse

def read_pass_file(file_name):
    """ Read username and password from file in the same place as this script + file_name.

    Structure of the loaded file is:
        user:passwd
    """
    script_dir = os.path.dirname(sys.argv[0])
    f_path = os.path.join(script_dir, file_name)
    with open(f_path, 'r') as f:
        (user, password) = f.readline().strip().split(":")
    return (user, password)


def parse_args():
    """ Parse input arguments. """
    parser = argparse.ArgumentParser(description="Helper script to authenticate squid proxy.")
    parser.add_argument("passwd_file", help="path to the password file. "
                                            "Password file should be in format: username:password")
    parser.add_argument("-d", "--debug", dest="debug", action="store_true",
                        help="Turn the debug on. Write the debug output to "
                             "squid-auth.log file, next to this script file.")
    return parser.parse_args()


def write_debug(message, debug_fd):
    """ Write debug message and flush it. """
    if debug_fd is not None:
        debug_fd.write(message)


def main(user, password, debug_fd=None):
    """ Main program loop. """
    try:
        while True:
            r_in = input()
            write_debug("Test credentials: %s -- " % r_in.rstrip(), debug_fd=debug_fd)
            (in_user, in_password) = r_in.strip().split(' ')
            if in_user == user and in_password == password:
                print("OK")
                write_debug("OK\n", debug_fd=debug_fd)
            else:
                print("ERR ")
                write_debug("ERR\n", debug_fd=debug_fd)
                write_debug(("ref: '%s' '%s' -- in: '%s' '%s'\n" %
                             (user, password, in_user, in_password)), debug_fd=debug_fd)
    except EOFError:
        pass


if __name__ == "__main__":
    args = parse_args()

    (user, password) = read_pass_file(args.passwd_file)
    script_dir = os.path.dirname(os.path.realpath(sys.argv[0]))
    if args.debug:
        with open(os.path.join(script_dir, "squid-auth.log"), 'w') as f:
            f.write("Logging start\n")
            f.flush()
            main(user=user, password=password, debug_fd=f)
            f.write("Logging end\n")
    else:
        main(user=user, password=password)

