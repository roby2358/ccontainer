# ccontainer

A container to run Claude Code with `--dangerously-skip-permissions` while keeping the host protected. Targets Windows + WSL2 + podman.

Bundles Claude Code plus the usual dev utilities (see `Containerfile`). Inside the container, `cc` aliases `claude --dangerously-skip-permissions` — safe-ish because the container is the sandbox. Don't run that alias on your host.

## Prereqs (on the WSL host)

- `gh auth login`
- `systemctl --user start podman.socket`
- A working tree at `/mnt/c/work` (or edit `run.sh`)

## Use

```sh
./run.sh
```

Auto-builds `ccontainer:latest` on first run. Then `cc` inside.

## What persists

- `/work` ← host `/mnt/c/work` (your code)
- `~/.claude`, `~/.config/gh` ← bind-mounted from host
- everything else in `/home/roby` ← podman volume `ccontainer-home`

Container itself is `--rm`.
