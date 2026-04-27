# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A two-file definition of a sandboxed dev container for running Claude Code on Windows/WSL2 via podman. The image bundles `claude-code`, `gh`, `git`, `uv`, `podman`, `ripgrep`, and Node 22. Inside the container, the alias `cc` runs `claude --dangerously-skip-permissions`.

There is no application code here, no test suite, and no language toolchain to set up. Edits land in `Containerfile` or `run.sh`.

## Common commands

- Build image manually: `podman build -t ccontainer:latest .`
- Build + run (auto-builds if image missing): `./run.sh`
- Rebuild from scratch: `podman rmi localhost/ccontainer:latest && ./run.sh`
- Reset persistent home: `podman volume rm ccontainer-home`

## Architecture notes that are not obvious from one file

The container is designed for **podman-in-podman without nesting**: instead of running a podman daemon inside the container, `run.sh` bind-mounts the host's user podman socket (`$XDG_RUNTIME_DIR/podman/podman.sock`) into the container at `/run/podman/podman.sock` and exports `CONTAINER_HOST` so the in-container `podman` CLI talks back to the host daemon. Any container started "from inside" actually runs as a sibling on the host. This requires `systemctl --user start podman.socket` on the host first; `run.sh` warns but does not fail if the socket is missing.

Three host paths are shared into the container, and changes to anything under them are real edits to host state:

- `/mnt/c/work` → `/work` (the WSL view of the Windows `C:\work` directory; this is the working tree)
- `$HOME/.claude` → `/home/roby/.claude` (Claude Code config + memory; shared with the host's Claude Code)
- `$HOME/.config/gh` → `/home/roby/.config/gh` (gh auth; do `gh auth login` on the host first)

The rest of `/home/roby` lives in a named podman volume `ccontainer-home`, so shell history, npm caches, and similar persist across `--rm` runs without leaking into the host home.

UID alignment uses `--userns=keep-id` plus a `roby` user created at uid 1000 in the image. The Containerfile deletes the default `node` user before creating `roby` to free uid 1000. If the host user is not uid 1000, file ownership on the bind mounts will look wrong.

## Things to keep in mind when editing

- `Containerfile` runs as root until the final `USER roby`. Anything that needs to land in `roby`'s home must either run after that line or be placed in `/etc/skel` / a shared location.
- `run.sh` uses `set -euo pipefail` and `exec podman run --rm -it ...`; the container is ephemeral by design — only `ccontainer-home` and the bind mounts survive.
- `.claude/settings.local.json` is a permission allowlist for Claude Code running on the host against this directory; it is not consumed by the container build.
