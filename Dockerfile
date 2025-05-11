ARG PHP_VERSION
FROM php:${PHP_VERSION-8.3}-bookworm
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

SHELL ["/bin/bash", "-euox", "pipefail", "-c"]

RUN <<EOF
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get -y install \
  autoconf \
  build-essential \
  busybox \
  ca-certificates \
  dahdi-linux \
  linux-source \
  libevent-dev \
  libldap2-dev \
  libpcre3-dev \
  libssl-dev \
  libtool \
  libtool-bin \
  libxml2-dev \
  libyaml-dev \
  libzip-dev \
  pkg-config
  # "linux-headers-$(uname -r)" \
apt-get clean
rm -rf /var/lib/apt/lists/*

rm -rf /bin/ps
ln -s /bin/busybox /bin/ps
ln -s /bin/busybox /bin/ifconfig
ln -s /bin/busybox /bin/ping
ln -s /bin/busybox /bin/route
ln -s /usr/sbin/cron /usr/sbin/crond

unset DEBIAN_FRONTEND
EOF

RUN <<EOF
php -i | grep enabled

mv /usr/local/etc/php/php.ini-production /etc/php.ini
pecl config-set php_ini /etc/php.ini

ln -s /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/libldap.so
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

pecl install event
docker-php-ext-enable --ini-name zz-event.ini event

EXTS=(psr mailparse igbinary msgpack xdebug yaml zephir_parser redis)
pecl install -s "${EXTS[@]}"
docker-php-ext-enable "${EXTS[@]}"

pecl install -s "phalcon-${PHALCON_VERSION}" &> /dev/null
docker-php-ext-enable phalcon
pecl clear-cache
EOF

WORKDIR /root/install

COPY ./libs/ ./libs/
COPY ./packages/ ./packages/
COPY ./install.sh .

RUN ./install.sh

ENTRYPOINT ["/bin/sh", "/sbin/docker-entrypoint"]

EXPOSE 80 443 5060/udp 5060/tcp 5038 8088 8089 10000-11000/udp
