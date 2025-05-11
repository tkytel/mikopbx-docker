ARG PHP_VERSION
FROM php:${PHP_VERSION-8.3}-bookworm
ENV PHP_VERSION=${PHP_VERSION:-8.3}

LABEL maintainer="eggplants <w10776e8w@yahoo.co.jp>"
LABEL org.opencontainers.image.source="https://github.com/mikopbx/Core"
LABEL org.opencontainers.image.description="MikoPBX - is free, easy to setup PBX for small business based on Asterisk"

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
  busybox \
  curl \
  gcc \
  linux-image-generic \
  libcurl4-openssl-dev \
  libldap-dev \
  libtool \
  libtool-bin \
  make
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
pecl install -s psr
docker-php-ext-enable psr
pecl clear-cache
curl -LO https://github.com/phalcon/cphalcon/archive/v${PHALCON_VERSION}.tar.gz
tar xzf v${PHALCON_VERSION}.tar.gz
if [[ ${PHALCON_VERSION} =~ ^5\. ]]; then
  docker-php-ext-install -j$(nproc) /cphalcon-${PHALCON_VERSION}/build/phalcon &> /dev/null
else
  docker-php-ext-install -j$(nproc) /cphalcon-${PHALCON_VERSION}/build/php7/64bits &> /dev/null
fi
rm -rf v${PHALCON_VERSION}.tar.gz cphalcon-${PHALCON_VERSION}

docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/
docker-php-ext-install -j$(nproc) \
  curl \
  iconv \
  ldap \
  openssl \
  pcntl \
  posix \
  simplexml \
  sockets \
  sqlite3 \
  zip
if [[ "$PHP_VERSION" =~ ^8\. ]]; then
  :
else
  docker-php-ext-install -j$(nproc) json
fi

EOF

WORKDIR /root/install

COPY ./libs/ ./libs/
COPY ./packages/ ./packages/
COPY ./install.sh .

RUN ls /root/install /root/install/libs /root/install/packages

RUN ./install.sh

ENTRYPOINT ["sh", "/sbin/docker-entrypoint"]

EXPOSE 80 443 5060/udp 5060/tcp 5038 8088 8089 10000-11000/udp
