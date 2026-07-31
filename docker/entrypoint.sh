#!/usr/bin/env bash
# Default entrypoint for an interactive container: shell, then chown the mount back.
set -e
USER_ID="${HOST_UID:-1000}"
GROUP_ID="${HOST_GID:-1000}"

bash -l

if [ -d /workspace ]; then
  chown -R "${USER_ID}:${GROUP_ID}" /workspace
fi
