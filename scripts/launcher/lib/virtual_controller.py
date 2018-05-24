#!/usr/bin/python3
#
# virtual_controller - the LMC-like library that only does
# what's necessary for running kickstart-based tests in anaconda
#
# Copyright (C) 2011-2015  Red Hat, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Author(s): Brian C. Lane <bcl@redhat.com>
#            Chris Lumens <clumens@redhat.com>
#            Jiri Konecny <jkonecny@redhat.com>
#

import os
import sys
import uuid
import tempfile
import subprocess
import libvirt

from time import sleep

# Use the Lorax treebuilder branch for iso creation
from pylorax.treebuilder import udev_escape
from pylorax.executils import execWithRedirect

from pylorax import setup_logging
from pylorax.monitor import LogMonitor
from pylorax.mount import IsoMountpoint

from .validator import replace_new_lines

import logging
log = logging.getLogger("livemedia-creator")


__all__ = ["VirtualConfiguration", "VirtualManager", "InstallError"]


class InstallError(Exception):
    def __str__(self):
        return super().__str__().replace("#012", "\n")


class VirtualConfiguration(object):

    def __init__(self, iso_path, ks_paths):
        super().__init__()

        self._iso = iso_path
        self._ks_paths = ks_paths
        self._disk = []
        self._nic = []
        self._proxy = None
        self._location = None
        self._boot = None
        self._logfile = "./livemedia.log"
        self._tmp = "/var/tmp"
        self._keep_image = True
        self._ram = 1024
        self._vnc = None
        self._kernel_args = None
        self._timeout = None

    def __str__(self):
        msg = "Virtual Configuration:"

        for p in dir(VirtualConfiguration):
            if p.startswith("_"):
                continue
            else:
                if getattr(self, p):
                    msg += " {}: {},".format(p, getattr(self, p))

        msg = msg[:-1]

        return msg

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


class VirtualInstall(object):
    """
    Run virt-install using an iso and a kickstart
    """
    def __init__(self, iso, ks_paths, disk_paths, log_check,
                 kernel_args=None, memory=1024, vnc=None,
                 virtio_host="127.0.0.1", virtio_port=6080,
                 nics=None, boot=None):
        """
        Start the installation

        :param iso: Information about the iso to use for the installation
        :type iso: IsoMountpoint
        :param list ks_paths: Paths to kickstart files. All are injected, the
           first one is the one executed.
        :param log_check: Method that returns True if the installation fails
        :type log_check: method
        :param list disk_paths: Paths to pre-existing disk images.
        :param str kernel_args: Extra kernel arguments to pass on the kernel cmdline
        :param int memory: Amount of RAM to assign to the virt, in MiB
        :param str vnc: Arguments to pass to virt-install --graphics
        :param str virtio_host: Hostname to connect virtio log to
        :param int virtio_port: Port to connect virtio log to
        :param list nics: virt-install --network parameters
        :param str boot: virt-install --boot option (used eg for ibft)
        """
        super().__init__()

        self._virt_name = "LiveOS-" + str(uuid.uuid4())
        self._iso = iso
        self._ks_paths = ks_paths
        self._disk_paths = disk_paths
        self._kernel_args = kernel_args
        self._memory = memory
        self._vnc = vnc
        self._log_check = log_check
        self._virtio_host = virtio_host
        self._virtio_port = virtio_port
        self._nics = nics
        self._boot = boot

    def _prepare_args(self):
        # add --graphics none later
        # add whatever serial cmds are needed later
        args = ["-n", self._virt_name,
                "-r", str(self._memory),
                "--noautoconsole",
                "--rng", "/dev/random"]

        # CHECKME This seems to be necessary because of ipxe ibft chain booting,
        # otherwise the vm is created but it does not boot into installation
        if not self._boot:
            args.append("--noreboot")

        args.append("--graphics")
        if self._vnc:
            args.append(self._vnc)
        else:
            args.append("none")

        for ks in self._ks_paths:
            args.append("--initrd-inject")
            args.append(ks)

        for disk in self._disk_paths:
            args.append("--disk")
            args.append("path={0}".format(disk))

        for nic in self._nics or []:
            args.append("--network")
            args.append(nic)

        if self._iso.stage2:
            disk_opts = "path={0},device=cdrom,readonly=on,shareable=on".format(self._iso.iso_path)
            args.append("--disk")
            args.append(disk_opts)

        if self._ks_paths:
            extra_args = "ks=file:/{0}".format(os.path.basename(self._ks_paths[0]))
        else:
            extra_args = ""
        if not self._vnc:
            extra_args += " inst.cmdline"
        if self._kernel_args:
            extra_args += " " + self._kernel_args
        if self._iso.stage2:
            extra_args += " stage2=hd:CDLABEL={0}".format(udev_escape(self._iso.label))

        if self._boot:
            # eg booting from ipxe to emulate ibft firmware
            args.append("--boot")
            args.append(self._boot)
        else:
            args.append("--extra-args")
            args.append(extra_args)

            args.append("--location")
            args.append(self._iso.mount_dir)

        channel_args = "tcp,host={0}:{1},mode=connect,target_type=virtio" \
                       ",name=org.fedoraproject.anaconda.log.0".format(
                       self._virtio_host, self._virtio_port)
        args.append("--channel")
        args.append(channel_args)

        log.info("Running virt-install.")
        log.info("virt-install %s", args)
        try:
            execWithRedirect("virt-install", args, raise_err=True)
        except subprocess.CalledProcessError as e:
            raise InstallError("Problem starting virtual install: %s" % e)

        conn = libvirt.openReadOnly(None)
        dom = conn.lookupByName(self._virt_name)

        # TODO: If vnc has been passed, we should look up the port and print that
        # for the user at this point
        while dom.isActive() and not self._log_check():
            sys.stdout.write(".")
            sys.stdout.flush()
            sleep(10)
        print()

        if self._log_check():
            log.info("Installation error detected. See logfile.")
        else:
            log.info("Install finished. Or at least virt shut down.")

    def destroy(self, pool_name):
        """
        Make sure the virt has been shut down and destroyed

        Could use libvirt for this instead.
        """
        log.info("Shutting down %s", self._virt_name)
        subprocess.run(["virsh", "destroy", self._virt_name])
        subprocess.run(["virsh", "undefine", self._virt_name])
        subprocess.run(["virsh", "pool-destroy", pool_name])
        subprocess.run(["virsh", "pool-undefine", pool_name])


class VirtualManager(object):

    def __init__(self, virtual_configuration: VirtualConfiguration):
        super().__init__()
        self._conf = virtual_configuration

        self._install_log = os.path.join(self._conf.temp_dir, "virt-install.log")

    def _start_virt_install(self, install_log):
        """
        Use virt-install to install to a disk image

        :param str install_log: The path to write the log from virt-install

        This uses virt-install with a boot.iso and a kickstart to create a disk
        image.
        """
        iso_mount = IsoMountpoint(self._conf.iso_path, self._conf.location)
        log_monitor = LogMonitor(install_log, timeout=self._conf.timeout)

        kernel_args = ""
        if self._conf.kernel_args:
            kernel_args += self._conf.kernel_args
        if self._conf.proxy:
            kernel_args += " proxy=" + self._conf.proxy

        try:
            virt = VirtualInstall(iso_mount, self._conf.ks_paths,
                                  disk_paths=self._conf.disk_paths,
                                  kernel_args=kernel_args,
                                  memory=self._conf.ram,
                                  vnc=self._conf.vnc,
                                  log_check = log_monitor.server.log_check,
                                  virtio_host = log_monitor.host,
                                  virtio_port = log_monitor.port,
                                  nics=self._conf.networks,
                                  boot=self._conf.boot_image)

            virt.destroy(os.path.basename(self._conf.temp_dir))
            log_monitor.shutdown()
        except InstallError as e:
            log.error("VirtualInstall failed: %s", e)
            raise
        finally:
            log.info("unmounting the iso")
            iso_mount.umount()

        if log_monitor.server.log_check():
            if not log_monitor.server.error_line and self._conf.timeout:
                msg = "virt_install failed due to timeout"
            else:
                msg = "virt_install failed on line: %s" % log_monitor.server.error_line
            raise InstallError(msg)

    def _prepare_and_run(self):
        """
        Install to a disk image

        Use virt-install or anaconda to install to a disk image.
        """
        try:
            install_log = os.path.abspath(os.path.dirname(self._conf.log_path))+"/virt-install.log"
            log.info("install_log = %s", install_log)

            self._start_virt_install(install_log)
        except InstallError as e:
            log.error("Install failed: %s", e)

            if not self._conf.keep_image:
                log.info("Removing bad disk image")

                for image in self._conf.disk_paths:
                    if os.path.exists(image):
                        os.unlink(image)

            raise

        log.info("Disk Image install successful")

    def run(self):
        setup_logging(self._conf.log_path, log)

        log.debug(VirtualConfiguration)

        # Check for invalid combinations of options, print all the errors and exit.
        errors = self._check_setup()
        if errors:
            list(log.error(e) for e in errors)
            return False

        tempfile.tempdir = self._conf.temp_dir

        # Make the image.
        try:
            self._prepare_and_run()
        except InstallError as e:
            log.error("ERROR: Image creation failed: %s", e)
            return False

        self._create_human_log()

        log.info("SUMMARY")
        log.info("-------")
        log.info("Logs are in %s", os.path.abspath(os.path.dirname(self._conf.log_path)))
        log.info("Disk image(s) at %s", ",".join(self._conf.disk_paths))
        log.info("Results are in %s", self._conf.temp_dir)

        return True

    def _create_human_log(self):
        output_log = os.path.join(self._conf.temp_dir, "virt-install-human.log")
        with open(self._install_log, 'rt') as in_file:
            with open(output_log, 'wt') as out_file:
                for line in in_file:
                    line = replace_new_lines(line)
                    out_file.write(line)

    def _check_setup(self):
        errors = []

        if self._conf.ks_paths and not os.path.exists(self._conf.ks_paths[0]):
            errors.append("kickstart file (%s) is missing." % self._conf.ks_paths[0])

        if self._conf.iso_path and not os.path.exists(self._conf.iso_path):
            errors.append("The iso %s is missing." % self._conf.iso_path)

        if not self._conf.iso_path:
            errors.append("virt install needs an install iso.")

        if not os.path.exists("/usr/bin/virt-install"):
            errors.append("virt-install needs to be installed.")

        if os.getuid() != 0:
            errors.append("You need to run this as root")

        return errors
