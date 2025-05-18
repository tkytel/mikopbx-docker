#!/bin/bash
set -eux

# https://github.com/asterisk/asterisk/releases
LIB_VERSION='16.30.1'
LIB_URL="https://github.com/asterisk/asterisk/releases/download/${LIB_VERSION}/asterisk-${LIB_VERSION}.tar.gz"
srcDirName=$(downloadFile "$LIB_URL")

pushd "$srcDirName"

contrib/scripts/get_mp3_source.sh
./configure
make menuselect.makeopts
case "$(dpkg --print-architecture)" in
amd64)
  menuselect/menuselect \
    --enable app_meetme \
    --enable format_mp3 \
    --enable res_fax \
    --enable app_macro \
    --enable codec_opus \
    --enable codec_silk \
    --enable codec_siren7 \
    --enable codec_siren14 \
    --enable codec_g729a \
    --enable CORE-SOUNDS-RU-ALAW \
    --enable CORE-SOUNDS-EN-ULAW \
    menuselect.makeopts
  ;;
*)
  menuselect/menuselect \
    --enable app_meetme \
    --enable format_mp3 \
    --enable res_fax \
    --enable app_macro \
    --enable CORE-SOUNDS-RU-ALAW \
    --enable CORE-SOUNDS-EN-ULAW \
    menuselect.makeopts
  ;;
esac
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
