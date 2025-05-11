#!/bin/bash
set -eux

if command -v systemctl &>/dev/null; then
  rm -rf /etc/resolv.conf 2>/dev/null
  ln -svi /run/systemd/resolve/resolv.conf /etc/resolv.conf
  echo "[Resolve]" >/tmp/resolved.conf
  echo "DNS=127.0.0.1 4.4.4.4 8.8.8.8" >>/tmp/resolved.conf
  mv /tmp/resolved.conf /etc/systemd/resolved.conf
  systemctl enable systemd-resolved
  systemctl restart systemd-resolved
fi
# END Setting DNS
