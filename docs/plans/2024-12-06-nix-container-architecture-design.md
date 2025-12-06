# Nix Container Architecture Design

## Overview

A **project-centric** container architecture using pure Nix. Infrastructure provides **package sets** (building blocks) and **builder functions**. Projects compose these to create **project-specific** devcontainer and runtime images with **maximum Docker layer sharing**.

## Goals

1. **Reproducibility**: Identical builds locally, in CI, and in production via Nix flakes
2. **Security**: Fast CVE patches via `nixos-25.11-small` channel + manual overlays for critical issues
3. **Developer experience**: Git clone, open VS Code, container ready in <30 seconds
4. **Docker layer caching**: Shared nixpkgs pin = shared `/nix/store` paths = shared Docker layers
5. **Accurate SBOMs**: Each project's image = exact Nix closure = perfect dependency tracking

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  infra/flake.nix (single source of truth)                           │
│                                                                     │
│  nixpkgs pinned @ nixos-25.11-small (weekly updates via CI)         │
│                                                                     │
│  Package Sets:                    Builder Functions:                │
│  ├── base                         ├── mkDevContainer { packages }   │
│  ├── devTools                     └── mkRuntime { packages }        │
│  ├── python                                                         │
│  ├── pythonDev                                                      │
│  ├── node                                                           │
│  ├── nodeDev                                                        │
│  └── ...                                                            │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ inputs.nixpkgs.follows = "infra/nixpkgs"
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  project/flake.nix                                                  │
│                                                                     │
│  packages = sets.base ++ sets.python ++ sets.pythonDev;            │
│                                                                     │
│  devcontainer = infra.lib.mkDevContainer { inherit packages; };    │
│  runtime = infra.lib.mkRuntime { packages = sets.base ++ python; };│
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Project-specific images (built by project's CI)                    │
│                                                                     │
│  ghcr.io/org/wctf/devcontainer:latest                              │
│  ghcr.io/org/wctf/runtime:latest                                   │
└─────────────────────────────────────────────────────────────────────┘
```

## Why Project-Specific Images?

| Approach | Pros | Cons |
|----------|------|------|
| **Generic images** (runtime-python) | Simple, fewer images | Bloated, inaccurate SBOM, one-size-fits-none |
| **Project-specific images** | Exact deps, accurate SBOM, minimal size | More images, project CI builds them |

We chose **project-specific** because:
- Each project gets exactly what it needs
- SBOM is accurate (image = project's Nix closure)
- Smaller images (no unused packages)
- Clear ownership (project defines and builds its images)

## Docker Layer Caching Strategy

### The Key Insight

Docker layers are shared when they have **identical content**. Nix store paths are **content-addressed** - same inputs = same `/nix/store/hash-name`.

**If all projects use the same nixpkgs pin, they get identical store paths for shared packages.**

### How It Works

```
infra/flake.nix:
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11-small";
  # Pinned at commit abc123

project-a/flake.nix:
  inputs.nixpkgs.follows = "infra/nixpkgs";  # Same abc123
  # python312 → /nix/store/xyz-python312

project-b/flake.nix:
  inputs.nixpkgs.follows = "infra/nixpkgs";  # Same abc123
  # python312 → /nix/store/xyz-python312  ← IDENTICAL HASH

Result: Project A and B share the python312 Docker layer
```

### Layer Structure

```
Project A (Python + Redis):
┌────────────────────────────────────────────┐
│ Layers 1-30:  base (bash, coreutils, etc.) │ ← Shared with ALL projects
│ Layers 31-50: python312, pip               │ ← Shared with Python projects
│ Layers 51-55: redis                        │ ← Project A only
└────────────────────────────────────────────┘

Project B (Python + Postgres):
┌────────────────────────────────────────────┐
│ Layers 1-30:  base (bash, coreutils, etc.) │ ← CACHED (same as A)
│ Layers 31-50: python312, pip               │ ← CACHED (same as A)
│ Layers 51-55: postgres                     │ ← Project B only
└────────────────────────────────────────────┘

When Project B pulls: Only layers 51-55 downloaded!
```

## Package Sets

Infrastructure defines **composable package sets** - building blocks for container images:

```nix
# infra/flake.nix
packageSets = {
  # Foundation (always included)
  base = with pkgs; [
    bashInteractive
    coreutils
    findutils
    gnugrep
    gnused
    cacert
    tzdata
  ];

  # Development tools (for devcontainers)
  devTools = with pkgs; [
    git
    curl
    jq
    ripgrep
    fd
    fzf
    bat
    shadow
    sudo
  ];

  # Nix tooling (for containers that need nix develop)
  nixTools = with pkgs; [
    nix
    direnv
    nix-direnv
  ];

  # Language: Python
  python = with pkgs; [
    python312
  ];
  pythonDev = with pkgs; [
    python312Packages.pip
    python312Packages.virtualenv
    uv
    ruff
    pyright
  ];

  # Language: Node
  node = with pkgs; [
    nodejs_22
  ];
  nodeDev = with pkgs; [
    bun
    nodePackages.typescript
    nodePackages.prettier
    nodePackages.eslint
  ];

  # Language: Go
  go = with pkgs; [
    go
  ];
  goDev = with pkgs; [
    gopls
    golangci-lint
  ];

  # Language: Rust
  rust = with pkgs; [
    rustc
    cargo
  ];
  rustDev = with pkgs; [
    rust-analyzer
    clippy
    rustfmt
  ];
};
```

## Builder Functions

Infrastructure provides **builder functions** that take package sets and produce container images:

### mkDevContainer

Creates a development container with:
- vscode user (uid 1000)
- sudo access
- direnv hook in bashrc
- Nix configured for flakes

```nix
mkDevContainer = {
  packages,
  name ? "devcontainer",
  user ? "vscode",
  extraConfig ? {}
}: pkgs.dockerTools.buildLayeredImage {
  inherit name;
  tag = "latest";
  contents = packages ++ [
    (mkUser { name = user; uid = 1000; gid = 1000; home = "/home/${user}"; })
    (mkBashrc { inherit user; })
    (mkNixConf { })
    (mkDirenvConf { })
  ];
  config = {
    User = user;
    WorkingDir = "/workspace";
    Env = [
      "HOME=/home/${user}"
      "USER=${user}"
      "PATH=/home/${user}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
      "NIX_PATH=nixpkgs=channel:nixos-25.11-small"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
  } // extraConfig;
  maxLayers = 100;
};
```

### mkRuntime

Creates a minimal production container with:
- app user (uid 1000, non-root)
- No development tools
- No Nix (unless explicitly included)

```nix
mkRuntime = {
  packages,
  name ? "runtime",
  user ? "app",
  workdir ? "/app",
  extraConfig ? {}
}: pkgs.dockerTools.buildLayeredImage {
  inherit name;
  tag = "latest";
  contents = packages ++ [
    (mkUser { name = user; uid = 1000; gid = 1000; home = workdir; })
  ];
  config = {
    User = user;
    WorkingDir = workdir;
    Env = [
      "HOME=${workdir}"
      "USER=${user}"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
  } // extraConfig;
  maxLayers = 50;
};
```

## Project Usage

### Project flake.nix

```nix
{
  description = "WCTF - World Championship of Transformative Facilitation";

  inputs = {
    infra.url = "github:mrdavidlaing/laingville?dir=infra";
    nixpkgs.follows = "infra/nixpkgs";  # Critical for layer sharing!
  };

  outputs = { self, infra, nixpkgs }:
    let
      system = "x86_64-linux";
      sets = infra.packageSets.${system};
      lib = infra.lib.${system};
    in
    {
      # DevShell for local development (nix develop)
      devShells.${system}.default = infra.devShells.${system}.python;

      # Container images (built by CI, pushed to registry)
      packages.${system} = {
        devcontainer = lib.mkDevContainer {
          name = "ghcr.io/mrdavidlaing/wctf/devcontainer";
          packages = sets.base ++ sets.nixTools ++ sets.devTools
                  ++ sets.python ++ sets.pythonDev;
        };

        runtime = lib.mkRuntime {
          name = "ghcr.io/mrdavidlaing/wctf/runtime";
          packages = sets.base ++ sets.python;
        };
      };
    };
}
```

### Project devcontainer.json

```json
{
  "name": "WCTF",
  "image": "ghcr.io/mrdavidlaing/wctf/devcontainer:latest",
  "postStartCommand": "direnv allow",
  "remoteUser": "vscode",
  "mounts": [
    "source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly"
  ],
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-python.vscode-pylance",
        "charliermarsh.ruff"
      ]
    }
  }
}
```

### Project CI

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Install Nix
        uses: DeterminateSystems/nix-installer-action@main

      - name: Setup Nix cache
        uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Build devcontainer
        run: nix build .#devcontainer -o devcontainer.tar.gz

      - name: Build runtime
        run: nix build .#runtime -o runtime.tar.gz

      - name: Login to ghcr.io
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Push images
        run: |
          docker load < devcontainer.tar.gz
          docker push ghcr.io/mrdavidlaing/wctf/devcontainer:latest

          docker load < runtime.tar.gz
          docker push ghcr.io/mrdavidlaing/wctf/runtime:latest
```

## CVE Handling

**Pure Nix approach with small channels**:

1. **Primary defense**: Use `nixos-25.11-small` channel for fast upstream patches (hours vs days)
2. **Automated updates**: Weekly `nix flake update` PRs in infra repo
3. **Propagation**: Projects inherit updates via `nixpkgs.follows`
4. **Scanning**: Run OSV Scanner in CI to detect known CVEs
5. **Manual patches**: For Critical/High CVEs not yet in nixpkgs, add to `infra/overlays/cve-patches.nix`
6. **Cleanup**: Remove local patches once upstream catches up

**Update flow:**
```
infra: weekly flake update → new nixpkgs pin
                ↓
projects: CI detects new infra → rebuilds images
                ↓
new images pushed to registry with patched packages
```

## Repository Structure

```
laingville/
├── infra/
│   ├── flake.nix              # Package sets + builder functions
│   ├── flake.lock             # Pinned nixpkgs (single source of truth)
│   ├── overlays/
│   │   ├── default.nix
│   │   ├── cve-patches.nix
│   │   ├── license-fixes.nix
│   │   └── custom-builds.nix
│   └── README.md
├── .github/
│   └── workflows/
│       ├── update-nixpkgs.yml    # Weekly flake.lock update
│       └── security-scan.yml     # Daily CVE scanning
└── ...

project-repo/  (e.g., wctf)
├── flake.nix                     # Uses infra's package sets + builders
├── flake.lock                    # Follows infra/nixpkgs
├── .devcontainer/
│   └── devcontainer.json         # Points to project's devcontainer image
├── .github/
│   └── workflows/
│       └── ci.yml                # Builds & pushes project's images
└── ...
```

## Decisions Summary

| Area | Decision |
|------|----------|
| **Architecture** | Project-specific images built from shared package sets |
| **Layer sharing** | All projects follow `infra/nixpkgs` for identical store paths |
| **Package sets** | Composable building blocks defined in infra |
| **Builder functions** | `mkDevContainer` and `mkRuntime` in infra |
| **Image builder** | `dockerTools.buildLayeredImage` (no Dockerfiles) |
| **Nixpkgs channel** | `nixos-25.11-small` (fast security updates) |
| **Image ownership** | Projects build and push their own images |
| **CI cache** | Docker registry (ubiquitous) + magic-nix-cache |
| **CVE handling** | Small channel + weekly updates + overlays for critical |

## Benefits

1. **Docker caching works**: Shared nixpkgs = shared layers across all projects
2. **Accurate SBOMs**: Each image = exact Nix closure
3. **Minimal images**: Projects include only what they need
4. **Fast developer onboarding**: Pre-built images, no nix at container start
5. **Clear ownership**: Projects control their dependencies
6. **Single update path**: Update infra → all projects get security fixes

## Future Considerations

- Add more package sets (java, cobol, rust, go)
- VS Code extensions in package sets (via DevContainer features or direct)
- Multi-arch support (aarch64-linux)
- Cachix/FlakeHub for faster CI if magic-nix-cache insufficient
- SBOM generation from Nix closure for compliance
