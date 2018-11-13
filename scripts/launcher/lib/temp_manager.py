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

# This is library for working with temp directory.

import os
import shutil

from contextlib import AbstractContextManager
from tempfile import mkdtemp
from glob import glob
from lib.conf.configuration import KeepLevel


class TempManager(AbstractContextManager):

    def __init__(self, keep_type, test_name):
        super().__init__()

        self._tmp_dir = None
        self._keep_type = keep_type
        self._test_name = test_name

    def __enter__(self):
        prefix = "kstest-{}.".format(self._test_name)
        self._tmp_dir = mkdtemp(prefix=prefix, dir="/var/tmp")
        self._change_permission()

        return self._tmp_dir

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._keep_type is KeepLevel.NOTHING:
            shutil.rmtree(self._tmp_dir)
        elif self._keep_type is KeepLevel.LOGS_ONLY:
            images_path = self._tmp_join_path("disk-*.img")
            iso_path = self._tmp_join_path("*.iso")

            for f in glob(images_path):
                os.remove(f)

            for f in glob(iso_path):
                os.remove(f)

    def _tmp_join_path(self, file_path):
        return os.path.join(self._tmp_dir, file_path)

    def _change_permission(self):
        os.chmod(self._tmp_dir, 0o755)

