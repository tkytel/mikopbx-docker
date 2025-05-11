#!/bin/bash
#
# MikoPBX - free phone system for small business
# Copyright © 2017-2021 Alexey Portnov and Nikolay Beketov
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program.
# If not, see <https://www.gnu.org/licenses/>.
#
set -eux

usage() {
cat <<EOF
$0: a script to install distribution-specific prerequirement
Usage: $0:                    Shows this message.
Usage: $0 install             Really install.
EOF
}

PACKAGES_DEBIAN=(
  # Basic build system:
  curl dialog dropbear build-essential pkg-config
  # Asterisk: basic requirements:
  libedit-dev libjansson-dev libsqlite3-dev uuid-dev libxml2-dev
  # Asterisk: for addons:
  libspeex-dev libspeexdsp-dev libogg-dev libvorbis-dev libasound2-dev portaudio19-dev libcurl4-openssl-dev xmlstarlet bison flex
  libpq-dev unixodbc-dev libneon27-dev libgmime-2.6-dev liblua5.2-dev liburiparser-dev libxslt1-dev libssl-dev
  libbluetooth-dev libradcli-dev freetds-dev libosptk-dev libjack-jackd2-dev bash
  libsnmp-dev libiksemel-dev libcorosync-common-dev libcpg-dev libcfg-dev libnewt-dev libpopt-dev libical-dev libspandsp-dev
  libresample1-dev libc-client2007e-dev binutils-dev libsrtp2-dev libsrtp2-dev libgsm1-dev doxygen graphviz zlib1g-dev libldap2-dev
  libcodec2-dev libfftw3-dev libsndfile1-dev libunbound-dev
  # Asterisk: for the unpackaged below:
  wget subversion p7zip-full open-vm-tools sysstat dahdi-linux sox
  bzip2 patch python-dev vlan git ntp sqlite3 curl w3m re2c lame libbz2-dev libgmp-dev libzip-dev
  fail2ban sngrep tcpdump msmtp beanstalkd lua5.1-dev liblua5.1-0 libtonezone-dev libevent-dev libyaml-dev
)

# The distributions we do support:
if [[ -r /etc/debian_version ]]; then
  apt-get install -y "${PACKAGES_DEBIAN[@]}"
  apt-get clean
  rm -rf /var/lib/apt/lists/*
else
  echo >&2 "$0: Only Debian is supported. Aborting."
  exit 1
fi

echo
echo "## $1 completed successfully"
echo "####################################################"
