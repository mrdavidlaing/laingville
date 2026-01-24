# Ubuntu Implementation: Rapid Development Mode

This document details the **Ubuntu-based implementation** of the DevContainer architecture. This is the **Development Mode** (Layer 0 Bedrock) designed for speed, familiarity, and access to the latest tooling.

## Overview

The Ubuntu implementation prioritizes **developer velocity** and **AI agent compatibility**. It uses a "Modernized Ubuntu" strategy: a stable LTS foundation combined with scripts that fetch the latest tools directly from upstream.

### Key Technologies
- **Ubuntu 24.04 LTS**: The industry-standard base for high agent compatibility.
- **Apt**: For stable system dependencies (glibc, git, curl).
- **Direct Upstream Fetching**: Using `curl`, `uv`, `nvm`, and `gh` to get the latest versions.
- **Runtime Installation**: Tools are installed when the container is built/started, ensuring freshness.

---

## Bedrock Image (Layer 0)

The Bedrock image is defined via a standard Dockerfile. It merges the OS and the core toolset.

### 1. The Stable Foundation
We start with a minimal Ubuntu LTS image and install essential system utilities:

```dockerfile
FROM ubuntu:24.04

# Core system dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates curl git jq ripgrep fd-find fzf bat eza \
    build-essential cmake ninja-build \
    sudo zsh locales \
    && rm -rf /var/lib/apt/lists/*
```

### 2. The Pioneer Layer (Fresh Tools)
Instead of older `apt` packages, we use installers that track the edge:

- **Python**: Use `uv` for lightning-fast, latest-version Python management.
- **Node.js**: Use `nvm` or `fnm` to manage Node versions.
- **Go/Rust**: Use official `rustup` and `go` binary releases.

---

## Feature Extensions (Layer 1)

In Development Mode, features are installed via the `install.sh` interface at runtime.

### 1. The Interface
Every feature must provide an `install.sh` that detects it is running in an Ubuntu environment.

### 2. Implementation Pattern
```bash
# Example: feature/pensive-assistant/install.sh (Ubuntu branch)
if [ -f /etc/os-release ] && grep -q "ubuntu" /etc/os-release; then
    # Install beads via direct binary download
    curl -L https://github.com/steveyegge/beads/releases/latest/download/bd-linux-amd64 -o /usr/local/bin/bd
    chmod +x /usr/local/bin/bd
    
    # Install zellij and lazygit via apt or direct download
    apt-get update && apt-get install -y zellij lazygit
fi
```

---

## Workflow

### Local Iteration
1. **Open in Container**: VS Code builds the Dockerfile.
2. **Freshness**: You get the latest tool versions available on that day.
3. **Agent Confidence**: AI agents find a standard Ubuntu environment where `apt-get` and common paths work as expected.

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
