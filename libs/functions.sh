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

# downloadFile URL SHA256: download and verify a tarball, extract it, and print
# the extracted directory.
downloadFile() {
  extensionUrl="$1"
  curl -fsSLO "$extensionUrl"
  arName=$(basename "$extensionUrl")
  echo "$2  $arName" | sha256sum -c - >&2
  srcDirName="$(
    tar -tf "${PWD}/${arName}" |
      cut -f 1 -d '/' |
      sort -u |
      grep -v package.xml
  )"
  tar xzf "${PWD}/${arName}" && rm "$_"
  realpath "$srcDirName"
}

# downloadPecl NAME-VERSION SHA256: download and verify a PECL package and print
# its path. "pecl install NAME-VERSION" resolves through PECL's REST metadata,
# which it cannot read for some packages (ev: "does not have REST xml available").
downloadPecl() {
  local file="/tmp/$1.tgz"
  curl -fsSL -o "$file" "https://pecl.php.net/get/$1.tgz"
  echo "$2  $file" | sha256sum -c - >&2
  echo "$file"
}

# Print Debian packages providing the shared libraries that ELF files under the
# given directory are linked against. Used to install only runtime libraries
# into the final image.
listRuntimePackages() {
  local root="$1"
  find "$root" -type f \( -name '*.so*' -o -perm -u+x \) -print0 |
    { xargs -0 -r env LD_LIBRARY_PATH="${root}/usr/lib" ldd 2>/dev/null || :; } |
    awk -v root="${root}/" '$2 == "=>" && $3 ~ /^\// && index($3, root) != 1 {print $3}' |
    sort -u |
    xargs -r realpath |
    { xargs -r dpkg -S 2>/dev/null || :; } |
    grep -v '^diversion' |
    cut -d: -f1 |
    sort -u
}
