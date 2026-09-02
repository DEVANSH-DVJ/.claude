#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  IMAGE_NAME="myproject:latest-amd64"
else
  echo "Error: Unsupported architecture: $ARCH"
  exit 1
fi

HOST_MOUNT="$(pwd)/.."

GPU_FLAGS=()
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1 &&
  docker info -f '{{json .Runtimes}}' 2>/dev/null | grep -q '"nvidia"'; then
  GPU_FLAGS=(--gpus all)
fi

trap './chown.sh >/dev/null 2>&1' EXIT

docker run --rm --entrypoint bash \
  --name "myproject-exec-$$-${RANDOM}" \
  "${GPU_FLAGS[@]}" \
  -v "${HOST_MOUNT}:/workspace:rw" \
  -w /workspace \
  "${IMAGE_NAME}" \
  -lc "$*"
