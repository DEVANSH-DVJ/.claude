#!/usr/bin/env bash
# The one edit point for the container tooling. Sourced by exec.sh / build.sh / chown.sh.
PROJECT_SLUG="myproject"

case "$(uname -m)" in
  x86_64) IMAGE_TAG="latest-amd64" ;;
  aarch64 | arm64) IMAGE_TAG="latest-arm64" ;;
  *)
    echo "unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac
IMAGE_NAME="${PROJECT_SLUG}:${IMAGE_TAG}"
