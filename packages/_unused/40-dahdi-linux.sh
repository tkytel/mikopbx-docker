#!/bin/bash
set -eux

LIB_VERSION='3.1.0'
LIB_URL="https://github.com/asterisk/dahdi-linux/releases/download/v${LIB_VERSION}/dahdi-linux-${LIB_VERSION}.tar.gz"
srcDirName=$(downloadFile "$LIB_URL")
pushd "$srcDirName"

make all
make install
insmod "$(modinfo dahdi | grep filename | awk -F' ' '$0=$2')"
insmod "$(modinfo dahdi_transcode | grep filename | awk -F' ' '$0=$2')"

popd
rm -rf "$srcDirName" ./zephir
