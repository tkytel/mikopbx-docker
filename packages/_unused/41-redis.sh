#!/bin/bash
set -eux

# https://github.com/redis/redis/releases
LIB_VERSION='6.2.18'
LIB_URL="https://download.redis.io/releases/redis-${LIB_VERSION}.tar.gz"
srcDirName=$(downloadFile "$LIB_URL")
pushd "$srcDirName"

make -j"$(nproc)" PREFIX=/
make install

popd

rm -rf "$srcDirName" ./zephir
