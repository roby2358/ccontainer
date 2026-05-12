FROM node:lts-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        curl \
        gnupg \
        ripgrep \
        less \
        procps \
        sudo \
        python3 \
        python3-venv \
        openssh-client \
        vim \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh \
        | bash -s -- --to /usr/local/bin

RUN npm install -g npm@latest \
    && npm install -g @anthropic-ai/claude-code

RUN { \
        echo "alias cc='claude --dangerously-skip-permissions'"; \
        echo "alias ll='ls -lA'"; \
    } > /etc/profile.d/cc.sh

RUN { \
        echo 'if [ -f "$HOME/.gitconfig.host" ] && ! grep -qF .gitconfig.host "$HOME/.gitconfig" 2>/dev/null; then'; \
        echo '    {'; \
        echo '        echo "[include]"'; \
        echo '        echo "    path = ~/.gitconfig.host"'; \
        echo '        echo "[credential]"'; \
        echo '        echo "    helper ="'; \
        echo '        echo "    helper = !gh auth git-credential"'; \
        echo '    } > "$HOME/.gitconfig"'; \
        echo 'fi'; \
    } > /etc/profile.d/gitconfig-init.sh

RUN userdel -r node 2>/dev/null || true \
    && useradd -m -u 1000 -s /bin/bash roby \
    && echo 'roby ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/roby

USER roby
WORKDIR /work
CMD ["bash", "-l"]
