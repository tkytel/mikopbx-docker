#!/bin/bash
# Lay out MikoPBX Core (already copied to /usr/www) on top of Debian the same
# way the official firmware image does.
set -euxo pipefail

: "${MIKOPBX_VERSION:?}"
: "${WWW_UID:?}"
: "${WWW_GID:?}"

wwwDir='/usr/www'
rootFs="$wwwDir/src/Core/System/RootFS"
resources='/tmp/resources'

# Users: MikoPBX runs nginx, php-fpm and dnsmasq as "www".
groupadd -g "$WWW_GID" www
useradd -u "$WWW_UID" -g www -d /tmp -s /bin/bash -c 'Web User' www

# On the official firmware /usr is /offload/rootfs/usr, and Core refers to
# both paths (e.g. /offload/rootfs/usr/www, /offload/rootfs/usr/share/geolite2).
mkdir -p /offload/rootfs/usr
for dir in /usr/*; do
  ln -s "$dir" "/offload/rootfs/usr/$(basename "$dir")"
done

# MikoPBX applies these owner and modes to the core at every boot
# (Storage::applyFolderRights); doing it here keeps the boot from copying every
# file up to the container layer.
find "$wwwDir" -type d -exec chmod 755 {} +
find "$wwwDir" -type f -exec chmod 644 {} +
find "$wwwDir/src/Core/Asterisk/agi-bin" -type f -exec chmod 755 {} +
chown -R www:www "$wwwDir"

# /etc
cp -R "$rootFs/etc/rc" "$rootFs/etc/inc" /etc/
cp -R "$rootFs/etc/php.ini" "$rootFs/etc/php-fpm.conf" "$rootFs/etc/php-www.conf" "$rootFs/etc/profile" /etc/
chmod -R +x /etc/rc

# nginx: Core ships the whole /etc/nginx, but Debian loads dynamic modules
# (lua, nchan, headers-more) from modules-enabled.
mv /etc/nginx/modules-enabled /tmp/nginx-modules-enabled
rm -rf /etc/nginx
cp -R "$rootFs/etc/nginx" /etc/nginx
mv /tmp/nginx-modules-enabled /etc/nginx/modules-enabled
# Debian's nginx is built with --error-log-path=stderr, so without a main-level
# error_log the daemon keeps the caller's stderr open and MikoPBX, which waits
# for the output of "nginx", hangs at boot.
sed -i '1i include /etc/nginx/modules-enabled/*.conf;\nerror_log /var/log/nginx_error.log;' /etc/nginx/nginx.conf

# PHP is built with Core's layout: /etc/php.ini, /etc/php.d and /etc/php-fpm.conf.
mkdir -p /etc/php.d /var/lib/php/session
chown www:www /var/lib/php/session
cp -R "$rootFs/etc/php.d/." /etc/php.d/

# Rootless Docker cannot apply its AppArmor profile, so a host profile attached
# to /usr/sbin/rsyslogd (Ubuntu ships one) confines the container's rsyslogd and
# denies writing to /storage. Keep the binary under another path.
dpkg-divert --local --rename --divert /usr/sbin/rsyslogd.distrib --add /usr/sbin/rsyslogd
ln -s rsyslogd.distrib /usr/sbin/rsyslogd

# fail2ban: Core generates its own jails; Debian's default sshd jail needs systemd.
rm -f /etc/fail2ban/jail.d/defaults-debian.conf

# /sbin helpers (Debian's /sbin is /usr/sbin).
for f in "$rootFs/sbin/"*; do
  install -m755 "$f" "/usr/sbin/$(basename "$f")"
done

# /bin/sh is BusyBox ash on the official firmware. Core runs every command
# through a /bin/sh snippet that closes inherited descriptors with
# "exec 12>&-", which dash cannot parse (it takes single-digit descriptors only).
dpkg-divert --local --rename --divert /usr/bin/sh.distrib --add /usr/bin/sh
ln -s busybox /usr/bin/sh

# BusyBox applets Core calls directly from shell scripts.
ln -sf /bin/busybox /usr/bin/ps
for applet in ifconfig route ping arp nslookup udhcpc udhcpc6 syslogd logread crond killall vconfig; do
  if ! command -v "$applet" >/dev/null; then
    ln -s /bin/busybox "/usr/sbin/$applet"
  fi
done

# Locales MikoPBX generates at boot when they are missing.
for locale in en_US en_GB ru_RU; do
  localedef -i "$locale" -f UTF-8 "$locale.UTF-8"
done

# Default configuration DB, sounds and other read-only resources.
install -Dm644 "$resources/db/mikopbx.db" /conf.default/mikopbx.db
mkdir -p /offload/asterisk
cp -a "$resources/sounds-base" /offload/asterisk/sounds-base
cp -an "$resources/rootfs/usr/share/." /usr/share/

# Asterisk: MikoPBX keeps its data under /offload/asterisk.
for dir in /var/lib/asterisk/*; do
  mv "$dir" /offload/asterisk/
done
rm -rf /var/lib/asterisk
ln -s /offload/asterisk /var/lib/asterisk
mv /usr/lib/asterisk/modules /offload/asterisk/modules
ln -s /offload/asterisk/modules /usr/lib/asterisk/modules
mkdir -p /offload/asterisk/{agi-bin,firmware/iax,log,moh,run,sounds,spool,third-party} /var/asterisk/run
rm -rf /etc/asterisk
mkdir -p /etc/asterisk

echo "$MIKOPBX_VERSION" >/etc/version
date -u '+%Y-%m-%d %H:%M:%S' >/etc/version.buildtime
cp /etc/version.buildtime /offload/version.buildtime
