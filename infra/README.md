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
