# Ubuntu Implementation: Rapid Development Mode

This document details the **Ubuntu-based implementation** of the DevContainer architecture. This is the **Development Mode** (Layer 0 Bedrock) designed for speed, familiarity, and access to the latest tooling.

## Overview

The Ubuntu implementation prioritizes **developer velocity** and **AI agent compatibility**. It uses a "Modernized Ubuntu" strategy: a stable LTS foundation combined with scripts that fetch the latest tools directly from upstream.

### Key Technologies
- **Ubuntu 24.04 LTS**: The industry-standard base for high agent compatibility.
- **Apt**: For stable system dependencies (glibc, git, curl).
- **Direct Upstream Fetching**: Using `curl`, `uv`, `fnm`, `rustup`, and official binary releases.
- **Runtime Installation**: Tools are installed when the container is built, ensuring freshness.

---

## Bedrock Image (Layer 0)

The Bedrock image is defined in `.devcontainer/ubuntu.Dockerfile`. It builds on Ubuntu LTS with layered tool installation.

### Layer 0.1: Stable System Foundation

Core utilities installed via apt from Ubuntu repositories:

```dockerfile
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
```

### Layer 0.2: Container User Setup

Creates a standard `vscode` user with sudo access:

```dockerfile
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN set -ex \
    && if getent group "$USER_GID" >/dev/null 2>&1; then \
        existing_group=$(getent group "$USER_GID" | cut -d: -f1); \
        groupmod -g "99${USER_GID}" "$existing_group"; \
    fi \
    && if getent passwd "$USER_UID" >/dev/null 2>&1; then \
        existing_user=$(getent passwd "$USER_UID" | cut -d: -f1); \
        usermod -u "99${USER_UID}" "$existing_user"; \
    fi \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME
```

### Layer 0.3: Modern Language Runtimes (Latest from Upstream)

Instead of older `apt` packages, we use installers that track the edge:

#### Python (via uv)

```dockerfile
# Python via uv - modern Python package and project manager
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /usr/local/bin/ \
    && mv /root/.local/bin/uvx /usr/local/bin/ \
    && uv python install 3.12 \
    && ln -sf /root/.local/share/uv/python/cpython-3.12*/bin/python3 /usr/local/bin/python3 \
    && ln -sf /usr/local/bin/python3 /usr/local/bin/python \
    && ln -sf /root/.local/share/uv/python/cpython-3.12*/bin/pip3 /usr/local/bin/pip3 \
    && ln -sf /usr/local/bin/pip3 /usr/local/bin/pip
```

#### Node.js (via fnm - Fast Node Manager)

```dockerfile
ENV FNM_DIR="/usr/local/share/fnm"
RUN curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell \
    && eval "$("$FNM_DIR/fnm" env)" \
    && "$FNM_DIR/fnm" install --lts \
    && "$FNM_DIR/fnm" use lts-latest \
    && ln -sf "$FNM_DIR/aliases/lts-latest/bin/node" /usr/local/bin/node \
    && ln -sf "$FNM_DIR/aliases/lts-latest/bin/npm" /usr/local/bin/npm \
    && ln -sf "$FNM_DIR/aliases/lts-latest/bin/npx" /usr/local/bin/npx
```

#### Go (official binary release)

```dockerfile
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
```

#### Rust (via rustup)

```dockerfile
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --no-modify-path \
    && ln -sf /usr/local/cargo/bin/rustc /usr/local/bin/rustc \
    && ln -sf /usr/local/cargo/bin/cargo /usr/local/bin/cargo \
    && ln -sf /usr/local/cargo/bin/rustup /usr/local/bin/rustup \
    && chmod -R a+rX /usr/local/cargo /usr/local/rustup
```

### Layer 0.4: Development Tools (Latest from Upstream)

```dockerfile
# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Starship prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes

# direnv (for .envrc file support)
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64) DIRENV_ARCH="amd64" ;; \
        aarch64|arm64) DIRENV_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/direnv/direnv/releases/latest/download/direnv.linux-${DIRENV_ARCH}" -o /usr/local/bin/direnv \
    && chmod +x /usr/local/bin/direnv
```

### Layer 0.5: Shell Environment Configuration

```dockerfile
# Configure bash to load direnv automatically
RUN echo 'eval "$(direnv hook bash)"' >> /etc/bash.bashrc

# Configure starship prompt for bash
RUN echo 'eval "$(starship init bash)"' >> /etc/bash.bashrc

# Ensure ~/.local/bin is in PATH for all users (used by feature extensions)
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /etc/bash.bashrc
```

---

## Feature Extensions (Layer 1)

In Development Mode, features are installed via the `install.sh` interface at runtime.

### pensive-assistant Feature (Ubuntu Mode)

The pensive-assistant feature (`/.devcontainer/features/pensive-assistant/`) supports both Nix and Ubuntu modes. The mode is detected by the `MODE` environment variable in `install.sh`:

```bash
MODE="${MODE:-nix}"

if [ "$MODE" = "ubuntu" ]; then
  echo "Mode: ubuntu (Development Mode)"
  exec "${FEATURE_DIR}/install-ubuntu.sh"
fi
```

#### Ubuntu Mode Installation

When `MODE=ubuntu`, the feature runs `install-ubuntu.sh` which installs the following tools directly from GitHub releases:

| Tool | Installation Method | Description |
|------|---------------------|-------------|
| **beads (bd)** | GitHub release tarball | Issue tracking CLI |
| **zellij** | GitHub release tarball | Terminal multiplexer |
| **lazygit** | GitHub release tarball | Git TUI |
| **bun** | Official installer script | JavaScript runtime |
| **opencode** | `bun add -g opencode-ai` | AI coding assistant |
| **claude** | `bun add -g @anthropic-ai/claude-code` | Anthropic's Claude Code CLI |

Example from the actual `install-ubuntu.sh`:

```bash
install_beads() {
  echo "Installing beads (bd)..."
  local version="${BEADS_VERSION:-latest}"

  if [ "$version" = "latest" ]; then
    local latest_tag=$(curl -fsSL https://api.github.com/repos/steveyegge/beads/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    version="${latest_tag#v}"
  else
    version="${version#v}"
  fi

  local archive="beads_${version}_linux_${BINARY_ARCH}.tar.gz"
  local url="https://github.com/steveyegge/beads/releases/download/v${version}/${archive}"

  curl -fsSL "$url" | tar -xz -C "${REMOTE_HOME}/.local/bin" bd
  chmod +x "${REMOTE_HOME}/.local/bin/bd"
  echo "  ✓ beads ${version} installed"
}
```

Tools are installed to `~/.local/bin` and `~/.bun/bin`, with PATH configured in `~/.bashrc` and `~/.profile`.

---

## Workflow

### Local Iteration
1. **Open in Container**: VS Code builds the Dockerfile from `.devcontainer/ubuntu/`.
2. **Freshness**: You get the latest tool versions available at build time.
3. **Agent Confidence**: AI agents find a standard Ubuntu environment where `apt-get` and common paths work as expected.

### Using the ctl Tool

The preferred interface for managing the DevContainer is the `ctl` tool:

```bash
.devcontainer/bin/ctl up      # Start container with credential forwarding
.devcontainer/bin/ctl shell   # Open interactive shell
.devcontainer/bin/ctl down    # Stop container
.devcontainer/bin/ctl status  # Show service health
```

See [docs/ctl-usage.md](../../ctl-usage.md) for full documentation.

### Transitioning to Secure Mode
When a project matures, you can "harden" it by:
1. Identifying the versions installed in Dev Mode.
2. Creating a Nix `flake.lock` with those exact versions.
3. Switching the `devcontainer.json` image to the Nix-built Bedrock.

---

## Why Use the Ubuntu Implementation?

1. **Agent Native**: Most LLMs "think" in Ubuntu. Commands like `sudo apt-get install` are their default reflex.
2. **Infinite Flexibility**: No need to learn Nix expressions to add a new tool; just add a `RUN` command or a `curl` call.
3. **Latest & Greatest**: Get the very latest features of tools the moment they are released.

---

## Security Considerations

⚠️ **Non-Reproducible**: Builds may drift over time as upstream repositories change.
⚠️ **No Native SBOM**: You must use external scanners (like Syft) to generate an SBOM after the build.
⚠️ **Internet Dependent**: Requires a stable connection during the build phase.
