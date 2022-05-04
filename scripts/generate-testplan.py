#!/usr/bin/python3
#
# Copyright (C) 2022  Red Hat, Inc.
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
# Red Hat Author(s): Radek Vykydal <rvykydal@redhat.com>

import argparse
import subprocess
from jinja2 import Template


def parse_args():
    _parser = argparse.ArgumentParser(description="Generate testplan for scenario from template and skip-test tags")
    _parser.add_argument("--template-file", "-t", type=str, required=True,
                         metavar="TEMPLATE_FILE",
                         help="Template file.")
    _parser.add_argument("--skiptest-file", "-f", type=str, required=True,
                         metavar="SKIP_TEST_FILE",
                         help="File with skip test variables")
    _parser.add_argument("--skiptest-variable", "-s", type=str, required=True,
                         metavar="SKIP_TEST_VARIABLE",
                         help="Variable from the file to be used.")
    _parser.add_argument("--output", "-o", type=str,
                         metavar="OUTPUT_FILE",
                         help="Output file.")
    _parser.add_argument("--verbose", "-v", default=False, action="store_true",
                         help="Print the generated file.")
    return _parser.parse_args()


def get_variable_from_shell_file(varname, filename):
    cmd = f"echo $(source {filename}; echo ${varname})"
    print(cmd)
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True, shell=True, executable='/bin/bash')
    return p.stdout.read().strip()


if __name__ == "__main__":

    args = parse_args()

    var_value = get_variable_from_shell_file(args.skiptest_variable, args.skiptest_file)
    tag_list = var_value.split(',')

    with open(args.template_file, 'r') as f:
        template_tp = f.read()

    template = Template(template_tp, trim_blocks=True)
    header = f"# Query generated from {args.skiptest_variable} of {args.skiptest_file}"
    tp = template.render(skiptags=tag_list)

    if args.output:
        with open(args.output, 'w') as f:
            f.write(header+"\n")
            f.write(tp)

    if not args.output or args.verbose:
        print(header)
        print(tp)
