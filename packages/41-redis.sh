#!/bin/bash
set -eux

LIB_VERSION='6.2.1'
LIB_URL="https://download.redis.io/releases/redis-${LIB_VERSION}.tar.gz"
srcDirName=$(downloadFile "$LIB_URL")
pushd "$srcDirName"

make -j"$(nproc)" PREFIX=/
make install

popd

rm -rf "$srcDirName" ./zephir
