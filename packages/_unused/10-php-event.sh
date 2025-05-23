#!/bin/bash
set -eux

LIB_VERSION='2.5.6'
LIB_URL="https://pecl.php.net/get/event-${LIB_VERSION}.tgz"
LIB_PRIORITY='40'
LIB_PHP_MODULE_PREFIX_INI=''
LIB_CONFIGURE_OPTIONS=''
LIB_NAME='event'

installPhpExtension "$LIB_NAME" "$LIB_URL" "$LIB_PRIORITY" "$LIB_PHP_MODULE_PREFIX_INI" "$LIB_CONFIGURE_OPTIONS"
