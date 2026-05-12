#!/usr/bin/env bash
set -euo pipefail

IMAGE="ccontainer:latest"

cd "$(dirname "$0")"

podman build --no-cache --pull=newer -t "$IMAGE" .
