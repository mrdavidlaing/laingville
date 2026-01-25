# DevContainer Quickstart Guide

Get a working development environment in under 5 minutes.

## Prerequisites

Before you begin, ensure you have the following installed:

### Required

- **Docker** - Container runtime
  - macOS: [Docker Desktop](https://docs.docker.com/desktop/install/mac-install/) or [Colima](https://github.com/abiosoft/colima)
  - Linux: [Docker Engine](https://docs.docker.com/engine/install/)
  - Windows: [Docker Desktop with WSL2](https://docs.docker.com/desktop/install/windows-install/)

### For VS Code Workflow

- **VS Code** with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### For CLI Workflow

- **bash** (included on macOS/Linux, available via Git Bash on Windows)

### Optional (for GitHub integration)

- **GitHub CLI** (`gh`) - For GitHub API access within the container
  - Install: `brew install gh` (macOS) or see [installation guide](https://cli.github.com/manual/installation)
  - Authenticate: `gh auth login`

## Quick Start

### Option A: VS Code (Recommended)

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd laingville
   ```

2. **Open in VS Code**
   ```bash
   code .
   ```

3. **Reopen in Container**

   VS Code will detect the devcontainer configuration and prompt you:

   > Folder contains a Dev Container configuration file. Reopen folder to develop in a container?

   Click **"Reopen in Container"**

   Alternatively, open the Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`) and run:
   > Dev Containers: Reopen in Container

4. **Wait for build**

   First-time setup takes a few minutes to pull the pre-built image. Subsequent opens are nearly instant.

5. **Start coding**

   You now have a fully configured environment with:
   - Python (via uv)
   - Node.js (via fnm)
   - Go
   - Rust
   - All VS Code extensions pre-configured

### Option B: CLI Workflow

For users who prefer terminal-based development or CI/CD pipelines.

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd laingville
   ```

2. **Start the devcontainer**
   ```bash
   .devcontainer/bin/ctl up
   ```

   This will:
   - Pull the pre-built container image
   - Forward your GitHub credentials (if `gh` is authenticated)
   - Start the container in the background

3. **Open a shell**
   ```bash
   .devcontainer/bin/ctl shell
   ```

   You're now inside the container with full access to all development tools.

4. **When done, stop the container**
   ```bash
   .devcontainer/bin/ctl down
   ```

### Additional CLI Commands

```bash
.devcontainer/bin/ctl status  # Check container health
.devcontainer/bin/ctl help    # Show all commands
```

See [ctl-usage.md](./ctl-usage.md) for detailed CLI documentation.

## Development Mode (Ubuntu)

For local image development or customization, use the Ubuntu development mode:

### VS Code

1. Open the Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`)
2. Run: **Dev Containers: Open Folder in Container...**
3. Select the `.devcontainer/ubuntu` folder

### CLI

```bash
cd .devcontainer/ubuntu
docker compose up -d
docker compose exec devcontainer bash
```

This builds from `ubuntu.Dockerfile` locally instead of pulling a pre-built image.

## Troubleshooting

### Docker not running

**Symptom:** `Cannot connect to the Docker daemon`

**Solution:**
- macOS/Windows: Start Docker Desktop
- macOS with Colima: `colima start`
- Linux: `sudo systemctl start docker`

### Permission denied on Docker socket

**Symptom:** `Got permission denied while trying to connect to the Docker daemon socket`

**Solution (Linux):**
```bash
sudo usermod -aG docker $USER
# Log out and back in, or run:
newgrp docker
```

### VS Code can't find Dev Containers extension

**Symptom:** No "Reopen in Container" prompt

**Solution:**
1. Open VS Code Extensions (`Cmd+Shift+X` / `Ctrl+Shift+X`)
2. Search for "Dev Containers"
3. Install the extension by Microsoft
4. Reload VS Code

### Container fails to start

**Symptom:** `ctl up` exits with an error

**Solutions:**
1. Check Docker is running: `docker info`
2. View container logs: `docker compose -f .devcontainer/docker-compose.yml logs`
3. Try removing old containers: `.devcontainer/bin/ctl down && docker system prune`

### GitHub credentials not working

**Symptom:** `gh` commands fail inside container with authentication errors

**Solutions:**
1. Verify host authentication: `gh auth status`
2. Re-authenticate if needed: `gh auth login`
3. Restart the container: `.devcontainer/bin/ctl down && .devcontainer/bin/ctl up`

### SSH agent not forwarding

**Symptom:** `git push` prompts for password despite SSH key setup

**Solutions:**

macOS:
```bash
# Ensure SSH agent is running
ssh-add -l  # Should list your keys
# If empty:
ssh-add ~/.ssh/id_ed25519  # or your key path
```

Linux:
```bash
# Set the SSH socket before starting container
export DEVCONTAINER_SSH_SOCK=$SSH_AUTH_SOCK
.devcontainer/bin/ctl down
.devcontainer/bin/ctl up
```

### Slow performance on macOS

**Symptom:** File operations are noticeably slow

**Solution:** The compose file uses `:cached` volume mounts which should help. If still slow:
- Use Colima instead of Docker Desktop: `brew install colima && colima start`
- Consider using the [mutagen](https://mutagen.io/) extension for file sync

## Next Steps

- Read the [full devcontainer documentation](./devcontainer.md) for architecture details
- Learn about [multi-architecture builds](./devcontainer-multi-arch-setup.md)
- Explore [ctl commands](./ctl-usage.md) for advanced CLI usage
