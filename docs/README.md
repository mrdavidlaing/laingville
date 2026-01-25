# Documentation Index

This directory contains evergreen documentation for the Laingville project.

## Getting Started

### [devcontainer-quickstart.md](devcontainer-quickstart.md)
5-minute setup guide for new users. Covers VS Code and CLI workflows with troubleshooting tips.

### [ctl-usage.md](ctl-usage.md)
CLI reference for the `.devcontainer/bin/ctl` tool. Commands for starting, stopping, and accessing the devcontainer with GitHub credential forwarding.

## Core Architecture

### [devcontainer.md](devcontainer.md)
Composable, reproducible development environment architecture with dual implementation modes (Nix secure mode and Ubuntu development mode).

### [devcontainer-multi-arch-setup.md](devcontainer-multi-arch-setup.md)
Multi-architecture container setup for M2 Mac with native ARM64 performance.

### [dns-concepts.md](dns-concepts.md)
DNS fundamentals for home network: forward/reverse zones and resolver configuration.

## Specifications

### [specs/devcontainer-feature.md](specs/devcontainer-feature.md)
Contract between Feature Extensions and DevContainer environment for cross-mode compatibility.

## Implementation Guides

### Nix Implementation (Secure Mode)

- **[implementations/nix/README.md](implementations/nix/README.md)** - Nix-based secure mode using flakes and dockerTools for reproducibility.
- **[implementations/nix/feature-creation.md](implementations/nix/feature-creation.md)** - Guide to creating Nix-based Layer 1 Feature Extensions.

### Ubuntu Implementation (Development Mode)

- **[implementations/ubuntu/README.md](implementations/ubuntu/README.md)** - Ubuntu 24.04 LTS base with direct upstream tool installation (uv, fnm, rustup, Go). Prioritizes developer velocity and AI agent compatibility.
- **[implementations/ubuntu/migration.md](implementations/ubuntu/migration.md)** - Migrating projects from Development Mode to Secure Mode.

## Historical Documentation

### [history/](history/)
AI-assisted work session artifacts: analysis documents, benchmark reports, troubleshooting notes, and implementation summaries. These capture the research and decision-making process behind configuration changes and system optimizations.

### [plans/](plans/)
Implementation plans and design documents from past development work.
