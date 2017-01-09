#!/usr/bin/python3

import sys
from pylorax.treebuilder import udev_escape

if len(sys.argv) != 2:
    print("Usage: %s <string>" % sys.argv[0], file=sys.stderr)
    sys.exit(1)

print(udev_escape(sys.argv[1]))
