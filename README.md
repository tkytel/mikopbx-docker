# mikopbx-docker

[![image tags] ![image latest] ![image size]](https://github.com/tkytel/mikopbx-docker/pkgs/container/mikopbx-docker)

[image tags]: <https://ghcr-badge.egpl.dev/tkytel/mikopbx-docker/tags?trim=major>
[image latest]: <https://ghcr-badge.egpl.dev/tkytel/mikopbx-docker/latest_tag?trim=major&label=latest>
[image size]: <https://ghcr-badge.egpl.dev/tkytel/mikopbx-docker/size?tag=2026.5.6>

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
- [`2026.5.6`](https://github.com/mikopbx/Core/tree/2026.5.6)

## How to use image

See the comments in [`compose.yaml`](./compose.yaml) and <https://docs.mikopbx.com/mikopbx/english/setup/docker>.

```bash
ID_WWW_USER="$(id -u www-user)" \
  ID_WWW_GROUP="$(id -g www-user)" \
  docker compose up -d
```

## How to build

```bash
docker build . -t tkytel/mikopbx-docker:2026.5.6

# check
scripts/smoke-test.sh tkytel/mikopbx-docker:2026.5.6
```

## How to update

1. Change the `ARG` defaults in the [`Dockerfile`](./Dockerfile) (and each
   `*_SHA256` next to a changed `*_VERSION`), then pin the base images:

   ```bash
   mise run pinup
   ```

   `MIKOPBX_VERSION` must be a tag of both [mikopbx/Core](https://github.com/mikopbx/Core)
   and [mikopbx/mikopbx](https://hub.docker.com/r/mikopbx/mikopbx/tags), which
   provides the closed-source `mikopbx` PHP extension and `gnatsd`.
2. Commit, let [ci](./.github/workflows/ci.yaml) build and boot the image, and
   run [Release Package](./.github/workflows/release.yaml).
