# Nix Implementation: Secure & Reproducible Mode

This document details the **Nix-based implementation** of the DevContainer architecture. This is the **Secure Mode** (Layer 0 Bedrock) and **Feature Extension** (Layer 1) backend.

## Overview

The Nix implementation leverages **Nix flakes** and `dockerTools` to create bit-for-bit reproducible environments. It is designed for production reliability, airgap compatibility, and maximum Docker layer sharing.

### Key Technologies
- **Nix Flakes**: Hermetic dependency management and version pinning.
- **dockerTools**: Building Docker images without a Docker daemon or Dockerfiles.
- **ORAS**: Distributing feature tarballs as OCI artifacts.
- **GitHub Container Registry (GHCR)**: Central storage for images and artifacts.

---

## Bedrock Image (Layer 0)

The Bedrock image is defined in `infra/flake.nix`. It consolidates the OS foundation and core tools into a single immutable image.

### 1. Composable Package Sets
Instead of a monolithic list, we define tools in composable sets:

```nix
packageSets = {
  base = [ pkgs.bashInteractive pkgs.coreutils pkgs.cacert ... ];
  devTools = [ pkgs.git pkgs.jq pkgs.ripgrep ... ];
  python = [ pkgs.python312 pkgs.python312Packages.pip ... ];
  # ... node, go, rust sets ...
};
```

### 2. Builder Functions
We provide standard functions to compose these sets into images:

- `lib.mkDevContainer`: Creates a rich environment with a `vscode` user, sudo access, and shell hooks.
- `lib.mkRuntime`: Creates a minimal, non-root image for production execution.

### 3. Docker Layer Sharing Strategy
The "magic" of our layer sharing comes from the **shared nixpkgs pin**.

- **Identical Inputs = Identical Store Paths**: By forcing all projects to follow `infra/nixpkgs`, shared tools (like Python) result in the exact same `/nix/store` hash.
- **Layer Optimization**: `dockerTools.buildLayeredImage` automatically places shared store paths into shared Docker layers.

---

## Feature Extensions (Layer 1)

Features are implemented as **Nix-built delta tarballs**.

### 1. Feature Structure
A Nix-powered feature (like `pensive-assistant`) contains:
- `devcontainer-feature.json`: Standard metadata.
- `flake.nix`: Defines the tool closure.
- `build-delta-tarball.sh`: The build logic.
- `install.sh`: The installation orchestration.

### 2. The Delta Optimization
To minimize bloat, we don't publish the full closure in the feature tarball. Instead, our build script:
1. Snapshots the store paths in the **Bedrock image**.
2. Builds the feature closure.
3. Computes the **delta** (paths present in feature but NOT in Bedrock).
4. Packages only the delta into the tarball.

This ensures that `install.sh` only extracts what is truly new, saving bandwidth and disk space.

### 3. OCI Distribution
Feature tarballs are published as OCI artifacts using `oras`. They are tagged by architecture (e.g., `latest-amd64`, `latest-arm64`) because Nix store paths are architecture-specific.

---

## Workflow

### Local Development
Developers can enter the environment without a container using:
```bash
nix develop .#python
```
This provides the exact same tool versions as the container, allowing for fast iteration before committing.

### CI/CD Pipeline
1. **Infrastructure Update**: Weekly `nix flake update` PRs rotate the bedrock versions.
2. **Build & Push**: GitHub Actions build the Bedrock and Features, then push to GHCR.
3. **Security Scan**: `osv-scanner` runs daily against `flake.lock` to detect CVEs in the closure.

### Project Integration
Projects use the infra flake as an input:

```nix
inputs.infra.url = "github:mrdavidlaing/laingville?dir=infra";
inputs.nixpkgs.follows = "infra/nixpkgs";
```

---

## Why Use the Nix Implementation?

1. **True Reproducibility**: No more "it works on my machine" because a background `apt update` changed a library version.
2. **Airgap Ready**: The entire closure is captured in the image or feature tarball.
3. **Verified SBOM**: Nix can generate a perfect manifest of every file and its source.
4. **Security Velocity**: Using `nixos-small` channels allows us to propagate security patches across all projects within hours.

---

## Maintenance

- **Update Pinned Versions**: `cd infra && nix flake update`
- **Add New Tool**: Edit `packageSets` in `infra/flake.nix`.
- **Patch a CVE**: Add an overlay in `infra/overlays/cve-patches.nix`.
