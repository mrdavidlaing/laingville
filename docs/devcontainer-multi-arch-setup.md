# Multi-Architecture Devcontainer Setup for M2 Mac

## Goal

Enable local development of Linux containers on M2 Mac (ARM64) with native performance by building `aarch64-linux` containers locally, while maintaining compatibility with x86_64 systems through multi-architecture container images.

### Desired Outcome

- **Local Development**: Build `aarch64-linux` containers on M2 Mac with native performance
- **CI/CD**: Build both `aarch64-linux` and `x86_64-linux` container images in GitHub Actions
- **Automatic Selection**: Docker automatically pulls the correct architecture image
- **Developer Experience**: Fast iteration cycles without waiting for CI builds

## Solution: Colima + Build-in-VM

We use **Colima** as a unified Docker runtime and Linux build environment. The container is built directly inside the Colima VM (which runs aarch64-linux natively), then loaded into Docker.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  M2 Mac (aarch64-darwin)                                    │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  Colima VM (aarch64-linux, Apple Virtualization)       │ │
│  │                                                        │ │
│  │  /Users/... ← virtiofs mount (same paths as macOS)    │ │
│  │                                                        │ │
│  │  ┌─────────────┐    ┌─────────────────────────────┐  │ │
│  │  │ Docker      │    │ Nix                          │  │ │
│  │  │ daemon      │    │ nix build → .tar.gz          │  │ │
│  │  └─────────────┘    └─────────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────┘ │
│           │                        │                        │
│           │ docker context         │ ssh + stream           │
│           ▼                        ▼                        │
│  Docker CLI ←──────────────── docker load                   │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Install Colima

```bash
brew install colima docker
```

### 2. Create the Nix Builder VM

```bash
./infra/scripts/colima-vm create
```

This creates a Colima VM with Nix installed and configured.

### 3. Build Containers

```bash
# Build the devcontainer (and push to Cachix)
./infra/scripts/build-in-colima laingville-devcontainer local

# Or the Python runtime
./infra/scripts/build-in-colima example-python-runtime local
```

### 4. Use the Container

```bash
# Run directly
docker run --rm -it ghcr.io/mrdavidlaing/laingville/laingville-devcontainer:local bash

# Or in .devcontainer/devcontainer.json
{
  "image": "ghcr.io/mrdavidlaing/laingville/laingville-devcontainer:local"
}
```

## The Build Script

The `build-in-colima` script handles everything:

```bash
./infra/scripts/build-in-colima [package] [tag]
./infra/scripts/build-in-colima --no-push [package] [tag]  # Skip Cachix push
```

**What it does:**
1. Checks if Colima is running
2. Configures Cachix in the VM (using your macOS auth token)
3. SSHs into VM and runs `nix build` (pulls from cache.nixos.org + mrdavidlaing)
4. Pushes build results to Cachix (default, speeds up future builds)
5. Streams the tarball to `docker load`
6. Tags the image

**Environment variables:**
- `COLIMA_INSTANCE` - Override the instance name (default: `nix-builder`)
- `CACHIX_NAME` - Cache name (default: `mrdavidlaing`)
- `CACHIX_AUTH_TOKEN` - Override token (default: read from `~/.config/cachix/cachix.dhall`)

## Cachix Integration

The build script automatically uses your private Cachix cache for faster builds.

### How It Works

1. **Downloads from caches:**
   - `cache.nixos.org` - Standard nixpkgs packages (python, bash, etc.)
   - `mrdavidlaing.cachix.org` - Your custom packages

2. **Pushes after build:**
   - All custom derivations are pushed to `mrdavidlaing`
   - Next build (same commit) fetches instead of rebuilds

### Prerequisites

You need Cachix configured on macOS:

```bash
# Install and authenticate
nix profile install nixpkgs#cachix
cachix authtoken <your-token>

# Configure nix to use your cache
cachix use mrdavidlaing
```

The build script reads your token from `~/.config/cachix/cachix.dhall` and your cache config from `~/.config/nix/nix.conf`.

### Cache Hit Requirements

For cache hits on custom packages, the **Git tree must be clean** (committed). A dirty tree changes derivation hashes, making cached paths unusable.

```bash
# Commit first, then build
git add -A && git commit -m "My changes"
./infra/scripts/build-in-colima laingville-devcontainer

# Future builds with same commit will use cache
```

### Disable Pushing

For quick iteration without pushing:

```bash
./infra/scripts/build-in-colima --no-push laingville-devcontainer local
```

## Managing the VM

Use the `colima-vm` script:

```bash
./infra/scripts/colima-vm create   # Create and configure VM with Nix
./infra/scripts/colima-vm start    # Start existing VM
./infra/scripts/colima-vm stop     # Stop VM (preserves data)
./infra/scripts/colima-vm delete   # Delete VM completely
./infra/scripts/colima-vm status   # Show VM status
./infra/scripts/colima-vm ssh      # SSH into VM
```

Or use Colima directly:

```bash
colima list
colima ssh nix-builder
```

## Colima vs Docker Desktop

| Feature | Docker Desktop | Colima |
|---------|---------------|--------|
| License | Free personal, paid business | MIT (free) |
| VM Technology | Apple Hypervisor | Apple Virtualization (vz) |
| Resource usage | ~2GB RAM idle | Configurable |
| Nix builds | Separate VM needed | Same VM |
| GUI | Yes | No (CLI only) |

## CI/CD

GitHub Actions builds containers on Linux runners:
- `ubuntu-latest` for x86_64-linux
- ARM64 runners available for aarch64-linux (free for public repos)

The local Colima setup is for fast iteration during development.

## Troubleshooting

### Colima won't start

```bash
./infra/scripts/colima-vm stop --force
./infra/scripts/colima-vm start
```

### Nix not found in VM

```bash
# Recreate the VM
./infra/scripts/colima-vm delete
./infra/scripts/colima-vm create
```

### Build fails with network error

Some upstream sources may be temporarily unavailable. The Nix binary cache (`cache.nixos.org`) usually works; failures are typically from source tarballs.

### Wrong Docker context

```bash
docker context use colima-nix-builder
```
