#!/usr/bin/env bash
set -euo pipefail

IMAGE="ccontainer:latest"
VOLUME="ccontainer-home"

cd "$(dirname "$0")"

if ! podman image exists "$IMAGE"; then
    podman build -t "$IMAGE" .
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
    -v "$HOME/.config/gh":/home/roby/.config/gh:ro \
    -v "$HOME/.gitconfig":/home/roby/.gitconfig.host:ro \
    -w /work \
    "$IMAGE"
