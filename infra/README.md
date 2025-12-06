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
