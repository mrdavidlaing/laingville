# Ubuntu 24.04 Development Mode DevContainer
# Layer 0: Bedrock Image - OS Foundation + Core Development Tools
#
# This is the "Rapid Development Mode" implementation optimized for:
# - AI agent compatibility (standard Ubuntu paths and tools)
# - Latest tool versions from upstream sources
# - Fast local iteration without Nix knowledge
# - High developer velocity

FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set locale to avoid encoding issues
RUN apt-get update && apt-get install -y locales \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# ============================================================================
# Layer 0.1: Stable System Foundation (via apt)
# ============================================================================
# Core utilities that are stable and well-maintained in Ubuntu repositories
RUN apt-get update && apt-get install -y \
    # Core system
    ca-certificates \
    curl \
    wget \
    gnupg \
    software-properties-common \
    # Version control
    git \
    git-lfs \
    # Shell and terminal
    bash \
    zsh \
    tmux \
    # Build tools
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    # Search and navigation tools
    ripgrep \
    fd-find \
    fzf \
    jq \
    yq \
    # Modern replacements for classic tools
    bat \
    eza \
    # Network tools
    openssh-client \
    netcat-openbsd \
    # Text editors
    vim \
    neovim \
    # User management
    sudo \
    # Compression
    unzip \
    tar \
    gzip \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Create symlinks for fd (Ubuntu packages it as fdfind)
RUN ln -sf $(which fdfind) /usr/local/bin/fd || true

# ============================================================================
# Layer 0.2: Container User Setup
# ============================================================================
# Create vscode user with sudo access (standard for DevContainers)
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

# ============================================================================
# Layer 0.3: Modern Language Runtimes (Latest from Upstream)
# ============================================================================

# --- Python (via uv - modern Python package and project manager) ---
USER root
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /usr/local/bin/ \
    && mv /root/.local/bin/uvx /usr/local/bin/ \
    && uv python install 3.12 \
    && ln -sf /root/.local/share/uv/python/cpython-3.12*/bin/python3 /usr/local/bin/python3 \
    && ln -sf /usr/local/bin/python3 /usr/local/bin/python \
    && ln -sf /root/.local/share/uv/python/cpython-3.12*/bin/pip3 /usr/local/bin/pip3 \
    && ln -sf /usr/local/bin/pip3 /usr/local/bin/pip

# --- Node.js (via fnm - Fast Node Manager) ---
ENV FNM_DIR="/usr/local/share/fnm"
RUN curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell \
    && eval "$("$FNM_DIR/fnm" env)" \
    && "$FNM_DIR/fnm" install --lts \
    && "$FNM_DIR/fnm" use lts-latest \
    && ln -sf "$FNM_DIR/aliases/lts-latest/bin/node" /usr/local/bin/node \
    && ln -sf "$FNM_DIR/aliases/lts-latest/bin/npm" /usr/local/bin/npm \
    && ln -sf "$FNM_DIR/aliases/lts-latest/bin/npx" /usr/local/bin/npx

# --- Go (official binary release) ---
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

# --- Rust (via rustup) ---
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --no-modify-path \
    && ln -sf /usr/local/cargo/bin/rustc /usr/local/bin/rustc \
    && ln -sf /usr/local/cargo/bin/cargo /usr/local/bin/cargo \
    && ln -sf /usr/local/cargo/bin/rustup /usr/local/bin/rustup \
    && chmod -R a+rX /usr/local/cargo /usr/local/rustup

# ============================================================================
# Layer 0.4: Development Tools (Latest from Upstream)
# ============================================================================

# --- GitHub CLI ---
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# --- Starship prompt ---
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes

# --- direnv (for .envrc file support) ---
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64) DIRENV_ARCH="amd64" ;; \
        aarch64|arm64) DIRENV_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/direnv/direnv/releases/latest/download/direnv.linux-${DIRENV_ARCH}" -o /usr/local/bin/direnv \
    && chmod +x /usr/local/bin/direnv

# ============================================================================
# Layer 0.5: Shell Environment Configuration
# ============================================================================

# Configure bash to load direnv automatically
RUN echo 'eval "$(direnv hook bash)"' >> /etc/bash.bashrc

# Configure starship prompt for bash
RUN echo 'eval "$(starship init bash)"' >> /etc/bash.bashrc

# Ensure ~/.local/bin is in PATH for all users (used by feature extensions)
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /etc/bash.bashrc

# Set up user-specific configurations
USER $USERNAME
WORKDIR /home/$USERNAME

RUN mkdir -p ~/.config/direnv

# Initialize starship for user
RUN mkdir -p ~/.config \
    && starship preset nerd-font-symbols -o ~/.config/starship.toml

# Create .local/bin directory (used by feature extensions)
RUN mkdir -p ~/.local/bin

# ============================================================================
# Layer 0.6: Container Runtime Configuration
# ============================================================================

# Set default shell
SHELL ["/bin/bash", "-c"]

# Set working directory to /workspace (standard for DevContainers)
WORKDIR /workspace

# Keep container running
CMD ["sleep", "infinity"]
