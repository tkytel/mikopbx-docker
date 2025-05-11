#!/bin/bash

ROOT_DIR="$(realpath "$(dirname "$0")")"
# shellcheck source=libs/functions.sh
"${ROOT_DIR}/libs/functions.sh"

export ROOT_DIR
export DEBIAN_FRONTEND=noninteractive
export PATH="$PATH:/sbin:/usr/sbin"
export LOG_FILE=/dev/stdout

busybox touch "$LOG_FILE"
"${ROOT_DIR}/libs/install_prereq.sh"
for filename in "${ROOT_DIR}/packages/"*.sh; do
  echo "Starting $filename"
  ("$filename")
done
