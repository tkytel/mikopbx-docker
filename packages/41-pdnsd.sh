#!/bin/bash
set -eux

LIB_VERSION='1.2.9a-par'
LIB_URL="https://cloudfront.debian.net/debian-archive/debian/pool/main/p/pdnsd/pdnsd_${LIB_VERSION}.orig.tar.gz"
srcDirName=$(downloadFile "$LIB_URL")
pushd "$srcDirName"
{
  ./configure
  make
  make install
} >>"$LOG_FILE" 2>>"$LOG_FILE"
popd

rm -rf "$srcDirName"
