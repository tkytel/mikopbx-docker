#!/bin/bash
set -eux

if command -v apparmor_parser &>/dev/null; then
  ln -s /etc/apparmor.d/usr.bin.msmtp /etc/apparmor.d/disable/
  apparmor_parser -R /etc/apparmor.d/usr.bin.msmtp
fi
