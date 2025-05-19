#!/bin/bash
set -eux

# Add the 8021q module to autoload for VLAN support
grep -q 8021q /etc/modules || sed -i '1i8021q' /etc/modules
