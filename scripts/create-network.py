#!/usr/bin/python3
#
# kstest-runner - LMC-like program that only does what's necessary for running
# kickstart-based tests in anaconda
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
# Author(s): Radek Vykydal <rvykydal@redhat.com>
#
# The script takes one argument - name of libvirt network that will be created.
# It looks at existing libvirt subnets in 192.168 range and uses the first
# unassigned /24 subnet (starting from 192.168.100) for the new virtual nated
# network that would be used by a kickstart test.  The script outputs
# "<IP address> <netmask> <gateway IP>", the values that can be substituted
# into kickstart network command for static network configuration.

import libvirt
import sys
import xml.etree.ElementTree as ET

if len(sys.argv) != 2:
    print("Usage: create-network.py <network name>", file=sys.stderr)
    sys.exit(1)

network_name = sys.argv[1]

conn = libvirt.open()

# Look for free 192.168 subnet assuming 255.255.255.0 netmask.
# As 'default' network has.

used_subnets = set()
for network in conn.listAllNetworks():
    network_xml = network.XMLDesc()
    root = ET.fromstring(network_xml)
    for ip in root.iter('ip'):
        used_subnets.add(ip.attrib['address'][:11])

for subnet in range(100, 255):
    if "192.168.%d" % subnet not in used_subnets:
        break
else:
    print("No 192.168 subnet available to create network", file=sys.stderr)
    conn.close()
    sys.exit(1)

network_xml = """
<network>
  <name>{0}</name>
  <forward mode='nat'>
     <nat>
       <port start='1024' end='65535'/>
     </nat>
  </forward>
  <ip address='192.168.{1:d}.1' netmask='255.255.255.0'>
     <dhcp>
     <range start='192.168.{1:d}.2' end='192.168.{1:d}.128'/>
     </dhcp>
  </ip>
</network>
""".format(network_name, subnet)

conn.networkCreateXML(network_xml)
conn.close()

print("192.168.{0:d}.130 255.255.255.0 192.168.{0:d}.1".format(subnet))

sys.exit(0)
