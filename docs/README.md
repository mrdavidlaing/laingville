# Documentation Index

This directory contains evergreen documentation for the Laingville project.

## Core Architecture

### [devcontainer.md](devcontainer.md)
Composable, reproducible development environment architecture with dual implementation modes.

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

- **[implementations/ubuntu/README.md](implementations/ubuntu/README.md)** - Ubuntu-based development mode prioritizing velocity and agent compatibility.
- **[implementations/ubuntu/migration.md](implementations/ubuntu/migration.md)** - Migrating projects from Development Mode to Secure Mode.

## Troubleshooting

### ShellSpec Issue #351 (WSL Reporter Bug)

- **[shellspec-issue-351-BREAKTHROUGH.md](shellspec-issue-351-BREAKTHROUGH.md)** - Minimal reproduction: WSL → Windows process boundary issue.
- **[shellspec-issue-351-FIX-CONFIRMED.md](shellspec-issue-351-FIX-CONFIRMED.md)** - Confirmed fix using native Linux PowerShell instead of Windows.
- **[shellspec-issue-351-WORKAROUND.md](shellspec-issue-351-WORKAROUND.md)** - Workaround guide: install native Linux PowerShell on WSL.

## Historical Documentation

The [plans/](plans/) directory contains implementation plans and design documents from past development work.
