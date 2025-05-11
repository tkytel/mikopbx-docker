#!/bin/bash
set -eux

curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer
