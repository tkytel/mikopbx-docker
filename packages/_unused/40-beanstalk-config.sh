#!/bin/bash
set -eux

echo "Setting beanstalkd ..."
cat <<'EOF' >/etc/default/beanstalkd
BEANSTALKD_LISTEN_ADDR=127.0.0.1
BEANSTALKD_LISTEN_PORT=4229
EOF
