#!/bin/bash
set -eux

# https://github.com/nginx/nginx/releases
NGINX_VERSION='1.28.0'
# https://github.com/openresty/lua-nginx-module/tags
NGINX_LUA_M_VERSION='0.10.28'
# https://github.com/wandenberg/nginx-push-stream-module/tags
NGINX_PUSH_M_VERSION='0.6.0'
# https://github.com/vision5/ngx_devel_kit/releases
NGINX_DEV_KIT_VERSION='0.3.4'

LIB_URL="http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
srcDirName=$(downloadFile "$LIB_URL")
LIB_URL_LUA="https://github.com/openresty/lua-nginx-module/archive/refs/tags/v${NGINX_LUA_M_VERSION}.tar.gz"
srcDirNameLua=$(downloadFile "$LIB_URL_LUA")
LIB_URL_PUSH="https://github.com/wandenberg/nginx-push-stream-module/archive/refs/tags/${NGINX_PUSH_M_VERSION}.tar.gz"
srcDirNamePush=$(downloadFile "$LIB_URL_PUSH")
LIB_URL_KIT="https://github.com/vision5/ngx_devel_kit/archive/refs/tags/v${NGINX_DEV_KIT_VERSION}.tar.gz"
srcDirNameKit=$(downloadFile "$LIB_URL_KIT")
pushd "$srcDirName"

export LUAJIT_LIB=/usr/
export LUAJIT_INC=/usr/include/luajit-2.1/
./configure --prefix=/usr --user=nginx --group=nginx --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/error.log \
  --http-log-path=/var/log/access.log \
  --pid-path=/var/run/nginx.pid \
  --http-client-body-temp-path=/var/log/client_body_temp \
  --http-proxy-temp-path=/var/log/proxy_temp \
  --http-fastcgi-temp-path=/var/log/fastcgi_temp \
  --http-uwsgi-temp-path=/var/log/uwsgi_temp \
  --http-scgi-temp-path=/var/log/scgi_temp \
  --with-http_ssl_module \
  --with-ld-opt="-Wl,-rpath,$LUAJIT_LIB,-ldl" \
  --add-module="$(realpath "$srcDirNameKit")" \
  --add-module="$(realpath "$srcDirNamePush")" \
  --add-module="$(realpath "$srcDirNameLua")"

make -j"$(nproc)"
make install

popd

useradd www
rm -rf "$srcDirName" "$srcDirNameLua" "$srcDirNamePush" "$srcDirNameKit"
