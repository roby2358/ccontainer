#!/usr/bin/env bash
set -euo pipefail

IMAGE="ccontainer:latest"
VOLUME="ccontainer-home"

cd "$(dirname "$0")"

if ! podman image exists "$IMAGE"; then
    podman build -t "$IMAGE" .
fi

HOST_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"
if [[ ! -S "$HOST_SOCK" ]]; then
    echo "warning: $HOST_SOCK not found — start it with: systemctl --user start podman.socket" >&2
fi

if [[ ! -d "$HOME/.config/gh" ]]; then
    echo "warning: $HOME/.config/gh not found — run 'gh auth login' on the host first" >&2
fi

if [[ ! -f "$HOME/.gitconfig" ]]; then
    echo "warning: $HOME/.gitconfig not found — set user.name/user.email on the host first" >&2
fi

exec podman run --rm -it \
    --userns=keep-id \
    -v /mnt/c/work:/work \
    -v "$VOLUME":/home/roby \
    -v "$HOME/.claude":/home/roby/.claude \
    -v "$HOME/.config/gh":/home/roby/.config/gh \
    -v "$HOME/.gitconfig":/home/roby/.gitconfig.host:ro \
    -v "$HOST_SOCK":/run/podman/podman.sock \
    -e CONTAINER_HOST=unix:///run/podman/podman.sock \
    -w /work \
    "$IMAGE"
