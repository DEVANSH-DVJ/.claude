#!/usr/bin/env bash
# Restore host ownership of the mount after a container ran as root.
set -euo pipefail
cd "$(dirname "$0")"
. ./config.sh

CHOWN_CONTAINER_NAME="${PROJECT_SLUG}-chown"

if docker ps -a --format '{{.Names}}' | grep -xq "${CHOWN_CONTAINER_NAME}"; then
  docker rm -f "${CHOWN_CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

docker run --rm --name "${CHOWN_CONTAINER_NAME}" \
  -v "$(pwd)/..:/workspace:rw" \
  busybox:1.36 \
  sh -c "chown -R $(id -u):$(id -g) /workspace"
