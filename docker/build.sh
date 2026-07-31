#!/usr/bin/env bash
# Build the project image. Usage: ./docker/build.sh [--rebuild]
set -euo pipefail
cd "$(dirname "$0")"
. ./config.sh

BUILD_FLAGS=()
[ "${1:-}" = "--rebuild" ] && BUILD_FLAGS=(--no-cache)

echo "building ${IMAGE_NAME} ..."
docker build "${BUILD_FLAGS[@]}" -f Dockerfile -t "${IMAGE_NAME}" .
echo "done: ${IMAGE_NAME}"
