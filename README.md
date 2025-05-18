# mikopbx-docker

[![Release Package](
  <https://github.com/tkytel/mikopbx-docker/actions/workflows/release.yaml/badge.svg>
  )](
  <https://github.com/tkytel/mikopbx-docker/actions/workflows/release.yaml>
) [![pre-commit](
  <https://github.com/tkytel/mikopbx-docker/actions/workflows/pre-commit.yaml/badge.svg>
  )](
  <https://github.com/tkytel/mikopbx-docker/actions/workflows/pre-commit.yaml>
)

## Supported Platforms

- `linux/arm64` (aarch64)
- `linux/amd64` (x86_64)

See also:

- <https://github.com/mikopbx/Core/tree/develop/resources/rootfs/usr/lib64/extensions>
- <https://github.com/mikopbx/Core/issues/889>

## Conformed versions of MikoPBX

- [`dev-develop#fd4f4b622306a8dd1cb82c9ea5bcd4a16eb6b79a`](https://github.com/mikopbx/Core/tree/fd4f4b622306a8dd1cb82c9ea5bcd4a16eb6b79a)

## How to build

```bash
# default
docker build . -t tkytel/mikopbx-docker:latest

# https://packagist.org/packages/mikopbx/core#dev-develop
docker build . \
  --build-arg PHP_VERSION=8.3 \
  --build-arg DEBIAN_CODENAME=bookworm \
  --build-arg PHALCON_VERSION=5.8.0 \
  --build-arg MIKO_PBX_VERSION=dev-develop \
  -t tkytel/mikopbx-docker:dev-develop
```

<!--

```bash
# https://packagist.org/packages/mikopbx/core#2024.1.114
docker build . \
  --build-arg PHP_VERSION=7.4 \
  --build-arg DEBIAN_CODENAME=buster \
  --build-arg PHALCON_VERSION=4.1.3 \
  --build-arg MIKO_PBX_VERSION=2024.1.114 \
  -t tkytel/mikopbx-docker:2024.1.114
```

-->

## How to use image

See: <https://docs.mikopbx.com/mikopbx/english/setup/docker>
