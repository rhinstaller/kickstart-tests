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
# Generate a testing repository.
# Usage: generate-repository.py <REPO_PATH> <REPO_NAME>
#
# This script generates a testing repository (for example, x) with the following packages:
#
#   mandatory-package-from-x
#       * Provided only by the repository x.
#       * It is a mandatory package of the @core group.
#       * It will be installed by default if the repository x is enabled.
#
#   optional-package-from-x
#       * Provided only by the repository x.
#       * It has to be explicitly requested for installation.
#
#   conflicting-package-from-x
#       * Provided only by the repository x.
#       * It has to be explicitly requested for installation.
#       * It conflicts with optional-package-from-x.
#
#   package-1
#       * It is provided by all generated repositories.
#       * It has to be explicitly requested for installation.
#       * It installs a file /usr/share/package-1/x if it is installed from repository x.
#
#   package-2
#       * It is provided by all generated repositories.
#       * It has to be explicitly requested for installation.
#       * It installs a file /usr/share/package-2/x if it is installed from repository x.
#
#   package-3
#       * It is provided by all generated repositories.
#       * It has to be explicitly requested for installation.
#       * It installs a file /usr/share/package-3/x if it is installed from repository x.
#

import os
import rpmfluff
import sys

from subprocess import check_call

# Check the arguments.
if len(sys.argv) != 3:
    print("Usage: %s <REPO_PATH> <REPO_NAME>" % sys.argv[0], file=sys.stderr)
    sys.exit(1)

# Get the repo path and repo name.
repo_path = sys.argv[1]
repo_name = sys.argv[2]

# Create the repo directory.
os.makedirs(repo_path, exist_ok=True)
os.chdir(repo_path)

# Everything in this script is super-noisy, which is bad for callers trying
# to keep a sensible stdout. dup stdout to /dev/null to shut up the parts
# that break kickstart test prepare(), and leave stderr so we can maybe see
# what went wrong if something goes wrong
os.dup2(os.open(os.devnull, os.O_WRONLY), 1)

# The repository contains one mandatory package.
pkg = rpmfluff.SimpleRpmBuild(
    'mandatory-package-from-{}'.format(repo_name),
    version='1.0',
    release='1',
    tmpdir=False,
)
pkg.make()

# The repository contains one optional package.
pkg = rpmfluff.SimpleRpmBuild(
    'optional-package-from-{}'.format(repo_name),
    version='1.0',
    release='1',
    tmpdir=False,
)
pkg.make()

# The repository contains one conflicting package.
pkg = rpmfluff.SimpleRpmBuild(
    'conflicting-package-from-{}'.format(repo_name),
    version='1.0',
    release='1',
    tmpdir=False,
)
pkg.add_conflicts(
    'optional-package-from-{}'.format(repo_name)
)
pkg.make()

# The repository contains three other packages.
# These packages are provided by all generated
# repositories, but they install different files.
for i in (1, 2, 3):
    pkg = rpmfluff.SimpleRpmBuild(
        'package-{}'.format(i),
        version='1.0',
        release='1',
        tmpdir=False,
    )
    pkg.add_installed_file(
        '/usr/share/package-{}/{}'.format(i, repo_name),
        rpmfluff.SourceFile(repo_name, '')
    )
    pkg.make()

# Create a comps file.
with open('comps.xml', 'wt') as comps:
    comps.write('''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE comps PUBLIC "-//Red Hat, Inc.//DTD Comps info//EN" "comps.dtd">
<comps>
  <group>
    <id>core</id>
    <packagelist>
      <packagereq type="mandatory">mandatory-package-from-{}</packagereq>
    </packagelist>
  </group>
</comps>'''.format(repo_name))

# Create a repository.
check_call(['createrepo_c', '-g', 'comps.xml', '.'])
