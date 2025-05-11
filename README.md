# mikopbx-docker

[![Release Package](
  <https://github.com/eggplants/mikopbx-docker/actions/workflows/release.yaml/badge.svg>
  )](
  <https://github.com/eggplants/mikopbx-docker/actions/workflows/release.yaml>
) [![pre-commit.ci status](
  <https://results.pre-commit.ci/badge/github/eggplants/mikopbx-docker/master.svg>
  )](
  <https://results.pre-commit.ci/latest/github/eggplants/mikopbx-docker/master>
)

## How to build

```bash
# default
docker build . -t eggplants/mikopbx-docker:latest

# https://packagist.org/packages/mikopbx/core#dev-develop
docker build . \
  --build-arg PHP_VERSION=8.3 \
  --build-arg PHALCON_VERSION=5.8.0 \
  --build-arg MIKO_PBX_VERSION=dev-develop \  
  -t eggplants/mikopbx-docker:dev-develop-2025-05-07-9ffdc3b25405788d5793bc767b1a5f2026bc2429

# https://packagist.org/packages/mikopbx/core#2024.1.114
docker build . \
  --build-arg PHP_VERSION=7.4 \
  --build-arg PHALCON_VERSION=4.1.3 \
  --build-arg MIKO_PBX_VERSION=2024.1.114 \  
  -t eggplants/mikopbx-docker:2024.1.114
```

## How to use image

See: <https://docs.mikopbx.com/mikopbx/english/setup/docker>
