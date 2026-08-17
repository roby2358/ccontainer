#!/usr/bin/env bash
set -euo pipefail

IMAGE="ccontainer:latest"

cd "$(dirname "$0")"

# Explicitly refresh the base image ourselves rather than trusting the build's
# --pull=newer, which in podman 4.9.x can silently no-op on a re-pushed tag and
# leave the build sitting on a stale cached base. A fully-qualified pull always
# queries the registry, downloads layers only if the digest moved, and fails
# loudly if it can't reach docker.io. The docker.io/library/ qualification avoids
# short-name resolution picking up a stray localhost/node image.
podman pull docker.io/library/node:lts-bookworm-slim

podman build --no-cache -t "$IMAGE" .
