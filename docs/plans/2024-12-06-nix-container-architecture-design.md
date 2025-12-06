# Nix Container Architecture Design

## Overview

A layered container architecture using **pure Nix** for reproducible builds, supporting multiple development runtimes with fast CVE updates via small channels and composable development environments.

## Goals

1. **Reproducibility**: Identical builds locally, in CI, and in production via Nix flakes
2. **Security**: Fast CVE patches via `nixos-25.11-small` channel + manual overlays for critical issues
3. **Developer experience**: Git clone, open VS Code, devcontainer ready
4. **Flexibility**: Support Python, Node/Bun, Go, Rust, Java, GnuCOBOL
5. **Minimal production images**: Nix closures with only required dependencies

## Layer Architecture

```
+-------------------------------------------------------------+
|  LAYER 3: DevShell (compilers + dev tools)                  |
|  - Bun, Go, Rust, GnuCOBOL/cobc, JDK, GraalVM               |
|  - LSPs, formatters, linters, debuggers                     |
|  - lazygit, neovim, tmux, shellspec                         |
|  NOT in production                                          |
+-------------------------------------------------------------+
|  LAYER 2: Runtime (interpreters + runtime libs from Nix)    |
|  - Python interpreter (nixpkgs)                             |
|  - Node.js runtime (nixpkgs)                                |
|  - libcob (COBOL runtime library, nixpkgs)                  |
|  - JRE (if not using GraalVM native-image, nixpkgs)         |
|  - Compiled binaries from Layer 3                           |
|  Shipped to production (project-specific Nix closure)       |
+-------------------------------------------------------------+
|  LAYER 1: Base                                              |
|  - Debian slim (for Nix installer compatibility)            |
|  - Nix + binary cache config + direnv                       |
|  - All dependencies from nixpkgs (not apt)                  |
|  Shipped to production                                      |
+-------------------------------------------------------------+
```

### Layer Details

**Layer 1 (Base)**: Debian slim provides glibc and minimal OS for Nix installation. After Nix is installed, **all packages come from nixpkgs**, not apt. The base image exists only to bootstrap Nix.

**Layer 2 (Runtime)**: All interpreters and runtime libraries come from **nixpkgs via small channels**. This ensures:
- Reproducible builds (flake.lock pins exact versions)
- Fast security updates (small channel updates in hours, not days)
- Consistent CVE patching via overlays

**Layer 3 (DevShell)**: Full development environment with compilers, toolchains, LSPs, and developer tools. Never shipped to production.

## Pure Nix Strategy

### Why Pure Nix (Not Hybrid Debian/Nix)

We chose pure Nix over hybrid approaches for these reasons:

| Concern | Hybrid (Debian runtimes) | Pure Nix |
|---------|-------------------------|----------|
| **Reproducibility** | Approximate (apt versions float) | Exact (flake.lock pins hashes) |
| **CVE tracking** | Split SBOM (apt + nix) | Single SBOM from Nix |
| **Update mechanism** | Manual apt + nix flake update | Single nix flake update |
| **Build consistency** | Varies by build date | Identical everywhere |

### Small Channels for Fast Security Updates

We use `nixos-25.11-small` instead of the full channel:

- **Full channels**: Wait for all ~30,000 packages to build (2-5 days)
- **Small channels**: Wait for critical packages only (hours to ~1 day)

This gives us security patch velocity comparable to traditional distros while maintaining Nix's reproducibility guarantees.

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11-small";
};
```

### Debian Base Image (Bootstrap Only)

Debian slim is used **only** to install Nix. We cannot use Distroless because:
- Distroless has no shell (required for Nix installer)
- Distroless has no package manager (required for curl, xz)

After Nix is installed, all subsequent packages come from nixpkgs. Debian's apt is not used for any runtime dependencies.

## Compiled vs Interpreted Languages

| Language | Build-time (Nix) | Runtime (Nix) | Production Needs |
|----------|------------------|---------------|------------------|
| Python | python312 | python312 | Python closure from nixpkgs |
| Node.js | nodejs_22 + npm | nodejs_22 | Node closure from nixpkgs |
| Bun | bun | Nothing | Static binary only |
| Go | go | Nothing | Static binary only |
| Rust | rustc + cargo | Nothing | Static binary only |
| Java | jdk | jre | JRE closure from nixpkgs |
| GnuCOBOL | gnucobol + gcc | libcob | libcob closure from nixpkgs |

**All runtimes come from nixpkgs**, ensuring consistent versioning and CVE patching across dev and production.

Compiled languages produce static binaries that need minimal runtime dependencies. Production images use `nix build` to create minimal closures containing only required packages.

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

**Pure Nix approach with small channels**:

1. **Primary defense**: Use `nixos-25.11-small` channel for fast upstream patches (hours vs days)
2. **Automated updates**: Weekly `nix flake update` PRs via CI
3. **Scanning**: Run OSV Scanner in CI to detect known CVEs
4. **Manual patches**: For Critical/High CVEs not yet in nixpkgs, add to `overlays/cve-patches.nix`
5. **Cleanup**: Remove local patches once upstream catches up
6. **Subscribe**: Monitor [NixOS Security Discourse](https://discourse.nixos.org/c/announcements/security/56) for advisories

**Why this works**:
- Small channels update when critical packages build (not all 30k packages)
- Weekly flake updates keep us current with upstream security fixes
- Overlays provide escape hatch for zero-day response
- Single dependency tree = single SBOM = simpler compliance

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
| **Dependency source** | Pure Nix (all packages from nixpkgs, not apt) |
| **Nixpkgs channel** | `nixos-25.11-small` (fast security updates) |
| **Base image** | Debian slim (bootstrap only, for Nix installer) |
| **C library** | glibc (from Debian base) |
| **Nix management** | Flakes with flake.lock |
| **Overlay structure** | Single overlays/ directory |
| **Update cadence** | Automated weekly PRs, human review |
| **CVE handling** | Small channel + OSV Scanner + manual patches for Critical/High |
| **DevShell model** | Composable by domain via Features |
| **Registry** | ghcr.io |
| **Image tags** | Date-based + SHA + latest |
| **CI structure** | Workflow per concern |
| **Build triggers** | Main + tags (balanced) |

## License Considerations

- **Base image**: Debian (various, mostly permissive)
- **glibc**: LGPL 2.1 (safe with dynamic linking)
- **Nix packages**: Inherit upstream licenses
- **Runtimes**: All permissive (Python PSF, Node MIT, Go BSD, Rust MIT/Apache)
- **GnuCOBOL**: GPL (compiler), LGPL (runtime) - acceptable for teaching/training
- **Avoid Berkeley DB** with GnuCOBOL to prevent source disclosure requirements

## Future Considerations

- GraalVM native-image for Java (eliminates JRE from runtime closure)
- Nuitka/PyInstaller for Python (could eliminate interpreter from closure)
- `pkgs.dockerTools.buildImage` for minimal production containers (no Debian base)
- Cachix integration if ghcr.io Nix caching proves insufficient
- Determinate Systems evaluation if SLA/compliance requirements emerge
- nix-security-tracker adoption when it matures
