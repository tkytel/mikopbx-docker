FROM golang:bookworm AS gnatsd-builder

WORKDIR /work
RUN go install github.com/nats-io/gnatsd@latest
RUN mv "$(which gnatsd)" ./

ARG PHP_VERSION
ARG DEBIAN_CODENAME
FROM php:${PHP_VERSION:-8.3}-rc-fpm-${DEBIAN_CODENAME:-bookworm} AS builder
ENV PHP_VERSION=${PHP_VERSION:-8.3}

LABEL maintainer="eggplants <w10776e8w@yahoo.co.jp>"
LABEL org.opencontainers.image.description="MikoPBX - a free, open-source PBX with a friendly interface, based on Asterisk."
LABEL org.opencontainers.image.documentation="https://docs.mikopbx.com/mikopbx/v/english/setup/docker"
LABEL org.opencontainers.image.source="https://github.com/mikopbx/Core"
LABEL org.opencontainers.image.title="MikoPBX"
LABEL org.opencontainers.image.url="https://www.mikopbx.com"
LABEL org.opencontainers.image.vendor="MIKO LLC"

# https://github.com/phalcon/cphalcon/tags
ARG PHALCON_VERSION
ENV PHALCON_VERSION=${PHALCON_VERSION:-5.8.0}

# see: https://packagist.org/packages/mikopbx/core
ARG MIKO_PBX_VERSION
ENV MIKO_PBX_VERSION=${MIKO_PBX_VERSION:-dev-develop}

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM}

SHELL ["/bin/bash", "-euox", "pipefail", "-c"]

COPY --from=gnatsd-builder /work/gnatsd /usr/sbin/gnatsd

RUN <<EOF
export DEBIAN_FRONTEND=noninteractive

# Essential packages; should be exist on every architecture
ESSENTIAL_PACKAGES=(
  # Basic build system:
  autoconf build-essential busybox ca-certificates curl dialog dropbear pkg-config
  # Asterisk: basic requirements:
  libedit-dev libjansson-dev libsqlite3-dev uuid-dev dahdi-linux linux-source
  # PHP extension requirements:
  libevent-dev libldap2-dev libpcre3-dev libssl-dev libtool libtool-bin libxml2-dev libyaml-dev libzip-dev libonig-dev libldb-dev libldap-dev redis
  # Asterisk: for addons:
  libspeex-dev libspeexdsp-dev libogg-dev libvorbis-dev libasound2-dev portaudio19-dev libcurl4-openssl-dev
  xmlstarlet libpq-dev unixodbc-dev libneon27-dev libgmime-3.0-dev liburiparser-dev libxslt1-dev
  libbluetooth-dev libradcli-dev freetds-dev libosptk-dev libjack-jackd2-dev
  libsnmp-dev libiksemel-dev libcorosync-common-dev libcpg-dev libcfg-dev libnewt-dev libpopt-dev
  libical-dev libspandsp-dev libresample1-dev libc-client2007e-dev binutils-dev libsrtp2-dev libsrtp2-dev
  libgsm1-dev doxygen graphviz libcodec2-dev libfftw3-dev libsndfile1-dev libunbound-dev
  # Asterisk: for the unpackaged below:
  wget subversion p7zip-full sysstat dahdi-linux sox
  python3-dev vlan git ntp sqlite3 curl w3m lame libbz2-dev libgmp-dev libtonezone-dev
  fail2ban sngrep tcpdump msmtp beanstalkd
  libluajit2-5.1-2 libluajit2-5.1-dev lua-resty-core lua-resty-lrucache
)

# Optional packages; desirable, but possibly not existent package on some architecture
OPTIONAL_PACKAGES=(
  # Asterisk: for the unpackaged below:
  open-vm-tools
)

apt-get update
apt-get -y install "${ESSENTIAL_PACKAGES[@]}"

# Install optional packages with ignoring error
for pkg in "${OPTIONAL_PACKAGES[@]}"; do
  apt-get install -y "$pkg" || true
done

rm -rf /bin/ps
ln -s /bin/busybox /bin/ps
ln -s /bin/busybox /bin/ifconfig
ln -s /bin/busybox /bin/ping
ln -s /bin/busybox /bin/route
ln -sf /bin/busybox /bin/killall
ln -s /usr/sbin/cron /usr/sbin/crond

unset DEBIAN_FRONTEND
EOF

RUN <<EOF
php -i | grep enabled

mv /usr/local/etc/php/php.ini-production /etc/php.ini
pecl config-set php_ini /etc/php.ini

case "$TARGETPLATFORM" in
  "linux/arm64") ln -s /usr/lib/aarch64-linux-gnu/libldap.so /usr/lib/libldap.so ;;
  "linux/amd64") ln -s /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/libldap.so ;;
  "linux/386") ln -s /usr/lib/i386-linux-gnu/libldap.so /usr/lib/libldap.so ;;
  "linux/arm/v6") ln -s /usr/lib/arm-linux-gnueabi/libldap.so /usr/lib/libldap.so ;;
  "linux/arm/v7") ln -s /usr/lib/arm-linux-gnueabihf/libldap.so /usr/lib/libldap.so ;;
  *) ln -s /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/libldap.so ;;
esac

docker-php-ext-configure pcntl --enable-pcntl
docker-php-ext-install -j"$(nproc)" \
  ldap \
  pcntl \
  sockets \
  zip
if [[ "$PHP_VERSION" =~ ^8\. ]]; then
  :
else
  docker-php-ext-install -j"$(nproc)" json
fi

pecl install ev event
docker-php-ext-enable --ini-name zz-event.ini event

EXTS=(psr mailparse igbinary msgpack xdebug yaml zephir_parser redis)
pecl install -s "${EXTS[@]}"
docker-php-ext-enable "${EXTS[@]}"

pecl install -s "phalcon-${PHALCON_VERSION}" &> /dev/null
docker-php-ext-enable phalcon
pecl clear-cache
EOF

WORKDIR /root/install

ENV PATH="$PATH:/sbin:/usr/sbin"

COPY ./libs/ ./libs/
COPY ./packages/ ./packages/

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

RUN <<EOF
set -eux

source ./libs/functions.sh
# shellcheck disable=SC1090
source ./packages/41-asterisk.sh
source ./packages/50-nginx.sh
EOF

RUN <<EOF
set -eux
# Add the 8021q module to autoload for VLAN support
grep -q 8021q /etc/modules || sed -i '1i8021q' /etc/modules

source ./packages/99-install-mikopbx.sh
EOF

ENV PHP_INI_SCAN_DIR=/etc/php.d

RUN <<EOF
export DEBIAN_FRONTEND=noninteractive

# TODO: check installation after finished install.sh
# pdnsd
# PDNSD_URL="https://cloudfront.debian.net/debian-archive/debian/pool/main/p/pdnsd/pdnsd_1.2.9a-par-2_$(dpkg --print-architecture).deb"
# curl -OL "$PDNSD_URL"
# apt-get install -y ./"$(basename "$PDNSD_URL")"
# rm "$_"

apt-get clean
rm -rf /var/lib/apt/lists/*
unset DEBIAN_FRONTEND
EOF

ENTRYPOINT ["/bin/sh", "/sbin/docker-entrypoint"]

EXPOSE 80 443 5060/udp 5060/tcp 5038 8088 8089 10000-11000/udp
