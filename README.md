# mikopbx-docker

[![image tags] ![image latest] ![image size]](https://github.com/tkytel/mikopbx-docker/pkgs/container/mikopbx-docker)

[image tags]: <https://ghcr-badge.egpl.dev/tkytel/mikopbx-docker/tags?trim=major>
[image latest]: <https://ghcr-badge.egpl.dev/tkytel/mikopbx-docker/latest_tag?trim=major&label=latest>
[image size]: <https://ghcr-badge.egpl.dev/tkytel/mikopbx-docker/size?tag=2026.3.40>

[![Release Package](
  <https://github.com/tkytel/mikopbx-docker/actions/workflows/release.yaml/badge.svg>
  )](
  <https://github.com/tkytel/mikopbx-docker/actions/workflows/release.yaml>
) [![ci](
  <https://github.com/tkytel/mikopbx-docker/actions/workflows/ci.yaml/badge.svg>
  )](
  <https://github.com/tkytel/mikopbx-docker/actions/workflows/ci.yaml>
)

Docker image of [MikoPBX](https://github.com/mikopbx/Core) built on Debian from source.

## Conformed versions of MikoPBX

- [`2026.3.40`](https://github.com/mikopbx/Core/tree/2026.3.40)

## How to build

```bash
# default
docker build . -t tkytel/mikopbx-docker:2026.3.40

# All build arguments
docker build . \
  --build-arg DEBIAN_CODENAME=trixie \
  --build-arg PHP_VERSION=8.4 \
  --build-arg PHALCON_VERSION=5.9.3 \
  --build-arg ASTERISK_VERSION=22.8.2 \
  --build-arg MIKOPBX_VERSION=2026.3.40 \
  --build-arg MIKOPBX_BINARY_IMAGE=mikopbx/mikopbx:latest \
  -t tkytel/mikopbx-docker:2026.3.40
```

## How to use image

See the comments in [`compose.yaml`](./compose.yaml) and <https://docs.mikopbx.com/mikopbx/english/setup/docker>.

```bash
ID_WWW_USER="$(id -u www-user)" ID_WWW_GROUP="$(id -g www-user)" docker compose up -d
```

`ID_WWW_USER` and `ID_WWW_GROUP` set the UID and GID of the `www` user in the container,
which must be able to write to the mounted directories.

The web interface is served on `WEB_PORT` / `WEB_HTTPS_PORT` (login: `admin` / `admin`).
