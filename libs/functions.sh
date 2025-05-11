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
downloadFile() {
  extensionUrl="$1"
  curl -LO "$extensionUrl"
  arName=$(basename "$extensionUrl")
  srcDirName=$(tar -tf "${PWD}/${arName}" | cut -f 1 -d '/' | sort -u | grep -v package.xml)
  tar xzf "${PWD}/${arName}" && rm "$_"
  realpath "$srcDirName"
}

installPhpExtension() {
  extensionName="$1"
  extensionUrl="$2"
  extensionPriority="$3"
  extensionPrefix="$4"
  extensionConfOpt="$5"

  srcDirName=$(downloadFile "$extensionUrl")
  makePhpExtension "${srcDirName}" "$extensionConfOpt"
  enablePhpExtension "$extensionName" "$extensionPriority" "$extensionPrefix"
  rm -rf "${srcDirName}"
}

enablePhpExtension() {
  libFileName="$1"
  priority="$2"
  prefix="$3"

  modDir="/etc/php/$PHP_VERSION/mods-available"
  if [ ! -d "$modDir" ]; then
    realModDir='/etc/php.d'
    mkdir -p "$realModDir"
  else
    realModDir=$modDir
  fi
  echo "${prefix}extension=${libFileName}.so" >"/tmp/${libFileName}.ini"
  mv "/tmp/${libFileName}.ini" "${realModDir}/${libFileName}.ini"
  if [ ! -d "$modDir" ]; then
    return
  fi

  rm -rf "/etc/php/$PHP_VERSION/fpm/conf.d/${priority}-${libFileName}.ini" "/etc/php/$PHP_VERSION/cli/conf.d/${priority}-${libFileName}.ini"
  links="$(find "/etc/php/$PHP_VERSION/cli/" -lname "/etc/php/$PHP_VERSION/mods-available/${libFileName}.ini")"
  if [ 'x' = "${links}x" ]; then
    ln -s "/etc/php/$PHP_VERSION/mods-available/${libFileName}.ini" "/etc/php/$PHP_VERSION/fpm/conf.d/${priority}-${libFileName}.ini"
    ln -s "/etc/php/$PHP_VERSION/mods-available/${libFileName}.ini" "/etc/php/$PHP_VERSION/cli/conf.d/${priority}-${libFileName}.ini"
  fi
}

makePhpExtension() {
  srcDirName="$1"
  confOptions="$2"
  pushd "$srcDirName"

  ${SUDO_CMD} phpize
  ${SUDO_CMD} ./configure "$confOptions"
  ${SUDO_CMD} make
  ${SUDO_CMD} make install

  popd
}

export makePhpExtension enablePhpExtension installPhpExtension
