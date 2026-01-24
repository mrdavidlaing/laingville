# Creating a Nix-based Feature Extension

This guide walks through creating a new **Layer 1 Feature Extension** using the Nix backend.

## 1. Directory Structure

Create a new directory in `.devcontainer/features/` or within a project:

```
my-feature/
├── devcontainer-feature.json
├── flake.nix
├── install.sh
├── build-delta-tarball.sh  # Copy from pensive-assistant
└── test.sh
```

## 2. Define the Tools (`flake.nix`)

The `flake.nix` defines exactly what tools are included in the feature. It should use `buildEnv` to create a unified environment.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11-small";
  };

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.default = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in pkgs.buildEnv {
      name = "my-tools";
      paths = [ pkgs.my-tool-1 pkgs.my-tool-2 ];
    };
  };
}
```

## 3. The Build Script (`build-delta-tarball.sh`)

This script is the engine of our "Secure Mode" features. It performs the following:
1. **Snapshots** the current `/nix/store` (usually running inside the Bedrock devcontainer).
2. **Builds** the feature environment.
3. **Computes the Delta**: It finds the store paths that are in the feature's closure but *not* in the base image.
4. **Packages**: It creates a tarball containing only those delta paths.

**Crucial:** This ensures we don't duplicate the 500MB of "base" Nix paths in every 10MB feature extension.

## 4. The Orchestrator (`install.sh`)

The `install.sh` script is what the DevContainer CLI executes. It must handle two scenarios:

### Local/Dev Build
If the tarball hasn't been built yet, it can fallback to building at runtime (if Nix is present).

### OCI/Secure Build
In production, it:
1. Pulls the tarball (or uses the one provided by the feature bundle).
2. Extracts it to `/`. Since it only contains `/nix/store` paths, it's safe.
3. Configures the environment (PATH).
4. Creates user-space symlinks if necessary (e.g., to `~/.local/bin`).

## 5. Publishing

Features should be published to an OCI registry (like GHCR). 

```bash
# Example publishing using oras
oras push ghcr.io/org/my-feature:latest-amd64 \
  dist/tarball.tar.gz:application/gzip \
  dist/env-path:text/plain
```

## Best Practices

- **Follow Bedrock nixpkgs**: Always use the same `nixpkgs` pin as the Bedrock image to maximize the "delta" efficiency.
- **Atomic Tarballs**: One feature = one purpose.
- **Multi-arch**: Always build for both `x86_64-linux` and `aarch64-linux`.
- **Test in Base**: Always run your `test.sh` inside the actual Bedrock image to ensure there are no missing library dependencies.
