FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y locales \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y \
    ca-certificates curl wget gnupg software-properties-common \
    git git-lfs \
    bash zsh tmux \
    build-essential cmake ninja-build pkg-config \
    ripgrep fd-find fzf jq yq bat eza \
    openssh-client netcat-openbsd \
    vim neovim \
    sudo \
    unzip tar gzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf $(which fdfind) /usr/local/bin/fd || true

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN set -ex \
    && if getent group "$USER_GID" >/dev/null 2>&1; then \
        existing_group=$(getent group "$USER_GID" | cut -d: -f1); \
        echo "Moving existing group $existing_group (GID $USER_GID) to GID 99${USER_GID}"; \
        groupmod -g "99${USER_GID}" "$existing_group"; \
    fi \
    && if getent passwd "$USER_UID" >/dev/null 2>&1; then \
        existing_user=$(getent passwd "$USER_UID" | cut -d: -f1); \
        echo "Moving existing user $existing_user (UID $USER_UID) to UID 99${USER_UID}"; \
        usermod -u "99${USER_UID}" "$existing_user"; \
    fi \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER root
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /usr/local/bin/ \
    && mv /root/.local/bin/uvx /usr/local/bin/ \
    && uv python install 3.12 \
    && ln -sf /root/.local/share/uv/python/cpython-3.12*/bin/python3 /usr/local/bin/python3 \
    && ln -sf /usr/local/bin/python3 /usr/local/bin/python \
    && ln -sf /root/.local/share/uv/python/cpython-3.12*/bin/pip3 /usr/local/bin/pip3 \
    && ln -sf /usr/local/bin/pip3 /usr/local/bin/pip

ENV FNM_DIR="/usr/local/share/fnm"
RUN curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell \
    && eval "$("$FNM_DIR/fnm" env)" \
    && "$FNM_DIR/fnm" install --lts \
    && "$FNM_DIR/fnm" use lts-latest \
    && ln -sf "$FNM_DIR/aliases/lts-latest/bin/node" /usr/local/bin/node \
    && ln -sf "$FNM_DIR/aliases/lts-latest/bin/npm" /usr/local/bin/npm \
    && ln -sf "$FNM_DIR/aliases/lts-latest/bin/npx" /usr/local/bin/npx

RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64) GO_ARCH="amd64" ;; \
        aarch64|arm64) GO_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    GO_VERSION=$(curl -fsSL https://go.dev/VERSION?m=text | head -1) && \
    curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-${GO_ARCH}.tar.gz" | tar -C /usr/local -xz \
    && ln -sf /usr/local/go/bin/go /usr/local/bin/go \
    && ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --no-modify-path \
    && ln -sf /usr/local/cargo/bin/rustc /usr/local/bin/rustc \
    && ln -sf /usr/local/cargo/bin/cargo /usr/local/bin/cargo \
    && ln -sf /usr/local/cargo/bin/rustup /usr/local/bin/rustup \
    && chmod -R a+rX /usr/local/cargo /usr/local/rustup

RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes

RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64) DIRENV_ARCH="amd64" ;; \
        aarch64|arm64) DIRENV_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/direnv/direnv/releases/latest/download/direnv.linux-${DIRENV_ARCH}" -o /usr/local/bin/direnv \
    && chmod +x /usr/local/bin/direnv

RUN echo 'eval "$(direnv hook bash)"' >> /etc/bash.bashrc
RUN echo 'eval "$(starship init bash)"' >> /etc/bash.bashrc
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /etc/bash.bashrc

USER $USERNAME
WORKDIR /home/$USERNAME

RUN mkdir -p ~/.config/direnv

RUN mkdir -p ~/.config \
    && starship preset nerd-font-symbols -o ~/.config/starship.toml

RUN mkdir -p ~/.local/bin

SHELL ["/bin/bash", "-c"]
WORKDIR /workspace

CMD ["sleep", "infinity"]
