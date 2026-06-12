#!/usr/bin/env bash
set -euo pipefail

IMAGE="ccontainer:latest"
VOLUME="ccontainer-home"

cd "$(dirname "$0")"

check_claude_code() {
    local installed latest
    installed=$(podman run --rm "$IMAGE" claude --version 2>/dev/null | awk '{print $1}') || return 0
    latest=$(curl -fsSL --max-time 3 https://registry.npmjs.org/@anthropic-ai/claude-code/latest 2>/dev/null \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])' 2>/dev/null) || return 0
    [[ -n "$installed" && -n "$latest" && "$installed" != "$latest" ]] || return 0
    echo "claude-code: $installed installed, $latest available — run ./rebuild.sh to update" >&2
}

check_node_base() {
    local local_digest remote_digest arch
    local_digest=$(podman image inspect node:lts-bookworm-slim --format '{{index .RepoDigests 0}}' 2>/dev/null \
        | sed 's/.*@//') || return 0
    # podman records the per-arch manifest digest in RepoDigests, but Docker Hub's
    # top-level tag "digest" is the multi-arch index digest — they never match. Compare
    # against the matching per-arch digest from the API's images[] array instead.
    arch=$(podman version --format '{{.Server.OsArch}}' 2>/dev/null | sed 's#.*/##') || return 0
    remote_digest=$(curl -fsSL --max-time 3 https://hub.docker.com/v2/repositories/library/node/tags/lts-bookworm-slim 2>/dev/null \
        | python3 -c "import json,sys; d=json.load(sys.stdin); print(next(i['digest'] for i in d['images'] if i.get('architecture')=='$arch'))" 2>/dev/null) || return 0
    [[ -n "$local_digest" && -n "$remote_digest" && "$local_digest" != "$remote_digest" ]] || return 0
    echo "node base: newer image available on registry — run ./rebuild.sh to update" >&2
}

check_host_paths() {
    [[ -d "$HOME/.config/gh" ]] \
        || echo "warning: $HOME/.config/gh not found — run 'gh auth login' on the host first" >&2
    [[ -f "$HOME/.gitconfig" ]] \
        || echo "warning: $HOME/.gitconfig not found — set user.name/user.email on the host first" >&2
}

check_claude_code
check_node_base
check_host_paths

podman build -q -t "$IMAGE" .

exec podman run --rm -it \
    --userns=keep-id \
    -v /mnt/c/work:/work \
    -v "$VOLUME":/home/roby \
    -v "$HOME/.claude":/home/roby/.claude \
    -v "$HOME/.config/gh":/home/roby/.config/gh:ro \
    -v "$HOME/.gitconfig":/home/roby/.gitconfig.host:ro \
    -w /work \
    "$IMAGE"
