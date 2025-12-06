# infra/containers/base/Dockerfile
# Layer 1: Base image with Nix + direnv
# Uses official nixos/nix image - pure Nix, no Debian/apt
ARG NIX_VERSION=2.32.4
FROM nixos/nix:${NIX_VERSION}

# Configure Nix for flakes (nixos/nix has Nix pre-installed)
RUN mkdir -p /root/.config/nix && \
    echo 'experimental-features = nix-command flakes' > /root/.config/nix/nix.conf && \
    echo 'accept-flake-config = true' >> /root/.config/nix/nix.conf

# Set default channel to small for faster security updates
ENV NIX_PATH="nixpkgs=channel:nixos-25.11-small"

# Install direnv and nix-direnv
RUN nix profile install \
      nixpkgs#direnv \
      nixpkgs#nix-direnv

# Configure direnv
RUN mkdir -p /root/.config/direnv && \
    echo 'source /root/.nix-profile/share/nix-direnv/direnvrc' > /root/.config/direnv/direnvrc

WORKDIR /workspace
