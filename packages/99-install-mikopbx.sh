#!/bin/bash
set -eux

if [[ -z $MIKO_PBX_VERSION ]]; then
  # https://github.com/mikopbx/Core/tree/5b15f5da681816858b7d0165d8b551d5155f0795
  MIKO_PBX_VERSION='dev-develop#5b15f5da681816858b7d0165d8b551d5155f0795'
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

# TODO: remove after merged https://github.com/mikopbx/Core/pull/893
grep -lr '/usr/bin/php' "$wwwDir/src/" | xargs sed -r -i 's;/usr/bin/php( -f)?;/usr/bin/env -S php -f;'

rm -rf /etc/php.ini /etc/nginx/ /etc/php-fpm.conf /etc/php-www.conf
mkdir -p /etc/php.d
for etc_path in "$wwwDir/resources/rootfs/etc" "$wwwDir/src/Core/System/RootFS/etc"; do
  if ! [[ -e $etc_path ]]; then
    continue
  fi
  for i in /usr/local/etc/php/conf.d/*.ini; do
    ln -s "$i" "/etc/php.d/00-$(basename "$i")"
  done
  ln -s "$etc_path/nginx" /etc/nginx

  ln -s "$etc_path/php.d/10-opcache.ini" /etc/php.d/10-opcache.ini
  ln -s "$etc_path/php.d/15-ev.ini" /etc/php.d/15-ev.ini

  # FIXME: https://github.com/mikopbx/Core/issues/892
  sed -i 's!extension=mikopbx.so!# &!' "$etc_path/php.d/50-mikopbx.ini"
  ln -s "$etc_path/php.d/50-mikopbx.ini" /etc/php.d/99-mikopbx.ini

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

mkdir -p /cf/conf/ /conf.default/
chown -R www:www /cf /conf.default
ln -s "$wwwDir/resources/db/mikopbx.db" /cf/conf/
ln -s "$wwwDir/resources/db/mikopbx.db" /conf.default/

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
