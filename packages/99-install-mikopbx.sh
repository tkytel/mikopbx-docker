#!/bin/bash
set -eux

if [[ -z $MIKO_PBX_VERSION ]]; then
  MIKO_PBX_VERSION='dev-develop'
fi

honeDir='/home/www'
wwwDir='/usr/www'

id -u www &>/dev/null || useradd www

mkdir -p "$honeDir" && chown www:www "$honeDir"
mkdir -p "$wwwDir" && chown www:www "$wwwDir"

pushd "$wwwDir"

su www -c "composer require mikopbx/core:${MIKO_PBX_VERSION}"
echo "${MIKO_PBX_VERSION}" >/etc/version
busybox touch /etc/version.buildtime
mv "$wwwDir/vendor/mikopbx/core/"* "$wwwDir/"
su www -c 'composer update'

echo "Installing gnatsd ..."
chmod +x "$wwwDir/resources/rootfs/usr/sbin/gnatsd"
ln -s "$wwwDir/resources/rootfs/usr/sbin/gnatsd" /usr/sbin/gnatsd

rm -rf /etc/php.ini /etc/php.d/ /etc/nginx/ /etc/php-fpm.conf /etc/php-www.conf
ln -s "$wwwDir/resources/rootfs/etc/nginx" /etc/nginx
ln -s "$wwwDir/resources/rootfs/etc/php.d" /etc/php.d
ln -s "$wwwDir/resources/rootfs/etc/php.ini" /etc/php.ini
ln -s "$wwwDir/resources/rootfs/etc/php-fpm.conf" /etc/php-fpm.conf
ln -s "$wwwDir/resources/rootfs/etc/php-www.conf" /etc/php-www.conf

mkdir -p /cf/conf/
chown -R www:www /cf
cp "$wwwDir/resources/db/mikopbx.db" /cf/conf/mikopbx.db

chown -R asterisk:asterisk /etc/asterisk
mkdir -p /offload/rootfs/usr/www/ /offload/asterisk/
ln -s /usr/lib/asterisk/modules/ /offload/asterisk/modules
ln -s /var/lib/asterisk/documentation/ /offload/asterisk/documentation
ln -s /var/lib/asterisk/moh/ /offload/asterisk/moh
mkdir -p /var/asterisk/run
chown -R asterisk:asterisk /var/asterisk/run

ln -s "$wwwDir/config" /etc/inc
if [[ -e "$wwwDir/src/Core/Rc" ]]; then
  ln -s "$wwwDir/src/Core/Rc" /etc/rc
  chmod +x -R /etc/rc
  chmod +x /etc/rc/debian/*
  ln -s /etc/rc/debian/mikopbx.sh /etc/init.d/mikopbx
  ln -s /etc/rc/debian/mikopbx_iptables /etc/init.d/mikopbx-iptables
fi
if [[ -e "$wwwDir/src/Core/System/RootFS/etc/rc/" ]]; then
  ln -s "$wwwDir/src/Core/System/RootFS/etc/rc" /etc/rc
  chmod +x -R /etc/rc
  chmod +x /etc/rc/debian/*
  ln -s /etc/rc/debian/mikopbx.sh /etc/init.d/mikopbx
  ln -s /etc/rc/debian/mikopbx_iptables /etc/init.d/mikopbx-iptables
fi
if ! [[ -e /etc/rc ]]; then
  echo 'rc directory is missing.' >&1
  exit 1
fi

chown -R www:www /offload

mkdir -p /storage/usbdisk1 /storage/usbdisk1/mikopbx/media/moh /offload/asterisk/firmware/iax
cp "$wwwDir/resources/sounds/moh/"* /storage/usbdisk1/mikopbx/media/moh/

extensionDir="$(php -i | grep '^extension_dir' | cut -d ' ' -f 3)"
ln -s "$wwwDir/resources/rootfs/usr/lib64/extensions/no-debug-zts-20190902/mikopbx.so" "$extensionDir/mikopbx.so"
ln -s "$wwwDir/resources/sounds" /offload/asterisk/sounds

if [[ -e "$wwwDir/resources/rootfs/sbin/" ]]; then
  chmod +x "$wwwDir/resources/rootfs/sbin/"*
  ln -s "$wwwDir/resources/rootfs/sbin/wav2mp3.sh" /sbin/wav2mp3.sh
  ln -s "$wwwDir/resources/rootfs/sbin/crash_asterisk" /sbin/crash_asterisk
fi
if [[ -e "$wwwDir/src/Core/System/RootFS/sbin/" ]]; then
  chmod +x "$wwwDir/src/Core/System/RootFS/sbin/"*
  ln -s "$wwwDir/src/Core/System/RootFS/sbin/wav2mp3.sh" /sbin/wav2mp3.sh
  ln -s "$wwwDir/src/Core/System/RootFS/sbin/crash_asterisk" /sbin/crash_asterisk
fi

if command -v systemctl &>/dev/null; then
  ln -s /etc/rc/debian/mikopbx_lan_dhcp /etc/dhcp/dhclient-enter-hooks.d/mikopbx_lan_dhcp
  update-rc.d mikopbx defaults
  systemctl restart mikopbx
  update-rc.d mikopbx-iptables defaults
  systemctl disable rsyslog
fi

popd
