#!/bin/bash
set -eux

# Install MikoPBX source.
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer
