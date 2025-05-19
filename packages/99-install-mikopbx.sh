#!/bin/bash
set -eux

if [[ -z $MIKO_PBX_VERSION ]]; then
  # https://github.com/mikopbx/Core/tree/fd4f4b622306a8dd1cb82c9ea5bcd4a16eb6b79a
  MIKO_PBX_VERSION='dev-develop#fd4f4b622306a8dd1cb82c9ea5bcd4a16eb6b79a'
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

mkdir -p /offload/rootfs/usr/www/
ln -s "$wwwDir/src/" /offload/rootfs/usr/www/src

rm -rf /etc/php.ini /etc/php.d/ /etc/nginx/ /etc/php-fpm.conf /etc/php-www.conf
for etc_path in "$wwwDir/resources/rootfs/etc" "$wwwDir/src/Core/System/RootFS/etc"; do
  if ! [[ -e $etc_path ]]; then
    continue
  fi
  ln -s "$etc_path/nginx" /etc/nginx
  ln -s "$etc_path/php.d" /etc/php.d
  ln -s "$etc_path/php.ini" /etc/php.ini
  ln -s "$etc_path/php-fpm.conf" /etc/php-fpm.conf
  ln -s "$etc_path/php-www.conf" /etc/php-www.conf
  break
done
if ! ls /etc/{nginx,php.d,php.ini,php-fpm.conf,php-www.conf} 1>/dev/null; then
  echo 'etc files are missing.' >&1
  exit 1
fi

for config_path in "$wwwDir/config" "$wwwDir/src/Core/System/RootFS/etc/inc"; do
  if ! [[ -e $config_path ]]; then
    continue
  fi
  ln -s "$config_path" /etc/inc
  break
done
if ! [[ -e $config_path ]]; then
  echo 'inc dir is missing.' >&1
  exit 1
fi

mkdir -p /cf/conf/
chown -R www:www /cf
cp "$wwwDir/resources/db/mikopbx.db" /cf/conf/mikopbx.db

chown -R asterisk:asterisk /etc/asterisk
mkdir -p /offload/asterisk/
ln -s /usr/lib/asterisk/modules/ /offload/asterisk/modules
ln -s /var/lib/asterisk/documentation/ /offload/asterisk/documentation
ln -s /var/lib/asterisk/moh/ /offload/asterisk/moh
mkdir -p /var/asterisk/run
chown -R asterisk:asterisk /var/asterisk/run

for rc_path in "$wwwDir/src/Core/Rc" "$wwwDir/src/Core/System/RootFS/etc/rc"; do
  if ! [[ -e $rc_path ]]; then
    continue
  fi
  ln -s "$rc_path" /etc/rc
  chmod +x -R /etc/rc
  chmod +x /etc/rc/debian/*
  ln -s /etc/rc/debian/mikopbx.sh /etc/init.d/mikopbx
  ln -s /etc/rc/debian/mikopbx_iptables /etc/init.d/mikopbx-iptables
  break
done
if ! [[ -e /etc/rc ]]; then
  echo 'rc directory is missing.' >&1
  exit 1
fi

chown -R www:www /offload

mkdir -p /storage/usbdisk1 /storage/usbdisk1/mikopbx/media/moh /offload/asterisk/firmware/iax
cp "$wwwDir/resources/sounds/moh/"* /storage/usbdisk1/mikopbx/media/moh/
ln -s "$wwwDir/resources/sounds" /offload/asterisk/sounds

mikopbx_prebuilt_dir="$(find "/usr/www/resources/rootfs/usr/lib64/extensions" -type d -name 'no-debug-non-zts-*' -exec echo {} \; | sort -V | tail -1)"
mikopbx_extension_dir="$(php -i | grep -m1 '^extension_dir' | cut -d ' ' -f 3 || :)"
mkdir -p "$mikopbx_extension_dir"

case "$TARGETPLATFORM" in
"linux/amd64") ln -s "$mikopbx_prebuilt_dir/mikopbx.so" "$mikopbx_extension_dir/mikopbx.so" ;;
"linux/arm64") ln -s "$mikopbx_prebuilt_dir/mikopbx-arm.so" "$mikopbx_extension_dir/mikopbx.so" ;;
*)
  echo "unsupported platform '$TARGETPLATFORM'" >&1
  exit 1
  ;;
esac

for sbin_path in "$wwwDir/resources/rootfs/sbin" "$wwwDir/src/Core/System/RootFS/sbin"; do
  if ! [[ -e $sbin_path ]]; then
    continue
  fi
  chmod +x "$sbin_path/"*
  ln -sf "$sbin_path/"* /sbin/
  break
done

popd
