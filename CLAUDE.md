# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A small sandboxed dev container for running Claude Code on Windows/WSL2 via podman. The image bundles `claude-code`, `gh`, `git`, `uv`, `just`, `ripgrep`, and Node.js (current LTS, via the `node:lts-bookworm-slim` base). Inside the container, the alias `cc` runs `claude --dangerously-skip-permissions`.

There is no application code here, no test suite, and no language toolchain to set up. Edits land in `Containerfile`, `run.sh`, or `rebuild.sh`.

## Common commands

- Build + run: `./run.sh` — runs a plain `podman build` (cache-heavy, near-instant once warm) and then `podman run` with all bind mounts. Before building it does two soft version checks and prints a warning if newer versions exist: installed `claude-code` vs the npm registry, and the local `node:lts-bookworm-slim` digest vs Docker Hub. The checks never mutate anything — `./rebuild.sh` is what acts on them.
- Force a fresh image: `./rebuild.sh` — `podman build --no-cache --pull=newer`. Use this when a check warns about a stale claude-code or node base, or after non-trivial `Containerfile` edits.
- Build image manually: `podman build -t ccontainer:latest .`
- Reset persistent home: `podman volume rm ccontainer-home`

## Architecture notes that are not obvious from one file

Four host paths are shared into the container, and changes to anything under the writable ones are real edits to host state:

- `/mnt/c/work` → `/work` (the WSL view of the Windows `C:\work` directory; this is the working tree)
- `$HOME/.claude` → `/home/roby/.claude` (Claude Code config + memory; shared with the host's Claude Code)
- `$HOME/.config/gh` → `/home/roby/.config/gh` read-only (gh auth; do `gh auth login` on the host first — re-auth must happen on the host)
- `$HOME/.gitconfig` → `/home/roby/.gitconfig.host` read-only (host git identity)

The rest of `/home/roby` lives in a named podman volume `ccontainer-home`, so shell history, npm caches, and similar persist across `--rm` runs without leaking into the host home.

Git identity + auth wiring spans the Containerfile and `run.sh`. On login, `/etc/profile.d/gitconfig-init.sh` (written during the image build) generates `~/.gitconfig` if one doesn't already exist in the volume: it `[include]`s the read-only host `.gitconfig.host` and overrides the credential helper to `!gh auth git-credential`. The effect is that `git push` inside the container reuses the host `gh` token (via the read-only `~/.config/gh` mount) without needing a separate credential setup. If the wiring looks wrong, deleting `~/.gitconfig` from the `ccontainer-home` volume will cause it to be regenerated on next login.

UID alignment uses `--userns=keep-id` plus a `roby` user created at uid 1000 in the image. The Containerfile deletes the default `node` user before creating `roby` to free uid 1000. If the host user is not uid 1000, file ownership on the bind mounts will look wrong. `roby` has passwordless `sudo` inside the container — fine because the container is `--rm` and unprivileged on the host, but it means anything inside can install packages or write to `/etc`.

## Supply-chain hardening (npm)

`/etc/npmrc` is baked into the image with `ignore-scripts=true` after the bootstrap installs, so every subsequent `npm install` and `npx` inside the container skips `pre/post install` lifecycle hooks by default. This is the standard defense against the Shai-Hulud-class self-propagating npm worms (first observed Sep 2025; Mini Shai-Hulud hit `@tanstack/*`, Mistral AI, UiPath, etc. in May 2026), which detonate their payload from a poisoned package's `postinstall` (v1) or `preinstall` (v2) hook the moment `npm install` or `npx <pkg>` touches the package. The two bootstrap installs run *before* the npmrc is written: the npm self-upgrade adds `--ignore-scripts` for belt-and-braces, and the `@anthropic-ai/claude-code` install is left untouched so its own legitimate postinstall can run. The host mirrors this protection with `ignore-scripts=true` in `~/.npmrc`. If a package genuinely needs its install hook (rare — usually a native-module dep), pass `--ignore-scripts=false` per command after auditing the source.

`run.sh` and `rebuild.sh` inherit this protection structurally — both rebuild from `Containerfile`, so the `/etc/npmrc` is recreated on every image build. `rebuild.sh --no-cache` is the way to confirm the layer rebuilds cleanly after editing the hardening.

## Things to keep in mind when editing

- `Containerfile` runs as root until the final `USER roby`. Anything that needs to land in `roby`'s home must either run after that line or be placed in `/etc/skel` / a shared location.
- `run.sh` uses `set -euo pipefail` and `exec podman run --rm -it ...`; the container is ephemeral by design — only `ccontainer-home` and the bind mounts survive.
- `.claude/settings.local.json` is a permission allowlist for Claude Code running on the host against this directory; it is not consumed by the container build.
