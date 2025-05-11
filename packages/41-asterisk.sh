#!/bin/bash
set -eux

# https://github.com/asterisk/asterisk/releases
LIB_VERSION='16.30.1'
LIB_URL="https://github.com/asterisk/asterisk/releases/download/${LIB_VERSION}/asterisk-${LIB_VERSION}.tar.gz"
LIB_NAME='asterisk'
srcDirName=$(downloadFile "$LIB_URL")
pushd "$srcDirName"

ROOT_DIR="$(realpath "$(dirname "$0")")"
PATCH_PATH="$ROOT_DIR/patches/${LIB_NAME}"
if [ -d "$PATCH_PATH" ]; then
  for filename in "$PATCH_PATH"/*.patch; do
    [ -e "$filename" ] || continue
    echo "Starting $filename"
    (
      patch -p1 -i "$filename"
    )
  done
fi
contrib/scripts/get_mp3_source.sh
# contrib/scripts/install_prereq install
./configure
make menuselect.makeopts
menuselect/menuselect --enable app_meetme \
  --enable format_mp3 \
  --enable res_fax \
  --enable app_macro \
  --enable codec_opus \
  --enable codec_silk \
  --enable codec_siren7 \
  --enable codec_siren14 \
  --enable codec_g729a \
  --enable CORE-SOUNDS-RU-ALAW \
  --enable CORE-SOUNDS-EN-ULAW menuselect.makeopts
adduser --system --group --home /var/lib/asterisk --no-create-home --disabled-password --gecos "MIKO PBX" asterisk
make -j"$(nproc)"
make install
make config
mkdir -p /storage/usbdisk1/mikopbx/persistence \
  /storage/usbdisk1/mikopbx/astlogs/asterisk \
  /storage/usbdisk1/mikopbx/voicemailarchive \
  /storage/usbdisk1/mikopbx/log/asterisk/
chown -R asterisk:asterisk /storage/usbdisk1/mikopbx/persistence \
  /storage/usbdisk1/mikopbx/astlogs/asterisk \
  /storage/usbdisk1/mikopbx/voicemailarchive \
  /storage/usbdisk1/mikopbx/log/asterisk/ \
  /etc/asterisk \
  /var/lib/asterisk \
  /var/spool/asterisk \
  /var/log/asterisk
popd
rm -rf "$srcDirName" ./zephir
