# Nix Container Architecture Design

## Overview

A layered container architecture using Nix for reproducible builds, supporting multiple development runtimes with CVE-managed base images and composable development environments.

## Goals

1. **Reproducibility**: Identical builds locally, in CI, and in production
2. **Security**: CVE-managed base images with defined patching process
3. **Developer experience**: Git clone, open VS Code, devcontainer ready
4. **Flexibility**: Support Python, Node/Bun, Go, Rust, Java, GnuCOBOL
5. **Minimal production images**: Only ship what's needed to run

## Layer Architecture

```
+-------------------------------------------------------------+
|  LAYER 3: DevShell (compilers + dev tools)                  |
|  - Bun, Go, Rust, GnuCOBOL/cobc, JDK, GraalVM               |
|  - LSPs, formatters, linters, debuggers                     |
|  - lazygit, neovim, tmux, shellspec                         |
|  NOT in production                                          |
+-------------------------------------------------------------+
|  LAYER 2: Runtime (interpreters + runtime libs)             |
|  - Python interpreter                                       |
|  - libcob (COBOL runtime library)                           |
|  - JRE (if not using GraalVM native-image)                  |
|  - Compiled binaries from Layer 3                           |
|  Shipped to production (project-specific subset)            |
+-------------------------------------------------------------+
|  LAYER 1: Base                                              |
|  - Distroless/Ubuntu (parameterized)                        |
|  - Nix + binary cache config + direnv                       |
|  - glibc, ca-certs, tzdata                                  |
|  Shipped to production                                      |
+-------------------------------------------------------------+
```

### Layer Details

**Layer 1 (Base)**: Provides the OS foundation with Nix package manager pre-configured. The base image is parameterized to allow switching between Google Distroless (default) and Ubuntu LTS (for FIPS compliance).

**Layer 2 (Runtime)**: Contains only interpreters and runtime libraries that cannot be statically compiled away. Compiled languages (Go, Rust, Bun) produce static binaries that need nothing from this layer.

**Layer 3 (DevShell)**: Full development environment with compilers, toolchains, LSPs, and developer tools. Never shipped to production.

## Base Image Strategy

### Abstracted Base Image

The base image is parameterized to support multiple targets:

```dockerfile
ARG BASE_IMAGE=gcr.io/distroless/base-debian12
FROM ${BASE_IMAGE}
```

| Target | Image | Use Case |
|--------|-------|----------|
| Default | `gcr.io/distroless/base-debian12` | Standard deployments |
| FIPS | `ubuntu:24.04` + Pro | Government/compliance |

Both use glibc, ensuring binary compatibility for Nix-built packages.

### Why Google Distroless (Default)

- Google-backed, 7+ years in production
- Debian-based (familiar, well-documented)
- Minimal attack surface (~20MB base)
- No shell by default (security)

### Why Ubuntu (FIPS Fallback)

- Canonical backing, 10-year LTS
- FIPS 140-2 certified packages available
- Larger community, more documentation
- Required for government/compliance contexts

## Compiled vs Interpreted Languages

| Language | Build-time | Runtime | Production Needs |
|----------|------------|---------|------------------|
| Python | Interpreter | Interpreter | Python in Layer 2 |
| Node.js | Node + npm | Node | Node in Layer 2 |
| Bun | Bun | Nothing | Static binary only |
| Go | Go compiler | Nothing | Static binary only |
| Rust | rustc + cargo | Nothing | Static binary only |
| Java | JDK | JRE | JRE in Layer 2 |
| GnuCOBOL | cobc + gcc | libcob | libcob in Layer 2 |

Compiled languages produce static binaries. Production images only include Layer 2 components actually needed by the project.

## Nix Configuration

### Flake Structure

```
flake.nix
flake.lock
overlays/
├── default.nix          # Combines all overlays
├── cve-patches.nix      # Security patches
├── license-fixes.nix    # Recompile without copyleft deps
└── custom-builds.nix    # Modified compilation flags
```

### Nixpkgs Management

- **Method**: Flakes with `flake.lock` pinning
- **Updates**: Automated weekly PRs via GitHub Actions
- **Review**: Human approval required before merge

### CVE Handling

**Hybrid approach**:
1. Run vulnix in CI to detect known CVEs
2. Fail builds on Critical/High severity
3. Manually patch Critical/High in `overlays/cve-patches.nix`
4. Wait for upstream on Low/Medium
5. Remove local patches once upstream catches up

## DevContainer Integration

### Image Strategy

Pre-built base image with Nix shell activation:

```json
{
  "image": "ghcr.io/yourorg/containers/devcontainer-base:latest",
  "features": {
    "ghcr.io/yourorg/devcontainer-features/python": {}
  },
  "postStartCommand": "nix develop --impure"
}
```

### Binary Cache

Common Nix dependencies are baked into the devcontainer-base image (`/nix/store` pre-populated). This minimizes first-run wait time - `nix develop` only fetches project-specific additions.

### DevContainer Features

Composable features published to ghcr.io:

```
devcontainer-features/
└── src/
    ├── python/
    │   ├── devcontainer-feature.json
    │   └── install.sh
    ├── node/
    ├── go/
    ├── rust/
    ├── java/
    └── cobol/
```

Each feature declares:
- VS Code extensions for that language
- Any additional setup scripts
- Default settings

Projects compose features as needed:

```json
{
  "features": {
    "ghcr.io/yourorg/devcontainer-features/python": {},
    "ghcr.io/yourorg/devcontainer-features/node": {}
  }
}
```

## Container Registry

### Namespace Structure

```
ghcr.io/yourorg/
├── containers/
│   ├── base                    # Layer 1
│   ├── devcontainer-base       # Layer 1 + pre-cached /nix/store
│   ├── runtime-python          # Layer 1+2: Base + Python
│   ├── runtime-node            # Layer 1+2: Base + Node
│   └── runtime-minimal         # Layer 1+2: Base + libcob only
│
└── devcontainer-features/
    ├── python
    ├── node
    ├── go
    ├── rust
    ├── java
    └── cobol
```

### Tagging Strategy

Date-based with SHA for traceability:

```
# On push to main
ghcr.io/yourorg/containers/base:2024-12-06
ghcr.io/yourorg/containers/base:2024-12-06-abc123f
ghcr.io/yourorg/containers/base:latest

# On release tag (v1.2.3)
ghcr.io/yourorg/containers/base:1.2.3
ghcr.io/yourorg/containers/base:1.2
ghcr.io/yourorg/containers/base:1
```

## CI Pipeline Structure

### Workflows

```
.github/workflows/
├── build-containers.yml      # Build & publish container images
├── build-features.yml        # Build & publish devcontainer features
├── test.yml                  # Run tests (shellspec, etc.)
├── security-scan.yml         # vulnix CVE scanning
├── update-nixpkgs.yml        # Weekly flake.lock update PRs
└── release.yml               # Tag-triggered release
```

### Triggers

| Workflow | Trigger |
|----------|---------|
| build-containers.yml | Push to `main`, tags |
| build-features.yml | Push to `main`, tags |
| test.yml | All PRs, push to `main` |
| security-scan.yml | Daily schedule, push to `main` |
| update-nixpkgs.yml | Weekly schedule (creates PR) |
| release.yml | Tags (`v*`) |

## Project Template

Projects consuming this infrastructure:

```
my-project/
├── .devcontainer/
│   └── devcontainer.json
├── .github/
│   └── workflows/
│       └── ci.yml
├── flake.nix
├── flake.lock
├── .envrc
└── src/
```

### Project flake.nix

```nix
{
  inputs = {
    infra.url = "github:yourorg/infra";
    nixpkgs.follows = "infra/nixpkgs";
  };

  outputs = { self, infra, nixpkgs }: {
    devShells.x86_64-linux.default = infra.devShells.x86_64-linux.python;
  };
}
```

### Project .envrc

```bash
use flake
```

### Project devcontainer.json

```json
{
  "name": "My Python Project",
  "image": "ghcr.io/yourorg/containers/devcontainer-base:latest",
  "features": {
    "ghcr.io/yourorg/devcontainer-features/python": {}
  },
  "postStartCommand": "nix develop --impure",
  "remoteUser": "vscode",
  "mounts": [
    "source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly"
  ]
}
```

### Project CI

```yaml
name: CI
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/yourorg/containers/devcontainer-base:latest
    steps:
      - uses: actions/checkout@v4
      - run: nix develop --impure --command make test
      - run: nix develop --impure --command make build
```

## Production Deployment

### Build Flow

```
DevShell (Layer 3)  -->  Build Stage (Layer 3)  -->  Production (Layer 1+2)
     |                        |                            |
  Write code              go build                    Your binary
  Run tests               cargo build                 Python interp
  Debug                   cobc compile                libcob
                          bun build --compile
```

### Production Image Build

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build production image
        run: |
          nix build .#containerImage
          docker load < result

      - name: Push to registry
        run: |
          docker tag myapp:latest ghcr.io/yourorg/myapp:${{ github.ref_name }}
          docker push ghcr.io/yourorg/myapp:${{ github.ref_name }}
```

### Deployment Target (baljeet-style)

Production containers run on Docker hosts. The image contains:
- Layer 1 (base)
- Layer 2 subset (only needed runtimes)
- Compiled application artifacts

No development tools, compilers, or Layer 3 components.

## Repository Structure

```
infrastructure-repo/
├── containers/
│   ├── base/
│   │   └── Dockerfile
│   └── devcontainer-base/
│       └── Dockerfile
├── devcontainer-features/
│   └── src/
│       ├── python/
│       ├── node/
│       ├── go/
│       ├── rust/
│       ├── java/
│       └── cobol/
├── overlays/
│   ├── default.nix
│   ├── cve-patches.nix
│   ├── license-fixes.nix
│   └── custom-builds.nix
├── .github/
│   └── workflows/
│       ├── build-containers.yml
│       ├── build-features.yml
│       ├── test.yml
│       ├── security-scan.yml
│       ├── update-nixpkgs.yml
│       └── release.yml
├── flake.nix
├── flake.lock
└── README.md
```

## Decisions Summary

| Area | Decision |
|------|----------|
| Base image | Parameterized (Distroless default, Ubuntu for FIPS) |
| C library | glibc (both bases compatible) |
| Nix management | Flakes with flake.lock |
| Overlay structure | Single overlays/ directory |
| Update cadence | Automated weekly PRs, human review |
| CVE handling | vulnix scanner + manual patches for Critical/High |
| DevShell model | Composable by domain via Features |
| Registry | ghcr.io |
| Image tags | Date-based + SHA + latest |
| CI structure | Workflow per concern |
| Build triggers | Main + tags (balanced) |

## License Considerations

- **Base images**: Apache 2.0 (Distroless), various permissive (Ubuntu)
- **glibc**: LGPL 2.1 (safe with dynamic linking)
- **Runtimes**: All permissive (Python PSF, Node MIT, Go BSD, Rust MIT/Apache)
- **GnuCOBOL**: GPL (compiler), LGPL (runtime) - acceptable for teaching/training
- **Avoid Berkeley DB** with GnuCOBOL to prevent source disclosure requirements

## Future Considerations

- GraalVM native-image for Java (eliminates JRE from Layer 2)
- Nuitka/PyInstaller for Python (could eliminate interpreter)
- Ubuntu Chiseled images (smaller than full Ubuntu, newer option)
- Cachix integration if ghcr.io Nix caching proves insufficient
