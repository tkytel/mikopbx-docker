#!/bin/bash
# Boot the image and wait until MikoPBX is up: Asterisk answers on its console
# and the web interface serves the login page. Prints the container log on failure.
#
#   scripts/smoke-test.sh IMAGE [docker run options...]
set -euo pipefail

image="${1:?usage: $0 IMAGE [docker run options...]}"
shift
name="mikopbx-smoke-test-$$"
port=18080
timeout=600

cleanup() {
  status=$?
  if ((status != 0)); then
    docker logs "$name" 2>&1 | tail -n 100 >&2 || :
  fi
  docker rm -f "$name" >/dev/null 2>&1 || :
}
trap cleanup EXIT

# The web interface's default port: MikoPBX 2026.3.40 applies WEB_PORT only
# from the second boot on.
docker run -d -t --name "$name" --cap-add NET_ADMIN -p "127.0.0.1:${port}:80" \
  "$@" "$image" >/dev/null

start=$SECONDS
until docker exec "$name" asterisk -rx 'core show version' 2>/dev/null | grep -q '^Asterisk ' &&
  curl -fs -o /dev/null "http://127.0.0.1:${port}/admin-cabinet/session/index"; do
  if [[ "$(docker inspect -f '{{.State.Running}}' "$name")" != true ]]; then
    echo "smoke-test: the container exited" >&2
    exit 1
  fi
  if ((SECONDS - start > timeout)); then
    echo "smoke-test: MikoPBX did not come up within ${timeout}s" >&2
    exit 1
  fi
  sleep 5
done

echo "smoke-test: MikoPBX is up after $((SECONDS - start))s"
docker exec "$name" asterisk -rx 'core show version'
docker ps -s --filter "name=^${name}$" --format 'container layer: {{.Size}}'
