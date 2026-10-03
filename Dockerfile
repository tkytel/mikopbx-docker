# syntax=docker/dockerfile:1

ARG DEBIAN_CODENAME=trixie
# The official image provides two closed-source binaries that are not built
# from github.com/mikopbx/Core: the "mikopbx" PHP extension and gnatsd
# (patched NATS server with the license API).
ARG MIKOPBX_BINARY_IMAGE=mikopbx/mikopbx:latest

FROM ${MIKOPBX_BINARY_IMAGE}@sha256:91568202da4a7b862447ea000e31ab9a3c96e94e53b45510056b1fb2eba2a2b4 AS mikopbx-binary

# The extension lives in /usr/lib64/extensions on amd64 and in
# /usr/lib/extensions on arm64.
RUN mkdir -p /export \
  && cp "$(find /usr/lib/extensions /usr/lib64/extensions -name mikopbx.so 2>/dev/null | head -n 1)" /export/mikopbx.so \
  && cp /usr/sbin/gnatsd /export/gnatsd

# -----------------------------------------------------------------------------
# MikoPBX Core sources and PHP dependencies
# -----------------------------------------------------------------------------
FROM composer:2@sha256:af98f42dfff7c68ba8d53c2164fd9fde1087b7d449514baa38c418b1f6bc4bac AS core

# Any tag, branch or commit of https://github.com/mikopbx/Core
ARG MIKOPBX_VERSION=2026.3.40
ARG MIKOPBX_REPOSITORY=https://github.com/mikopbx/Core.git
# https://github.com/openresty/lua-resty-redis/tags
ARG LUA_RESTY_REDIS_VERSION=0.33

WORKDIR /usr/www
RUN <<EOF
set -eux
git init -q .
git remote add origin "$MIKOPBX_REPOSITORY"
git fetch -q --depth 1 origin "$MIKOPBX_VERSION"
git checkout -q FETCH_HEAD
composer install --no-dev --no-interaction --no-progress --optimize-autoloader --ignore-platform-reqs
mkdir -p /tmp/resources /tmp/lua/resty
mv resources/* /tmp/resources/
find . -mindepth 1 -maxdepth 1 ! -name src ! -name sites ! -name vendor ! -name composer.json ! -name config.json -exec rm -rf {} +
curl -fsSL -o /tmp/lua/resty/redis.lua \
  "https://raw.githubusercontent.com/openresty/lua-resty-redis/v${LUA_RESTY_REDIS_VERSION}/lib/resty/redis.lua"
EOF

# -----------------------------------------------------------------------------
# PECL extensions not packaged by Debian
# -----------------------------------------------------------------------------
FROM debian:${DEBIAN_CODENAME}@sha256:9cc080028c43b27d2074d63a5f9caf7166d731494965616c1a6d2827a004585c AS php-extensions

ARG PHP_VERSION=8.4
# https://pecl.php.net/package/phalcon (Core requires ^5.9.3)
ARG PHALCON_VERSION=5.9.3

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
RUN <<EOF
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential ca-certificates libevent-dev libssl-dev pkg-config \
  "php${PHP_VERSION}-dev" php-pear
EOF

# GCC 14 turns -Wincompatible-pointer-types into an error, which the C code
# generated for phalcon 5.9 does not pass.
RUN <<EOF
pecl channel-update pecl.php.net
CFLAGS='-O2 -Wno-incompatible-pointer-types' MAKEFLAGS="-j$(nproc)" pecl install "phalcon-${PHALCON_VERSION}"
EOF

RUN <<EOF
{ yes '' || :; } | pecl install ev
pecl install -D 'enable-event-debug="no" enable-event-sockets="yes" with-event-libevent-dir="/usr" with-event-pthreads="no" with-event-extra="yes" with-event-openssl="yes" with-event-ns="no" with-openssl-dir="no"' event
EOF

COPY libs/ /build/libs/
RUN <<EOF
extensionDir="$(php-config --extension-dir)"
for ext in phalcon ev event; do
  install -Dm644 "${extensionDir}/${ext}.so" "/staging${extensionDir}/${ext}.so"
done
source /build/libs/functions.sh
listRuntimePackages /staging >/staging/runtime-packages.txt
EOF

# -----------------------------------------------------------------------------
# Asterisk
# -----------------------------------------------------------------------------
FROM debian:${DEBIAN_CODENAME}@sha256:9cc080028c43b27d2074d63a5f9caf7166d731494965616c1a6d2827a004585c AS asterisk

# https://github.com/asterisk/asterisk/releases
ARG ASTERISK_VERSION=22.8.2
# https://github.com/deepfryed/beanstalk-client/tags
ARG BEANSTALK_CLIENT_VERSION=1.3.0

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
RUN <<EOF
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  autoconf automake build-essential bzip2 ca-certificates curl file libtool patch pkg-config python3 subversion \
  libcurl4-openssl-dev libedit-dev libgsm1-dev libjansson-dev liblua5.4-dev libncurses-dev \
  libogg-dev libopus-dev libopusfile-dev libpopt-dev libspandsp-dev libspeex-dev libspeexdsp-dev \
  libsqlite3-dev libsrtp2-dev libssl-dev libunbound-dev libvorbis-dev libxml2-dev libxslt1-dev uuid-dev
EOF

COPY libs/ /build/libs/
COPY packages/41-asterisk.sh /build/packages/
WORKDIR /build/src
RUN <<EOF
DESTDIR=/staging ASTERISK_VERSION="$ASTERISK_VERSION" BEANSTALK_CLIENT_VERSION="$BEANSTALK_CLIENT_VERSION" \
  /build/packages/41-asterisk.sh
source /build/libs/functions.sh
listRuntimePackages /staging >/staging/runtime-packages.txt
EOF

# /var/run is a symlink to /run on Debian; do not let COPY replace it.
RUN rm -rf /staging/var/run /staging/usr/include /staging/usr/share/man

# -----------------------------------------------------------------------------
# BusyBox with all applets: MikoPBX runs "busybox nohup", "busybox lsof", ...
# which Debian's busybox package does not include.
# -----------------------------------------------------------------------------
FROM debian:${DEBIAN_CODENAME}@sha256:9cc080028c43b27d2074d63a5f9caf7166d731494965616c1a6d2827a004585c AS busybox

# https://busybox.net/downloads/
ARG BUSYBOX_VERSION=1.38.0

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
RUN <<EOF
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends build-essential bzip2 ca-certificates curl
EOF

WORKDIR /build/src
RUN <<EOF
curl -fsSL "https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2" | tar xj --strip-components=1
make defconfig
# tc does not build against recent kernel headers and MikoPBX does not use it.
sed -i 's/^CONFIG_TC=y$/# CONFIG_TC is not set/' .config
make -j"$(nproc)"
install -Dm755 busybox /staging/usr/bin/busybox
EOF

# -----------------------------------------------------------------------------
# MikoPBX
# -----------------------------------------------------------------------------
FROM debian:${DEBIAN_CODENAME}-slim@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a

ARG PHP_VERSION=8.4
ARG MIKOPBX_VERSION=2026.3.40

LABEL org.opencontainers.image.description="MikoPBX - a free, open-source PBX with a friendly interface, based on Asterisk."
LABEL org.opencontainers.image.documentation="https://docs.mikopbx.com/mikopbx/english/setup/docker"
LABEL org.opencontainers.image.source="https://github.com/tkytel/mikopbx-docker"
LABEL org.opencontainers.image.title="MikoPBX"
LABEL org.opencontainers.image.url="https://www.mikopbx.com"
LABEL org.opencontainers.image.version="${MIKOPBX_VERSION}"

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

COPY --from=php-extensions /staging/runtime-packages.txt /tmp/php-runtime-packages.txt
COPY --from=asterisk /staging/runtime-packages.txt /tmp/asterisk-runtime-packages.txt

RUN <<EOF
export DEBIAN_FRONTEND=noninteractive
PACKAGES=(
  # Base tools used by MikoPBX
  bash ca-certificates cpio curl e2fsprogs gdisk iproute2 ipset iptables locales logrotate lsof
  mtr-tiny openssl parted pv sqlite3 sysstat tcpdump tzdata xz-utils bzip2
  # PHP
  "php${PHP_VERSION}-cli" "php${PHP_VERSION}-fpm" "php${PHP_VERSION}-opcache"
  "php${PHP_VERSION}-bcmath" "php${PHP_VERSION}-bz2" "php${PHP_VERSION}-curl" "php${PHP_VERSION}-gmp"
  "php${PHP_VERSION}-igbinary" "php${PHP_VERSION}-ldap" "php${PHP_VERSION}-mailparse"
  "php${PHP_VERSION}-mbstring" "php${PHP_VERSION}-msgpack" "php${PHP_VERSION}-redis"
  "php${PHP_VERSION}-sqlite3" "php${PHP_VERSION}-xml" "php${PHP_VERSION}-yaml" "php${PHP_VERSION}-zip"
  # Web server
  nginx libnginx-mod-http-lua libnginx-mod-nchan libnginx-mod-http-headers-more-filter
  # Services managed by MikoPBX
  beanstalkd dnsmasq-base dropbear-bin fail2ban monit msmtp openssh-client redis-server rsyslog
  # Media and diagnostics
  ffmpeg lame mpg123 sngrep sox
)
apt-get update
# shellcheck disable=SC2046
apt-get install -y --no-install-recommends "${PACKAGES[@]}" \
  $(cat /tmp/php-runtime-packages.txt /tmp/asterisk-runtime-packages.txt)
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/*-runtime-packages.txt
EOF

COPY --from=php-extensions /staging/ /
COPY --from=asterisk /staging/ /
COPY --from=busybox /staging/ /
COPY --from=mikopbx-binary /export/gnatsd /usr/sbin/gnatsd
COPY --from=mikopbx-binary /export/mikopbx.so /tmp/mikopbx.so
COPY --from=core /usr/www/ /usr/www/
COPY --from=core /tmp/resources/ /tmp/resources/
COPY --from=core /tmp/lua/ /usr/share/lua/5.1/
COPY rootfs/ /
COPY packages/99-install-mikopbx.sh /tmp/

RUN <<EOF
rm -f /runtime-packages.txt
ldconfig
install -m644 /tmp/mikopbx.so "$(php -n -r 'echo ini_get("extension_dir");')/mikopbx.so"

# BusyBox-compatible user management (see the script for details).
for cmd in adduser addgroup deluser delgroup; do
  if [[ -e /usr/sbin/$cmd ]]; then
    dpkg-divert --local --rename --add "/usr/sbin/$cmd"
  fi
  ln -s /usr/local/lib/mikopbx-docker/busybox-user-tools.sh "/usr/sbin/$cmd"
done

MIKOPBX_VERSION="$MIKOPBX_VERSION" PHP_VERSION="$PHP_VERSION" /tmp/99-install-mikopbx.sh
rm -rf /tmp/*

# Docker creates it, other runtimes do not; MikoPBX uses it to detect containers.
touch /.dockerenv

# Fail the build early if something essential is missing.
php -m | grep -qx phalcon
php -m | grep -qx mikopbx
for lib in /usr/sbin/asterisk /offload/asterisk/modules/*.so "$(php -r 'echo ini_get("extension_dir");')"/*.so; do
  if ldd "$lib" | grep -q 'not found'; then
    ldd "$lib"
    exit 1
  fi
done
nginx -t
rm -f /var/log/nginx_*.log
EOF

ENTRYPOINT ["/usr/local/sbin/mikopbx-docker-entrypoint"]

EXPOSE 80 443 5060/udp 5060/tcp 5038 8088 8089 10000-11000/udp
