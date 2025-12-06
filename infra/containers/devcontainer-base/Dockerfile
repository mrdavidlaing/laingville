# infra/containers/devcontainer-base/Dockerfile
# DevContainer base with pre-cached /nix/store for fast startup
# Uses official nixos/nix image - pure Nix, no Debian/apt
ARG NIX_VERSION=2.32.4
FROM nixos/nix:${NIX_VERSION}

# Install shadow for user management (needed for vscode user)
RUN nix profile install nixpkgs#shadow nixpkgs#sudo nixpkgs#bashInteractive

# Create vscode user (standard devcontainer user)
RUN groupadd -r vscode && \
    useradd -r -g vscode -G wheel -d /home/vscode -s /bin/bash -m vscode && \
    echo 'vscode ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    chown -R vscode:vscode /nix

# Configure Nix for flakes
RUN mkdir -p /root/.config/nix && \
    echo 'experimental-features = nix-command flakes' > /root/.config/nix/nix.conf && \
    echo 'accept-flake-config = true' >> /root/.config/nix/nix.conf

# Copy nix config to vscode user
USER vscode
WORKDIR /home/vscode

RUN mkdir -p ~/.config/nix && \
    echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf && \
    echo 'accept-flake-config = true' >> ~/.config/nix/nix.conf

# Set default channel to small for faster security updates
ENV NIX_PATH="nixpkgs=channel:nixos-25.11-small"
ENV PATH="/home/vscode/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH}"

# Install common tools into /nix/store (pre-cache)
RUN nix profile install \
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

# Ensure vscode owns all of /nix (including any new files)
USER root
RUN chown -R vscode:vscode /nix
USER vscode

WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
