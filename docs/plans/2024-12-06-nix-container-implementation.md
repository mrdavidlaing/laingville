# Nix Container Infrastructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the layered Nix container infrastructure within laingville/infra, with Python and Node DevContainer Features.

**Architecture:** Three-layer containers (Base → Runtime → DevShell) using Nix flakes, with composable DevContainer Features published to ghcr.io.

**Tech Stack:** Nix flakes, Docker, GitHub Actions, DevContainer Features, ghcr.io

---

## Phase 1: Foundation (flake.nix + overlays)

### Task 1: Create infrastructure directory structure

**Files:**
- Create: `infra/flake.nix`
- Create: `infra/overlays/default.nix`
- Create: `infra/overlays/cve-patches.nix`
- Create: `infra/overlays/license-fixes.nix`
- Create: `infra/overlays/custom-builds.nix`
- Create: `infra/.envrc`

**Step 1: Create directory structure**

```bash
mkdir -p infra/overlays
mkdir -p infra/containers/base
mkdir -p infra/containers/devcontainer-base
mkdir -p infra/devcontainer-features/src/python
mkdir -p infra/devcontainer-features/src/node
mkdir -p infra/.github/workflows
```

**Step 2: Create base flake.nix**

```nix
# infra/flake.nix
{
  description = "Nix container infrastructure for laingville";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = import ./overlays;
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlays ];
          config.allowUnfree = false;
        };
      in
      {
        # DevShells - composable development environments
        devShells = {
          default = pkgs.mkShell {
            name = "infra-dev";
            packages = with pkgs; [
              git
              direnv
              nix-direnv
            ];
          };

          python = pkgs.mkShell {
            name = "python-dev";
            packages = with pkgs; [
              python312
              python312Packages.pip
              python312Packages.virtualenv
              uv
              ruff
              pyright
            ];
            shellHook = ''
              echo "Python devShell activated"
            '';
          };

          node = pkgs.mkShell {
            name = "node-dev";
            packages = with pkgs; [
              nodejs_22
              bun
              nodePackages.typescript
              nodePackages.typescript-language-server
              nodePackages.prettier
              nodePackages.eslint
            ];
            shellHook = ''
              echo "Node devShell activated"
            '';
          };
        };

        # Packages - for container builds
        packages = {
          # Runtime closures for Layer 2
          pythonRuntime = pkgs.python312;
          nodeRuntime = pkgs.nodejs_22;
        };
      }
    );
}
```

**Step 3: Create overlays/default.nix**

```nix
# infra/overlays/default.nix
final: prev:
let
  cvePatches = import ./cve-patches.nix final prev;
  licenseFixes = import ./license-fixes.nix final prev;
  customBuilds = import ./custom-builds.nix final prev;
in
cvePatches // licenseFixes // customBuilds
```

**Step 4: Create overlays/cve-patches.nix**

```nix
# infra/overlays/cve-patches.nix
# CVE patches for Critical/High vulnerabilities
# Remove patches once upstream catches up
final: prev: {
  # Example (uncomment when needed):
  # openssl = prev.openssl.overrideAttrs (old: {
  #   patches = old.patches or [] ++ [
  #     ./patches/openssl-CVE-2024-XXXX.patch
  #   ];
  # });
}
```

**Step 5: Create overlays/license-fixes.nix**

```nix
# infra/overlays/license-fixes.nix
# Recompile packages to avoid copyleft dependencies
final: prev: {
  # Example: ffmpeg without GPL codecs
  # ffmpeg = prev.ffmpeg.override {
  #   withGPL = false;
  # };
}
```

**Step 6: Create overlays/custom-builds.nix**

```nix
# infra/overlays/custom-builds.nix
# Custom compilation flags and build options
final: prev: {
  # Example: GnuCOBOL with VBISAM instead of Berkeley DB
  # gnucobol = prev.gnucobol.override {
  #   useBerkeleyDB = false;
  # };
}
```

**Step 7: Create .envrc for direnv**

```bash
# infra/.envrc
use flake
```

**Step 8: Verify flake builds**

Run: `cd infra && nix flake check`
Expected: No errors

**Step 9: Commit**

```bash
git add infra/
git commit -m "feat(infra): add base flake.nix with overlays structure

- flake.nix with Python and Node devShells
- Overlay structure for CVE patches, license fixes, custom builds
- direnv integration via .envrc"
```

---

## Phase 2: Container Definitions

### Task 2: Create base container Dockerfile

**Files:**
- Create: `infra/containers/base/Dockerfile`
- Create: `infra/containers/base/nix.conf`

**Step 1: Create nix.conf**

```ini
# infra/containers/base/nix.conf
experimental-features = nix-command flakes
accept-flake-config = true
max-jobs = auto
```

**Step 2: Create base Dockerfile**

```dockerfile
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
```

**Step 3: Test base image builds**

Run: `docker build -t infra-base:test infra/containers/base/`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add infra/containers/base/
git commit -m "feat(infra): add base container with Nix and direnv

- Debian bookworm-slim base (glibc compatible)
- Single-user Nix installation
- Flakes enabled via nix.conf
- direnv + nix-direnv pre-installed"
```

---

### Task 3: Create devcontainer-base image

**Files:**
- Create: `infra/containers/devcontainer-base/Dockerfile`

**Step 1: Create devcontainer-base Dockerfile**

```dockerfile
# infra/containers/devcontainer-base/Dockerfile
# Layer 1 + pre-cached /nix/store for fast devcontainer startup
ARG BASE_IMAGE=debian:bookworm-slim
FROM ${BASE_IMAGE} AS nix-installer

# Install Nix dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    xz-utils \
    git \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create vscode user (standard devcontainer user)
RUN groupadd -r vscode && useradd -r -g vscode -G sudo -d /home/vscode -s /bin/bash -m vscode
RUN echo 'vscode ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Create nix directory
RUN mkdir -p /nix && chown -R vscode:vscode /nix

USER vscode
WORKDIR /home/vscode

# Install Nix
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# Configure Nix for flakes
RUN mkdir -p ~/.config/nix && \
    echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf && \
    echo 'accept-flake-config = true' >> ~/.config/nix/nix.conf

# Add Nix to PATH
ENV PATH="/home/vscode/.nix-profile/bin:${PATH}"

# Install common tools into /nix/store (pre-cache)
RUN . ~/.nix-profile/etc/profile.d/nix.sh && \
    nix profile install \
      nixpkgs#direnv \
      nixpkgs#nix-direnv \
      nixpkgs#git \
      nixpkgs#curl \
      nixpkgs#jq \
      nixpkgs#ripgrep \
      nixpkgs#fd \
      nixpkgs#fzf \
      nixpkgs#bat

# Configure direnv
RUN mkdir -p ~/.config/direnv && \
    echo 'source ~/.nix-profile/share/nix-direnv/direnvrc' > ~/.config/direnv/direnvrc

# Configure shell for direnv
RUN echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
```

**Step 2: Test devcontainer-base builds**

Run: `docker build -t infra-devcontainer-base:test infra/containers/devcontainer-base/`
Expected: Build succeeds (may take several minutes for Nix downloads)

**Step 3: Commit**

```bash
git add infra/containers/devcontainer-base/
git commit -m "feat(infra): add devcontainer-base with pre-cached nix store

- vscode user for devcontainer compatibility
- Common tools pre-installed (direnv, git, ripgrep, fd, fzf, bat, jq)
- Nix flakes enabled
- direnv auto-hook in bashrc"
```

---

## Phase 3: DevContainer Features

### Task 4: Create Python DevContainer Feature

**Files:**
- Create: `infra/devcontainer-features/src/python/devcontainer-feature.json`
- Create: `infra/devcontainer-features/src/python/install.sh`

**Step 1: Create devcontainer-feature.json**

```json
{
  "id": "python",
  "version": "1.0.0",
  "name": "Python DevShell",
  "description": "Activates Python Nix devShell with VS Code extensions",
  "documentationURL": "https://github.com/mrdavidlaing/laingville/tree/main/infra/devcontainer-features",
  "options": {},
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-python.vscode-pylance",
        "ms-python.debugpy",
        "charliermarsh.ruff"
      ],
      "settings": {
        "python.defaultInterpreterPath": "/home/vscode/.nix-profile/bin/python3",
        "[python]": {
          "editor.formatOnSave": true,
          "editor.defaultFormatter": "charliermarsh.ruff"
        }
      }
    }
  },
  "installsAfter": []
}
```

**Step 2: Create install.sh**

```bash
#!/bin/bash
# infra/devcontainer-features/src/python/install.sh
set -e

echo "Python DevContainer Feature installed"
echo "Python devShell will be activated via 'nix develop' in postStartCommand"

# Feature installation is minimal - actual Python comes from Nix devShell
# This feature primarily declares VS Code extensions and settings
```

**Step 3: Make install.sh executable**

```bash
chmod +x infra/devcontainer-features/src/python/install.sh
```

**Step 4: Commit**

```bash
git add infra/devcontainer-features/src/python/
git commit -m "feat(infra): add Python DevContainer Feature

- VS Code extensions: Python, Pylance, debugpy, Ruff
- Format on save with Ruff
- Python comes from Nix devShell (not installed by feature)"
```

---

### Task 5: Create Node DevContainer Feature

**Files:**
- Create: `infra/devcontainer-features/src/node/devcontainer-feature.json`
- Create: `infra/devcontainer-features/src/node/install.sh`

**Step 1: Create devcontainer-feature.json**

```json
{
  "id": "node",
  "version": "1.0.0",
  "name": "Node/Bun DevShell",
  "description": "Activates Node/Bun Nix devShell with VS Code extensions",
  "documentationURL": "https://github.com/mrdavidlaing/laingville/tree/main/infra/devcontainer-features",
  "options": {},
  "customizations": {
    "vscode": {
      "extensions": [
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "oven.bun-vscode"
      ],
      "settings": {
        "[javascript]": {
          "editor.formatOnSave": true,
          "editor.defaultFormatter": "esbenp.prettier-vscode"
        },
        "[typescript]": {
          "editor.formatOnSave": true,
          "editor.defaultFormatter": "esbenp.prettier-vscode"
        },
        "[json]": {
          "editor.formatOnSave": true,
          "editor.defaultFormatter": "esbenp.prettier-vscode"
        }
      }
    }
  },
  "installsAfter": []
}
```

**Step 2: Create install.sh**

```bash
#!/bin/bash
# infra/devcontainer-features/src/node/install.sh
set -e

echo "Node/Bun DevContainer Feature installed"
echo "Node devShell will be activated via 'nix develop' in postStartCommand"

# Feature installation is minimal - actual Node/Bun comes from Nix devShell
# This feature primarily declares VS Code extensions and settings
```

**Step 3: Make install.sh executable**

```bash
chmod +x infra/devcontainer-features/src/node/install.sh
```

**Step 4: Commit**

```bash
git add infra/devcontainer-features/src/node/
git commit -m "feat(infra): add Node/Bun DevContainer Feature

- VS Code extensions: ESLint, Prettier, Bun
- Format on save with Prettier for JS/TS/JSON
- Node/Bun come from Nix devShell (not installed by feature)"
```

---

## Phase 4: CI Workflows

### Task 6: Create container build workflow

**Files:**
- Create: `infra/.github/workflows/build-containers.yml`

**Step 1: Create build-containers.yml**

```yaml
# infra/.github/workflows/build-containers.yml
name: Build Containers

on:
  push:
    branches: [main]
    paths:
      - 'infra/containers/**'
      - 'infra/flake.nix'
      - 'infra/flake.lock'
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_PREFIX: ${{ github.repository_owner }}/laingville

jobs:
  build-base:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Generate image tags
        id: tags
        run: |
          DATE=$(date +%Y-%m-%d)
          SHA=$(git rev-parse --short HEAD)
          echo "date=${DATE}" >> $GITHUB_OUTPUT
          echo "sha=${SHA}" >> $GITHUB_OUTPUT

      - name: Build and push base image
        uses: docker/build-push-action@v5
        with:
          context: infra/containers/base
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/base:${{ steps.tags.outputs.date }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/base:${{ steps.tags.outputs.date }}-${{ steps.tags.outputs.sha }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/base:latest

  build-devcontainer-base:
    runs-on: ubuntu-latest
    needs: build-base
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Generate image tags
        id: tags
        run: |
          DATE=$(date +%Y-%m-%d)
          SHA=$(git rev-parse --short HEAD)
          echo "date=${DATE}" >> $GITHUB_OUTPUT
          echo "sha=${SHA}" >> $GITHUB_OUTPUT

      - name: Build and push devcontainer-base image
        uses: docker/build-push-action@v5
        with:
          context: infra/containers/devcontainer-base
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/devcontainer-base:${{ steps.tags.outputs.date }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/devcontainer-base:${{ steps.tags.outputs.date }}-${{ steps.tags.outputs.sha }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/devcontainer-base:latest
```

**Step 2: Commit**

```bash
git add infra/.github/workflows/build-containers.yml
git commit -m "ci(infra): add container build workflow

- Builds base and devcontainer-base images
- Pushes to ghcr.io with date-based tags
- Triggers on changes to containers/ or flake files"
```

---

### Task 7: Create DevContainer Features publish workflow

**Files:**
- Create: `infra/.github/workflows/build-features.yml`

**Step 1: Create build-features.yml**

```yaml
# infra/.github/workflows/build-features.yml
name: Build DevContainer Features

on:
  push:
    branches: [main]
    paths:
      - 'infra/devcontainer-features/**'
  workflow_dispatch:

jobs:
  publish-features:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Publish Features
        uses: devcontainers/action@v1
        with:
          publish-features: 'true'
          base-path-to-features: 'infra/devcontainer-features/src'
          generate-docs: 'true'

      - name: Commit generated docs
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add infra/devcontainer-features/src/*/README.md || true
          git diff --staged --quiet || git commit -m "docs: update DevContainer Feature READMEs [skip ci]"
          git push || true
```

**Step 2: Commit**

```bash
git add infra/.github/workflows/build-features.yml
git commit -m "ci(infra): add DevContainer Features publish workflow

- Uses official devcontainers/action
- Publishes features to ghcr.io
- Auto-generates README docs"
```

---

### Task 8: Create nixpkgs update workflow

**Files:**
- Create: `infra/.github/workflows/update-nixpkgs.yml`

**Step 1: Create update-nixpkgs.yml**

```yaml
# infra/.github/workflows/update-nixpkgs.yml
name: Update Nixpkgs

on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday at 9am UTC
  workflow_dispatch:

jobs:
  update-flake:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write

    steps:
      - uses: actions/checkout@v4

      - name: Install Nix
        uses: cachix/install-nix-action@v24
        with:
          nix_path: nixpkgs=channel:nixos-24.11

      - name: Update flake.lock
        working-directory: infra
        run: nix flake update

      - name: Check for changes
        id: changes
        working-directory: infra
        run: |
          if git diff --quiet flake.lock; then
            echo "changed=false" >> $GITHUB_OUTPUT
          else
            echo "changed=true" >> $GITHUB_OUTPUT
          fi

      - name: Create Pull Request
        if: steps.changes.outputs.changed == 'true'
        uses: peter-evans/create-pull-request@v5
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: 'chore(infra): update nixpkgs flake.lock'
          title: 'chore(infra): weekly nixpkgs update'
          body: |
            Automated weekly update of nixpkgs via `nix flake update`.

            ## Review Checklist
            - [ ] CI passes
            - [ ] No unexpected package changes
            - [ ] Security scan passes
          branch: chore/update-nixpkgs
          delete-branch: true
```

**Step 2: Commit**

```bash
git add infra/.github/workflows/update-nixpkgs.yml
git commit -m "ci(infra): add weekly nixpkgs update workflow

- Runs every Monday at 9am UTC
- Creates PR with flake.lock changes
- Includes review checklist"
```

---

### Task 9: Create security scan workflow

**Files:**
- Create: `infra/.github/workflows/security-scan.yml`

**Step 1: Create security-scan.yml**

```yaml
# infra/.github/workflows/security-scan.yml
name: Security Scan

on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6am UTC
  push:
    branches: [main]
    paths:
      - 'infra/flake.nix'
      - 'infra/flake.lock'
      - 'infra/overlays/**'
  workflow_dispatch:

jobs:
  vulnix-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Nix
        uses: cachix/install-nix-action@v24
        with:
          nix_path: nixpkgs=channel:nixos-24.11

      - name: Install vulnix
        run: nix profile install nixpkgs#vulnix

      - name: Run vulnix scan
        working-directory: infra
        run: |
          echo "Scanning Python devShell..."
          nix build .#devShells.x86_64-linux.python --no-link -o python-shell
          vulnix python-shell || true

          echo "Scanning Node devShell..."
          nix build .#devShells.x86_64-linux.node --no-link -o node-shell
          vulnix node-shell || true
        continue-on-error: true

      - name: Check for Critical/High CVEs
        working-directory: infra
        run: |
          echo "Checking for Critical/High severity CVEs..."
          # vulnix outputs CVEs to stdout
          # This step would parse output and fail on Critical/High
          # For now, just warn
          echo "::warning::Review vulnix output above for Critical/High CVEs"
```

**Step 2: Commit**

```bash
git add infra/.github/workflows/security-scan.yml
git commit -m "ci(infra): add vulnix security scan workflow

- Daily scan + on changes to flake/overlays
- Scans Python and Node devShells
- Warns on Critical/High CVEs (manual review required)"
```

---

## Phase 5: Example Project Template

### Task 10: Create example project template

**Files:**
- Create: `infra/templates/python-project/.devcontainer/devcontainer.json`
- Create: `infra/templates/python-project/flake.nix`
- Create: `infra/templates/python-project/.envrc`
- Create: `infra/templates/python-project/.github/workflows/ci.yml`

**Step 1: Create devcontainer.json**

```json
{
  "name": "Python Project",
  "image": "ghcr.io/mrdavidlaing/laingville/devcontainer-base:latest",
  "features": {
    "ghcr.io/mrdavidlaing/laingville/python": {}
  },
  "postStartCommand": "direnv allow && nix develop --impure",
  "remoteUser": "vscode",
  "mounts": [
    "source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly"
  ],
  "customizations": {
    "vscode": {
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash"
      }
    }
  }
}
```

**Step 2: Create flake.nix**

```nix
# templates/python-project/flake.nix
{
  description = "Python project using laingville infrastructure";

  inputs = {
    infra.url = "github:mrdavidlaing/laingville?dir=infra";
    nixpkgs.follows = "infra/nixpkgs";
  };

  outputs = { self, infra, nixpkgs }:
    let
      system = "x86_64-linux";
    in
    {
      devShells.${system}.default = infra.devShells.${system}.python;
    };
}
```

**Step 3: Create .envrc**

```bash
# templates/python-project/.envrc
use flake
```

**Step 4: Create CI workflow**

```yaml
# templates/python-project/.github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/mrdavidlaing/laingville/devcontainer-base:latest

    steps:
      - uses: actions/checkout@v4

      - name: Run tests
        run: |
          nix develop --impure --command python -m pytest || echo "No tests yet"

      - name: Lint
        run: |
          nix develop --impure --command ruff check . || echo "No Python files yet"
```

**Step 5: Create directory structure**

```bash
mkdir -p infra/templates/python-project/.devcontainer
mkdir -p infra/templates/python-project/.github/workflows
```

**Step 6: Commit**

```bash
git add infra/templates/
git commit -m "feat(infra): add Python project template

- devcontainer.json with Python feature
- flake.nix importing infra devShell
- CI workflow using devcontainer-base image
- .envrc for local development"
```

---

## Phase 6: Documentation

### Task 11: Create infrastructure README

**Files:**
- Create: `infra/README.md`

**Step 1: Create README.md**

```markdown
# Laingville Nix Container Infrastructure

Layered container architecture using Nix for reproducible builds.

## Quick Start

### Using in a New Project

1. Copy the template:
   ```bash
   cp -r infra/templates/python-project my-project
   cd my-project
   ```

2. Open in VS Code with DevContainers extension
3. VS Code will prompt to reopen in container
4. Start coding!

### Local Development (without DevContainer)

```bash
cd my-project
direnv allow
# Nix devShell activates automatically
```

## Architecture

```
Layer 3: DevShell (compilers + dev tools) - NOT in production
Layer 2: Runtime (Python, libcob, JRE)   - project-specific
Layer 1: Base (Nix + direnv)             - always present
```

## Available DevShells

- `python` - Python 3.12, pip, uv, ruff, pyright
- `node` - Node 22, Bun, TypeScript, ESLint, Prettier

## Container Images

| Image | Description |
|-------|-------------|
| `ghcr.io/mrdavidlaing/laingville/base` | Layer 1 only |
| `ghcr.io/mrdavidlaing/laingville/devcontainer-base` | Layer 1 + common tools |

## DevContainer Features

| Feature | Description |
|---------|-------------|
| `ghcr.io/mrdavidlaing/laingville/python` | Python VS Code extensions |
| `ghcr.io/mrdavidlaing/laingville/node` | Node/Bun VS Code extensions |

## Overlays

Custom Nix overlays in `overlays/`:

- `cve-patches.nix` - Security patches for Critical/High CVEs
- `license-fixes.nix` - Recompile to avoid copyleft
- `custom-builds.nix` - Custom compilation flags

## CI Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| build-containers | Push to main | Build container images |
| build-features | Push to main | Publish DevContainer Features |
| security-scan | Daily + main | vulnix CVE scanning |
| update-nixpkgs | Weekly | Automated flake.lock updates |

## Adding a New DevShell

1. Add to `flake.nix`:
   ```nix
   devShells.myshell = pkgs.mkShell {
     packages = [ ... ];
   };
   ```

2. Create DevContainer Feature in `devcontainer-features/src/myshell/`

3. Commit and push - CI publishes automatically
```

**Step 2: Commit**

```bash
git add infra/README.md
git commit -m "docs(infra): add infrastructure README

- Quick start guide
- Architecture overview
- Available devShells and container images
- How to add new devShells"
```

---

## Phase 7: Integration Test

### Task 12: Verify end-to-end flow

**Step 1: Build containers locally**

```bash
cd infra
docker build -t test-base containers/base/
docker build -t test-devcontainer-base containers/devcontainer-base/
```

Expected: Both builds succeed

**Step 2: Test devShell activation**

```bash
cd infra
nix develop .#python --command python --version
nix develop .#node --command node --version
```

Expected: Python 3.12.x and Node 22.x versions printed

**Step 3: Test flake check**

```bash
cd infra
nix flake check
```

Expected: No errors

**Step 4: Final commit**

```bash
git add -A
git status
# If any uncommitted files, commit them
```

---

## Summary

After completing all tasks, the infrastructure provides:

1. **flake.nix** with Python and Node devShells
2. **Overlay structure** for CVE patches and custom builds
3. **Container images** (base + devcontainer-base)
4. **DevContainer Features** (python + node)
5. **CI workflows** (build, scan, update)
6. **Project template** for new Python projects
7. **Documentation** in README.md

### Next Steps (Future Tasks)

- Add Go, Rust, Java, COBOL DevContainer Features
- Add vulnix failure threshold for Critical CVEs
- Add runtime containers (runtime-python, runtime-node)
- Create production container build in flake.nix
- Add Ubuntu FIPS base image variant
