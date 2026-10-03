#!/bin/bash
# Build Asterisk (and the beanstalk client library required by cel_beanstalkd)
# and install it into $DESTDIR.
set -euxo pipefail

: "${ASTERISK_VERSION:?}"
: "${BEANSTALK_CLIENT_VERSION:?}"
: "${DESTDIR:?}"

# shellcheck source=libs/functions.sh
source "$(dirname "$0")/../libs/functions.sh"

# https://github.com/deepfryed/beanstalk-client
# cel_beanstalkd.so delivers CEL events to beanstalkd; MikoPBX builds CDRs from them.
srcDirName="$(downloadFile "https://github.com/deepfryed/beanstalk-client/archive/refs/tags/v${BEANSTALK_CLIENT_VERSION}.tar.gz")"
pushd "$srcDirName"
make -j"$(nproc)" libbeanstalk.so
install -Dm644 beanstalk.h /usr/include/beanstalk.h
install -Dm755 libbeanstalk.so "/usr/lib/libbeanstalk.so.${BEANSTALK_CLIENT_VERSION}"
ln -sf "libbeanstalk.so.${BEANSTALK_CLIENT_VERSION}" /usr/lib/libbeanstalk.so.1
ln -sf libbeanstalk.so.1 /usr/lib/libbeanstalk.so
install -Dm755 libbeanstalk.so "${DESTDIR}/usr/lib/libbeanstalk.so.${BEANSTALK_CLIENT_VERSION}"
ln -sf "libbeanstalk.so.${BEANSTALK_CLIENT_VERSION}" "${DESTDIR}/usr/lib/libbeanstalk.so.1"
ldconfig
popd
rm -rf "$srcDirName"

# https://github.com/asterisk/asterisk/releases
srcDirName="$(downloadFile "https://github.com/asterisk/asterisk/releases/download/${ASTERISK_VERSION}/asterisk-${ASTERISK_VERSION}.tar.gz")"
pushd "$srcDirName"

# format_mp3 sources are fetched separately; it is optional.
contrib/scripts/get_mp3_source.sh || :

./configure \
  --prefix=/usr \
  --sysconfdir=/etc \
  --localstatedir=/var \
  --libdir=/usr/lib \
  --with-pjproject-bundled \
  --with-beanstalk \
  --with-unbound \
  --without-dahdi \
  --without-pri \
  --without-ss7 \
  --without-tonezone

make menuselect.makeopts
menuselect/menuselect \
  --disable BUILD_NATIVE \
  --disable-category MENUSELECT_CORE_SOUNDS \
  --disable-category MENUSELECT_MOH \
  --disable-category MENUSELECT_EXTRA_SOUNDS \
  --enable cel_beanstalkd \
  --enable cdr_beanstalkd \
  --enable pbx_lua \
  --enable res_resolver_unbound \
  --enable format_mp3 \
  --enable app_mp3 \
  menuselect.makeopts

make -j"$(nproc)"
make install DESTDIR="$DESTDIR"
popd
rm -rf "$srcDirName"

# Modules MikoPBX cannot work without.
for module in chan_pjsip res_pjsip chan_iax2 cel_beanstalkd pbx_lua app_confbridge app_queue res_resolver_unbound; do
  test -f "${DESTDIR}/usr/lib/asterisk/modules/${module}.so"
done
