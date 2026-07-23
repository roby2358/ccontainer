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
    local local_digests remote_digests arch d
    # podman records both the multi-arch index digest and the per-arch manifest digest
    # in RepoDigests when an image is pulled via tag. The index gets re-pushed whenever
    # any architecture (or attestation manifest) changes, so matching the index digest
    # alone warns even when the host-arch image is unchanged. Compare the host-arch
    # manifest digest — the only bytes a rebuild here would pull — and also accept an
    # index-digest match in case RepoDigests lacks the per-arch entry.
    case "$(uname -m)" in
        x86_64)  arch=amd64 ;;
        aarch64) arch=arm64 ;;
        *)       arch=$(uname -m) ;;
    esac
    local_digests=$(podman image inspect node:lts-bookworm-slim --format '{{range .RepoDigests}}{{.}} {{end}}' 2>/dev/null) || return 0
    remote_digests=$(curl -fsSL --max-time 3 https://hub.docker.com/v2/repositories/library/node/tags/lts-bookworm-slim 2>/dev/null \
        | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(next((i['digest'] for i in d['images'] if i['architecture'] == '$arch'), ''), d['digest'])
" 2>/dev/null) || return 0
    [[ -n "$local_digests" && -n "$remote_digests" ]] || return 0
    for d in $remote_digests; do
        [[ "$local_digests" == *"@$d"* ]] && return 0
    done
    echo "node base: newer image available on registry — run ./rebuild.sh to update" >&2
}

check_host_paths() {
    [[ -d "$HOME/.config/gh" ]] \
        || echo "warning: $HOME/.config/gh not found — run 'gh auth login' on the host first" >&2
    [[ -f "$HOME/.gitconfig" ]] \
        || echo "warning: $HOME/.gitconfig not found — set user.name/user.email on the host first" >&2
    [[ -d /data/littlebrain ]] \
        || echo "warning: /data/littlebrain not found on host — littlebrain DBs will not be mounted in the container" >&2
}

check_claude_code
check_node_base
check_host_paths

podman build -q -t "$IMAGE" .

# Optional mounts: only bind host paths that exist, so the container still
# starts on hosts without them (rootless podman cannot create missing
# host-side mount sources).
extra_mounts=()
[[ -d /data/littlebrain ]] && extra_mounts+=(-v /data/littlebrain:/data/littlebrain)

exec podman run --rm -it \
    --userns=keep-id \
    -v /mnt/c/work:/work \
    "${extra_mounts[@]}" \
    -v "$VOLUME":/home/roby \
    -v "$HOME/.claude":/home/roby/.claude \
    -v "$HOME/.config/gh":/home/roby/.config/gh:ro \
    -v "$HOME/.gitconfig":/home/roby/.gitconfig.host:ro \
    -w /work \
    "$IMAGE"
