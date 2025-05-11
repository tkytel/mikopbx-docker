#!/bin/bash
set -eux

LIB_VERSION='6.2.1'
LIB_URL="https://download.redis.io/releases/redis-${LIB_VERSION}.tar.gz"
srcDirName=$(downloadFile "$LIB_URL")
pushd "$srcDirName"
{
  make PREFIX=/
  make install
} >>"$LOG_FILE" 2>>"$LOG_FILE"
popd

rm -rf "$srcDirName" ./zephir
