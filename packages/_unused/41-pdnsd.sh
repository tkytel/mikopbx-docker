#!/bin/bash
set -eux

LIB_VERSION='1.2.9a-par-2'
LIB_URL="https://cloudfront.debian.net/debian-archive/debian/pool/main/p/pdnsd/pdnsd_${LIB_VERSION}_$(dpkg --print-architecture).deb"
srcDirName=$(downloadFile "$LIB_URL")
pushd "$srcDirName"

./configure
make
make install

popd

rm -rf "$srcDirName"
