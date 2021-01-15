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

# Library for parsing arguments and provides usable output from it.

import os

from enum import Enum
from abc import ABC

__all__ = ["KeepLevel", "RunnerConfiguration", "VirtualConfiguration"]


class KeepLevel(Enum):
    NOTHING = 0
    LOGS_ONLY = 1
    EVERYTHING = 2


class BaseConfiguration(ABC):
    """Base configuration implementing repr method."""
    def __init__(self, name):
        self._name = name

    def __repr__(self):
        msg = "{}:".format(self._name)

        for p in dir(self.__class__):
            if p.startswith("_"):
                continue
            else:
                if getattr(self, p):
                    msg += " {}: {},".format(p, getattr(self, p))

        msg = msg[:-1]

        return msg


class GlobalConfiguration(BaseConfiguration):
    """Global static configuration usable from all parts of the program"""
    _dry_run = False

    def __init__(self):
        super().__init__("Global Configuration")

    @classmethod
    def set_dry_run(cls, value):
        cls._dry_run = value

    @classmethod
    def dry_run(cls):
        return cls._dry_run


class RunnerConfiguration(BaseConfiguration):

    def __init__(self):
        """Configuration for the runner of the kickstart test"""
        super().__init__("Runner Configuration")

        self._ks_test_name = ""
        self._sh_path = ""
        self._ks_path = ""
        self._image_path = ""
        self._keep_option = KeepLevel.NOTHING
        self._updates_img_path = ""
        self._append_host_id = False
        self._hung_task_timeout_secs = 1200

    @property
    def shell_test_path(self):
        return self._sh_path

    @shell_test_path.setter
    def shell_test_path(self, val):
        self._sh_path = val

    @property
    def ks_test_path(self):
        return self._ks_path

    @ks_test_path.setter
    def ks_test_path(self, val):
        self._ks_path = val

    @property
    def ks_test_name(self):
        return self._ks_test_name

    @ks_test_name.setter
    def ks_test_name(self, val):
        self._ks_test_name = val

    @property
    def boot_image_path(self):
        return self._image_path

    @boot_image_path.setter
    def boot_image_path(self, val):
        self._image_path = val

    @property
    def boot_image_name(self):
        return os.path.basename(self._image_path)

    @property
    def keep_level(self):
        return self._keep_option

    @keep_level.setter
    def keep_level(self, val: KeepLevel):
        self._keep_option = val

    @property
    def updates_img_path(self):
        return self._updates_img_path

    @updates_img_path.setter
    def updates_img_path(self, val):
        self._updates_img_path = val

    @property
    def script_path(self):
        path = os.path.join(__file__, "..")
        return os.path.dirname(os.path.realpath(path))

    @property
    def append_host_id(self):
        return self._append_host_id

    @append_host_id.setter
    def append_host_id(self, val: bool):
        self._append_host_id = val

    @property
    def hung_task_timeout_secs(self):
        return self._hung_task_timeout_secs

    @hung_task_timeout_secs.setter
    def hung_task_timeout_secs(self, val: int):
        self._hung_task_timeout_secs = val


class VirtualConfiguration(BaseConfiguration):

    def __init__(self, iso_path, ks_paths):
        """Configuration for runner of the virtual machine"""
        super().__init__("Virtual Configuration")

        self._test_name = ""
        self._iso = iso_path
        self._ks_paths = ks_paths
        self._disk = []
        self._nic = []
        self._proxy = None
        self._location = None
        self._boot = None
        self._logfile = None
        self._tmp = "/var/tmp"
        self._keep_image = True
        self._vcpu_count = 1
        self._ram = 2048
        self._vnc = None
        self._kernel_args = None
        self._timeout = None
        self._runner_args = []

    @property
    def test_name(self):
        """Name of this test run.

        Optional. Can be empty string.
        """
        return self._test_name

    @test_name.setter
    def test_name(self, value):
        """Set name of this test run.

        Optional. Can be empty string.
        """
        self._test_name = value

    @property
    def iso_path(self) -> str:
        """Anaconda installation .iso path to use for virt-install"""
        return self._iso

    @iso_path.setter
    def iso_path(self, value: str):
        """Set Anaconda installation .iso path to use for virt-install"""
        self._iso = value

    @property
    def ks_paths(self) -> []:
        """Kickstart file defining the install"""
        return self._ks_paths

    @ks_paths.setter
    def ks_paths(self, value: []):
        """Set kickstart file defining the install"""
        self._ks_paths = value

    @property
    def disk_paths(self) -> []:
        """Pre-existing disk image to use for destination"""
        return self._disk

    @disk_paths.setter
    def disk_paths(self, value: []):
        """Set pre-existing disk image to use for destination"""
        self._disk = value

    @property
    def networks(self) -> []:
        """Network devices to be used"""
        return self._nic

    @networks.setter
    def networks(self, value: []):
        """Set network devices to be used"""
        self._nic = value

    @property
    def proxy(self) -> str:
        """Proxy URL to use for the install"""
        return self._proxy

    @proxy.setter
    def proxy(self, value: str):
        """Set proxy URL to use for the install"""
        self._proxy = value

    @property
    def location(self) -> str:
        """Location of iso directory tree"""
        return self._location

    @location.setter
    def location(self, value: str):
        """Set location of iso directory tree"""
        self._location = value

    @property
    def boot_image(self) -> str:
        """Alternative boot image

         eg. ipxe.lkrn for ibft
         """
        return self._boot

    @boot_image.setter
    def boot_image(self, value: str):
        """Set alternative boot image"""
        self._boot = value

    @property
    def log_path(self) -> str:
        """Path to logfile"""
        return self._logfile

    @log_path.setter
    def log_path(self, value: str):
        """Set path to logfile"""
        self._logfile = value

    @property
    def install_logpath(self):
        """Virtual log file

        Will be dynamically created based on the temp position.
        """
        return os.path.join(self._tmp, "virt-install.log")

    @property
    def temp_dir(self) -> str:
        """Top level temporary directory"""
        return self._tmp

    @temp_dir.setter
    def temp_dir(self, value: str):
        """Set top level temporary directory"""
        self._tmp = value

    @property
    def keep_image(self) -> bool:
        """Keep raw disk image after .iso creation"""
        return self._keep_image

    @keep_image.setter
    def keep_image(self, value: bool):
        """Set keep raw disk image after .iso creation"""
        self._keep_image = value

    @property
    def vcpu_count(self) -> int:
        """Number of CPU to allocate for installer"""
        return self._vcpu_count

    @vcpu_count.setter
    def vcpu_count(self, value: int):
        """Number of CPU to allocate for installer"""
        self._vcpu_count = value

    @property
    def ram(self) -> int:
        """Memory to allocate for installer in megabytes"""
        return self._ram

    @ram.setter
    def ram(self, value: int):
        """Set memory to allocate for installer in megabytes"""
        self._ram = value

    @property
    def vnc(self) -> str:
        """Passed to --graphics command"""
        return self._vnc

    @vnc.setter
    def vnc(self, value: str):
        """Set passed to --graphics command"""
        self._vnc = value

    @property
    def kernel_args(self) -> str:
        """Additional argument to pass to the installation kernel"""
        return self._kernel_args

    @kernel_args.setter
    def kernel_args(self, value: str):
        """Set additional argument to pass to the installation kernel"""
        self._kernel_args = value

    @property
    def timeout(self) -> int:
        """Cancel installer after X minutes"""
        return self._timeout

    @timeout.setter
    def timeout(self, value: int):
        """Set cancel installer after X minutes"""
        self._timeout = value

    @property
    def runner_args(self) -> list:
        """Additional arguments to pass to virt-install"""
        return self._runner_args

    @runner_args.setter
    def runner_args(self, value: list):
        """Set additional arguments to pass to virt-install"""
        self._runner_args = value
