# Nix Container Infrastructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a project-centric Nix container infrastructure with package sets and builder functions for maximum Docker layer sharing.

**Architecture:** Pure Nix with `dockerTools.buildLayeredImage`. Infrastructure provides **package sets** (building blocks) and **builder functions**. Projects compose these to create project-specific images.

**Tech Stack:** Nix flakes, dockerTools.buildLayeredImage, GitHub Actions, ghcr.io

**Key Decisions:**
- No Dockerfiles - all images built with `dockerTools.buildLayeredImage`
- Package sets are composable building blocks (base, devTools, python, pythonDev, etc.)
- Builder functions (`mkDevContainer`, `mkRuntime`) create images from package sets
- All projects follow `infra/nixpkgs` for identical store paths = shared Docker layers
- `nixos-25.11-small` channel for security patch velocity (hours vs days)
- OSV Scanner for CVE detection (vulnix is deprecated)

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
```

**Step 2: Create base flake.nix with package sets and builder functions**

```nix
# infra/flake.nix
{
  description = "Nix container infrastructure for laingville";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11-small";
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

        #############################################
        # Package Sets - composable building blocks
        #############################################
        packageSets = {
          # Foundation (always included)
          base = with pkgs; [
            bashInteractive
            coreutils
            findutils
            gnugrep
            gnused
            gawk
            cacert           # TLS certificates
            tzdata           # Timezone data
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
            shadow           # for user management
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
            nodePackages.typescript-language-server
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

        #############################################
        # Helper functions for user/config creation
        #############################################

        # Create a non-root user for containers
        mkUser = { name, uid, gid, home, shell ? "${pkgs.bashInteractive}/bin/bash" }:
          pkgs.runCommand "user-${name}" {} ''
            mkdir -p $out/etc

            echo "root:x:0:0:root:/root:${shell}" > $out/etc/passwd
            echo "${name}:x:${toString uid}:${toString gid}:${name}:${home}:${shell}" >> $out/etc/passwd

            echo "root:x:0:" > $out/etc/group
            echo "wheel:x:10:${name}" >> $out/etc/group
            echo "${name}:x:${toString gid}:" >> $out/etc/group

            echo "root:!:1::::::" > $out/etc/shadow
            echo "${name}:!:1::::::" >> $out/etc/shadow

            mkdir -p $out${home}
            mkdir -p $out/root

            # sudoers
            mkdir -p $out/etc/sudoers.d
            echo "${name} ALL=(ALL) NOPASSWD:ALL" > $out/etc/sudoers.d/${name}
          '';

        # Nix configuration
        mkNixConf = pkgs.writeTextDir "etc/nix/nix.conf" ''
          experimental-features = nix-command flakes
          accept-flake-config = true
        '';

        # direnv configuration
        mkDirenvConf = pkgs.writeTextDir "etc/direnv/direnvrc" ''
          source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
        '';

        # bashrc with direnv hook
        mkBashrc = user: pkgs.writeTextDir "home/${user}/.bashrc" ''
          eval "$(direnv hook bash)"
        '';

        # User nix config
        mkUserNixConf = user: pkgs.writeTextDir "home/${user}/.config/nix/nix.conf" ''
          experimental-features = nix-command flakes
          accept-flake-config = true
        '';

        # User direnv config
        mkUserDirenvConf = user: pkgs.writeTextDir "home/${user}/.config/direnv/direnvrc" ''
          source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
        '';

        #############################################
        # Builder Functions
        #############################################

        # mkDevContainer: Creates a development container
        # - vscode user (uid 1000)
        # - sudo access
        # - direnv hook in bashrc
        # - Nix configured for flakes
        mkDevContainer = {
          packages,
          name ? "devcontainer",
          tag ? "latest",
          user ? "vscode",
          extraConfig ? {}
        }:
          let
            userSetup = mkUser {
              name = user;
              uid = 1000;
              gid = 1000;
              home = "/home/${user}";
            };
          in
          pkgs.dockerTools.buildLayeredImage {
            inherit name tag;
            contents = packages ++ [
              mkNixConf
              mkDirenvConf
              userSetup
              (mkBashrc user)
              (mkUserNixConf user)
              (mkUserDirenvConf user)
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

        # mkRuntime: Creates a minimal production container
        # - app user (uid 1000, non-root)
        # - No development tools
        # - No Nix (unless explicitly included in packages)
        mkRuntime = {
          packages,
          name ? "runtime",
          tag ? "latest",
          user ? "app",
          workdir ? "/app",
          extraConfig ? {}
        }:
          let
            userSetup = mkUser {
              name = user;
              uid = 1000;
              gid = 1000;
              home = workdir;
            };
          in
          pkgs.dockerTools.buildLayeredImage {
            inherit name tag;
            contents = packages ++ [ userSetup ];
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

      in
      {
        # Export package sets for projects to use
        inherit packageSets;

        # Export builder functions
        lib = {
          inherit mkDevContainer mkRuntime mkUser;
        };

        # DevShells - for local development without containers
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
            packages = packageSets.base ++ packageSets.python ++ packageSets.pythonDev;
            shellHook = ''
              echo "Python devShell activated"
            '';
          };

          node = pkgs.mkShell {
            name = "node-dev";
            packages = packageSets.base ++ packageSets.node ++ packageSets.nodeDev;
            shellHook = ''
              echo "Node devShell activated"
            '';
          };
        };

        # Example container images (for testing/demo)
        # Projects should build their own using mkDevContainer/mkRuntime
        packages = {
          # Example devcontainer with Python
          example-python-devcontainer = mkDevContainer {
            name = "ghcr.io/mrdavidlaing/laingville/example-python-devcontainer";
            packages = packageSets.base ++ packageSets.nixTools ++ packageSets.devTools
                    ++ packageSets.python ++ packageSets.pythonDev;
          };

          # Example runtime with Python
          example-python-runtime = mkRuntime {
            name = "ghcr.io/mrdavidlaing/laingville/example-python-runtime";
            packages = packageSets.base ++ packageSets.python;
          };

          # Example devcontainer with Node
          example-node-devcontainer = mkDevContainer {
            name = "ghcr.io/mrdavidlaing/laingville/example-node-devcontainer";
            packages = packageSets.base ++ packageSets.nixTools ++ packageSets.devTools
                    ++ packageSets.node ++ packageSets.nodeDev;
          };

          # Example runtime with Node
          example-node-runtime = mkRuntime {
            name = "ghcr.io/mrdavidlaing/laingville/example-node-runtime";
            packages = packageSets.base ++ packageSets.node;
          };
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
git commit -m "feat(infra): add flake.nix with package sets and builder functions

- Package sets: base, devTools, nixTools, python, pythonDev, node, nodeDev, go, goDev, rust, rustDev
- Builder functions: mkDevContainer, mkRuntime
- Overlay structure for CVE patches, license fixes, custom builds
- Example container images for testing"
```

---

## Phase 2: CI Workflows

### Task 2: Create container build workflow

**Files:**
- Update: `.github/workflows/build-containers.yml`

**Step 1: Update build-containers.yml for Nix builds**

```yaml
# .github/workflows/build-containers.yml
name: Build Containers

on:
  push:
    branches: [main]
    paths:
      - 'infra/flake.nix'
      - 'infra/flake.lock'
      - 'infra/overlays/**'
  workflow_dispatch:

env:
  REGISTRY: ghcr.io

jobs:
  build-images:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    strategy:
      matrix:
        image:
          - example-python-devcontainer
          - example-python-runtime
          - example-node-devcontainer
          - example-node-runtime

    steps:
      - uses: actions/checkout@v4

      - name: Install Nix
        uses: DeterminateSystems/nix-installer-action@main

      - name: Setup Nix cache
        uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Generate image tags
        id: tags
        run: |
          DATE=$(date +%Y-%m-%d)
          SHA=$(git rev-parse --short HEAD)
          echo "date=${DATE}" >> $GITHUB_OUTPUT
          echo "sha=${SHA}" >> $GITHUB_OUTPUT

      - name: Build ${{ matrix.image }} image with Nix
        run: |
          nix build ./infra#${{ matrix.image }} --out-link result

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Load and push image
        run: |
          # Load the Nix-built image into Docker
          docker load < result

          # Get the image name from the tarball
          IMAGE_NAME=$(docker images --format '{{.Repository}}:{{.Tag}}' | head -1)

          # Tag with date and SHA
          docker tag "$IMAGE_NAME" "${{ env.REGISTRY }}/mrdavidlaing/laingville/${{ matrix.image }}:${{ steps.tags.outputs.date }}"
          docker tag "$IMAGE_NAME" "${{ env.REGISTRY }}/mrdavidlaing/laingville/${{ matrix.image }}:${{ steps.tags.outputs.date }}-${{ steps.tags.outputs.sha }}"
          docker tag "$IMAGE_NAME" "${{ env.REGISTRY }}/mrdavidlaing/laingville/${{ matrix.image }}:latest"

          # Push all tags
          docker push "${{ env.REGISTRY }}/mrdavidlaing/laingville/${{ matrix.image }}:${{ steps.tags.outputs.date }}"
          docker push "${{ env.REGISTRY }}/mrdavidlaing/laingville/${{ matrix.image }}:${{ steps.tags.outputs.date }}-${{ steps.tags.outputs.sha }}"
          docker push "${{ env.REGISTRY }}/mrdavidlaing/laingville/${{ matrix.image }}:latest"
```

**Step 2: Commit**

```bash
git add .github/workflows/build-containers.yml
git commit -m "ci(infra): update container build workflow for Nix

- Uses nix build instead of docker build
- Builds example devcontainer and runtime images
- Uses DeterminateSystems Nix installer and magic-nix-cache"
```

---

### Task 3: Create nixpkgs update workflow

**Files:**
- Create: `.github/workflows/update-nixpkgs.yml`

**Step 1: Create update-nixpkgs.yml**

```yaml
# .github/workflows/update-nixpkgs.yml
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
        uses: DeterminateSystems/nix-installer-action@main

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
git add .github/workflows/update-nixpkgs.yml
git commit -m "ci(infra): add weekly nixpkgs update workflow

- Runs every Monday at 9am UTC
- Creates PR with flake.lock changes
- Includes review checklist"
```

---

### Task 4: Create security scan workflow

**Files:**
- Create: `.github/workflows/security-scan.yml`

**Step 1: Create security-scan.yml**

```yaml
# .github/workflows/security-scan.yml
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
  osv-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Nix
        uses: DeterminateSystems/nix-installer-action@main

      - name: Run OSV Scanner
        uses: google/osv-scanner-action@v2
        with:
          scan-args: |-
            --lockfile=infra/flake.lock
            --format=table
        continue-on-error: true

      - name: Check flake health
        working-directory: infra
        run: |
          echo "Checking flake builds..."
          nix flake check --no-build

          echo "Listing package versions..."
          nix eval .#devShells.x86_64-linux.python.buildInputs --json | jq -r '.[].name' || true

      - name: Security summary
        run: |
          echo "## Security Scan Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Channel**: nixos-25.11-small (fast security updates)" >> $GITHUB_STEP_SUMMARY
          echo "- **Scanner**: OSV Scanner (Google)" >> $GITHUB_STEP_SUMMARY
          echo "- **Flake lock**: $(date -r infra/flake.lock)" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "Review OSV output above for vulnerabilities." >> $GITHUB_STEP_SUMMARY
```

**Step 2: Commit**

```bash
git add .github/workflows/security-scan.yml
git commit -m "ci(infra): add OSV security scan workflow

- Daily scan + on changes to flake/overlays
- Uses Google OSV Scanner (production-ready)
- Checks flake health and package versions
- Generates GitHub step summary"
```

---

## Phase 3: Example Project Usage

### Task 5: Create example project template

**Files:**
- Create: `infra/templates/python-project/.devcontainer/devcontainer.json`
- Create: `infra/templates/python-project/flake.nix`
- Create: `infra/templates/python-project/.envrc`
- Create: `infra/templates/python-project/.github/workflows/ci.yml`

**Step 1: Create project flake.nix**

```nix
# templates/python-project/flake.nix
{
  description = "Python project using laingville infrastructure";

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
          name = "ghcr.io/my-org/my-project/devcontainer";
          packages = sets.base ++ sets.nixTools ++ sets.devTools
                  ++ sets.python ++ sets.pythonDev;
        };

        runtime = lib.mkRuntime {
          name = "ghcr.io/my-org/my-project/runtime";
          packages = sets.base ++ sets.python;
        };
      };
    };
}
```

**Step 2: Create devcontainer.json**

```json
{
  "name": "Python Project",
  "image": "ghcr.io/my-org/my-project/devcontainer:latest",
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
      ],
      "settings": {
        "python.defaultInterpreterPath": "/home/vscode/.nix-profile/bin/python3",
        "[python]": {
          "editor.formatOnSave": true,
          "editor.defaultFormatter": "charliermarsh.ruff"
        }
      }
    }
  }
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
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Push images
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: |
          docker load < devcontainer.tar.gz
          docker push ghcr.io/my-org/my-project/devcontainer:latest

          docker load < runtime.tar.gz
          docker push ghcr.io/my-org/my-project/runtime:latest
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

- flake.nix using infra's packageSets and mkDevContainer/mkRuntime
- devcontainer.json pointing to project-specific image
- CI workflow that builds and pushes images
- Uses nixpkgs.follows for layer sharing"
```

---

## Phase 4: Documentation

### Task 6: Create infrastructure README

**Files:**
- Update: `infra/README.md`

**Step 1: Create README.md**

```markdown
# Laingville Nix Container Infrastructure

Project-centric container architecture using pure Nix. Infrastructure provides **package sets** (building blocks) and **builder functions**. Projects compose these to create **project-specific** devcontainer and runtime images with **maximum Docker layer sharing**.

## Quick Start

### Using in a New Project

1. Create a `flake.nix` in your project:

```nix
{
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
      packages.${system} = {
        devcontainer = lib.mkDevContainer {
          name = "ghcr.io/my-org/my-project/devcontainer";
          packages = sets.base ++ sets.nixTools ++ sets.devTools
                  ++ sets.python ++ sets.pythonDev;
        };

        runtime = lib.mkRuntime {
          name = "ghcr.io/my-org/my-project/runtime";
          packages = sets.base ++ sets.python;
        };
      };
    };
}
```

2. Build your images:
```bash
nix build .#devcontainer
nix build .#runtime
```

3. Load into Docker:
```bash
docker load < result
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  infra/flake.nix (single source of truth)                           │
│                                                                     │
│  nixpkgs pinned @ nixos-25.11-small (weekly updates via CI)         │
│                                                                     │
│  Package Sets:                    Builder Functions:                │
│  ├── base                         ├── mkDevContainer { packages }   │
│  ├── devTools                     └── mkRuntime { packages }        │
│  ├── nixTools                                                       │
│  ├── python, pythonDev                                              │
│  ├── node, nodeDev                                                  │
│  ├── go, goDev                                                      │
│  └── rust, rustDev                                                  │
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
```

## Package Sets

| Set | Contents |
|-----|----------|
| `base` | bash, coreutils, findutils, grep, sed, cacert, tzdata |
| `devTools` | git, curl, jq, ripgrep, fd, fzf, bat, shadow, sudo |
| `nixTools` | nix, direnv, nix-direnv |
| `python` | python312 |
| `pythonDev` | pip, virtualenv, uv, ruff, pyright |
| `node` | nodejs_22 |
| `nodeDev` | bun, typescript, prettier, eslint |
| `go` | go |
| `goDev` | gopls, golangci-lint |
| `rust` | rustc, cargo |
| `rustDev` | rust-analyzer, clippy, rustfmt |

## Builder Functions

### mkDevContainer

Creates a development container with:
- vscode user (uid 1000) with sudo access
- direnv hook in bashrc
- Nix configured for flakes

```nix
lib.mkDevContainer {
  name = "ghcr.io/org/project/devcontainer";
  packages = sets.base ++ sets.devTools ++ sets.python;
  # Optional:
  user = "vscode";  # default
  extraConfig = {};  # additional Docker config
}
```

### mkRuntime

Creates a minimal production container with:
- app user (uid 1000, non-root)
- No development tools
- No Nix

```nix
lib.mkRuntime {
  name = "ghcr.io/org/project/runtime";
  packages = sets.base ++ sets.python;
  # Optional:
  user = "app";      # default
  workdir = "/app";  # default
  extraConfig = {};  # additional Docker config
}
```

## Docker Layer Sharing

All projects using `nixpkgs.follows = "infra/nixpkgs"` get **identical store paths** for shared packages. This means:

- Python in Project A = `/nix/store/xyz-python312`
- Python in Project B = `/nix/store/xyz-python312` (same hash!)
- Docker layers containing these paths are **shared**

Result: Only project-specific packages are downloaded when pulling images.

## Overlays

Custom Nix overlays in `overlays/`:

- `cve-patches.nix` - Security patches for Critical/High CVEs
- `license-fixes.nix` - Recompile to avoid copyleft
- `custom-builds.nix` - Custom compilation flags

## CI Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| build-containers | Push to main | Build example container images |
| security-scan | Daily + main | OSV CVE scanning |
| update-nixpkgs | Weekly | Automated flake.lock updates |

## Local Development

For local development without containers:

```bash
cd your-project
direnv allow
# Nix devShell activates automatically
```

Or explicitly:

```bash
nix develop
```
```

**Step 2: Commit**

```bash
git add infra/README.md
git commit -m "docs(infra): update README for package sets architecture

- Package sets and builder functions documentation
- Docker layer sharing explanation
- Example project usage"
```

---

## Phase 5: Cleanup and Migration

### Task 7: Remove old Dockerfile-based containers

**Files:**
- Delete: `infra/containers/` directory (if exists)
- Delete: `infra/devcontainer-features/` directory (if exists)

**Step 1: Remove old containers**

```bash
rm -rf infra/containers/
rm -rf infra/devcontainer-features/
```

**Step 2: Commit**

```bash
git add -A
git commit -m "refactor(infra): remove Dockerfile-based containers

- All images now built with dockerTools.buildLayeredImage
- No more Dockerfiles"
```

---

## Phase 6: Integration Test

### Task 8: Verify end-to-end flow

**Step 1: Build example images locally**

```bash
cd infra
nix build .#example-python-devcontainer -o result-devcontainer
nix build .#example-python-runtime -o result-runtime
```

Expected: Both builds succeed

**Step 2: Load images into Docker**

```bash
docker load < result-devcontainer
docker load < result-runtime
```

Expected: Images load successfully

**Step 3: Test devcontainer**

```bash
docker run --rm -it ghcr.io/mrdavidlaing/laingville/example-python-devcontainer:latest python --version
```

Expected: Python 3.12.x version printed

**Step 4: Test runtime**

```bash
docker run --rm -it ghcr.io/mrdavidlaing/laingville/example-python-runtime:latest python --version
```

Expected: Python 3.12.x version printed

**Step 5: Test devShell**

```bash
cd infra
nix develop .#python --command python --version
nix develop .#node --command node --version
```

Expected: Python 3.12.x and Node 22.x versions printed

**Step 6: Test flake check**

```bash
cd infra
nix flake check
```

Expected: No errors

---

## Summary

After completing all tasks, the infrastructure provides:

1. **Package sets** - Composable building blocks (base, devTools, python, node, go, rust)
2. **Builder functions** - mkDevContainer and mkRuntime
3. **Docker layer sharing** - Via shared nixpkgs pin
4. **CI workflows** - Build, scan, update
5. **Project template** - For new projects
6. **Documentation** - README with examples

### Key Benefits

- **Reproducibility**: Identical builds locally, in CI, and in production
- **Security**: Fast CVE patches via nixos-25.11-small + weekly updates
- **Developer experience**: Pre-built images, <30 second container startup
- **Docker caching**: Shared layers across all projects
- **Accurate SBOMs**: Each image = exact Nix closure

### Next Steps (Future Tasks)

- Add more package sets (java, cobol)
- Multi-arch support (aarch64-linux)
- SBOM generation from Nix closure for compliance
- Cachix/FlakeHub for faster CI if magic-nix-cache insufficient
