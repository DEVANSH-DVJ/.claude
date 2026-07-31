#!/usr/bin/env bash
# Run one command inside a fresh ephemeral container over the bind-mounted repo.
# Usage: ./docker/exec.sh "<command>"
set -euo pipefail
cd "$(dirname "$0")"
. ./config.sh

HOST_MOUNT="$(pwd)/.."

# Attach GPUs only when the runtime is actually present.
GPU_FLAGS=()
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1 &&
  docker info -f '{{json .Runtimes}}' 2>/dev/null | grep -q '"nvidia"'; then
  GPU_FLAGS=(--gpus all)
fi

# Chown the mount back to the host user on exit (container writes as root).
trap './chown.sh >/dev/null 2>&1 || true' EXIT

docker run --rm --entrypoint bash \
  --name "${PROJECT_SLUG}-exec-$$-${RANDOM}" \
  "${GPU_FLAGS[@]}" \
  -v "${HOST_MOUNT}:/workspace:rw" \
  -w /workspace \
  "${IMAGE_NAME}" \
  -ilc "$*"
