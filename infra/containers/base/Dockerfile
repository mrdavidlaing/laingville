# infra/containers/base/Dockerfile
# Layer 1: Base image with Nix + direnv
ARG BASE_IMAGE=debian:bookworm-slim
FROM ${BASE_IMAGE} AS base

# Install Nix dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    xz-utils \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create nix user
RUN groupadd -r nix && useradd -r -g nix -d /nix -s /bin/bash nix
RUN mkdir -p /nix && chown -R nix:nix /nix

# Install Nix as single-user (simpler for containers)
USER nix
WORKDIR /nix
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# Configure Nix
RUN mkdir -p /home/nix/.config/nix
COPY --chown=nix:nix nix.conf /home/nix/.config/nix/nix.conf

# Add Nix to PATH
ENV PATH="/home/nix/.nix-profile/bin:${PATH}"
ENV NIX_PATH="nixpkgs=channel:nixos-24.11"

# Install direnv
RUN . /home/nix/.nix-profile/etc/profile.d/nix.sh && \
    nix profile install nixpkgs#direnv nixpkgs#nix-direnv

# Configure direnv
RUN mkdir -p /home/nix/.config/direnv && \
    echo 'source /home/nix/.nix-profile/share/nix-direnv/direnvrc' > /home/nix/.config/direnv/direnvrc

WORKDIR /workspace
