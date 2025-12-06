# infra/containers/devcontainer-base/Dockerfile
# Layer 1 + pre-cached /nix/store for fast devcontainer startup
ARG BASE_IMAGE=debian:bookworm-slim
FROM ${BASE_IMAGE} AS nix-installer

# Install Nix dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    xz-utils \
    git \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create vscode user (standard devcontainer user)
RUN groupadd -r vscode && useradd -r -g vscode -G sudo -d /home/vscode -s /bin/bash -m vscode
RUN echo 'vscode ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Create nix directory
RUN mkdir -p /nix && chown -R vscode:vscode /nix

USER vscode
WORKDIR /home/vscode

# Install Nix
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# Configure Nix for flakes
RUN mkdir -p ~/.config/nix && \
    echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf && \
    echo 'accept-flake-config = true' >> ~/.config/nix/nix.conf

# Add Nix to PATH
ENV PATH="/home/vscode/.nix-profile/bin:${PATH}"

# Install common tools into /nix/store (pre-cache)
RUN . ~/.nix-profile/etc/profile.d/nix.sh && \
    nix profile install \
      nixpkgs#direnv \
      nixpkgs#nix-direnv \
      nixpkgs#git \
      nixpkgs#curl \
      nixpkgs#jq \
      nixpkgs#ripgrep \
      nixpkgs#fd \
      nixpkgs#fzf \
      nixpkgs#bat

# Configure direnv
RUN mkdir -p ~/.config/direnv && \
    echo 'source ~/.nix-profile/share/nix-direnv/direnvrc' > ~/.config/direnv/direnvrc

# Configure shell for direnv
RUN echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

# Ensure vscode owns all of /nix (including db created during install)
USER root
RUN chown -R vscode:vscode /nix
USER vscode

WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
