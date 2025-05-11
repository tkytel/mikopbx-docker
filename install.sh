#!/bin/bash
set -eux

ROOT_DIR="$(realpath "$(dirname "$0")")"
source "${ROOT_DIR}/libs/functions.sh"

"${ROOT_DIR}/libs/install_prereq.sh"

for filename in "${ROOT_DIR}/packages/"*.sh; do
  cat <<EOF
###############################################
### Starting ${filename}
###############################################
EOF
  # shellcheck disable=SC1090
  source "$filename"
done
