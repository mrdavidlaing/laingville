# Devcontainer CTL Usage Guide

The `ctl` tool (`.devcontainer/bin/ctl`) manages the devcontainer lifecycle, including starting, stopping, and accessing the container with automatic GitHub credential forwarding.

## Quick Start

```bash
# Start the devcontainer
.devcontainer/bin/ctl up

# Open a shell in the running container
.devcontainer/bin/ctl shell

# Check status
.devcontainer/bin/ctl status

# Stop the devcontainer
.devcontainer/bin/ctl down
```

## Commands

### `ctl up`

Starts the devcontainer services with credential forwarding.

```bash
.devcontainer/bin/ctl up
```

**What it does:**
1. Sets up GitHub credentials by extracting your token from `gh auth`
2. Displays the forwarded credentials and their scopes
3. Starts the docker-compose services in detached mode
4. Shows next steps for accessing the container

**Example output:**
```
Starting devcontainer services...

🔐 GitHub credentials forwarded to agent:
✓ Account: your-github-username
✓ Scopes: repo, read:org, gist, workflow

   Agent capabilities:
   • Create PRs, issues, gists
   • Read organization membership
   • Pull from GitHub Package Registry
   • Full access to private repositories

   Blast radius: Container + GitHub API (via your token)
   Run 'gh auth status' on host to verify your scopes

✓ Devcontainer started

Next steps:
  • .devcontainer/bin/ctl shell    - Open interactive shell
  • .devcontainer/bin/ctl status   - Check service health
```

### `ctl down`

Stops and removes the devcontainer services.

```bash
.devcontainer/bin/ctl down
```

**What it does:**
1. Runs `docker compose down` to stop all services
2. Removes the stopped containers

### `ctl shell`

Opens an interactive bash shell in the running container.

```bash
.devcontainer/bin/ctl shell
```

**What it does:**
1. Checks if the devcontainer is running
2. If running, executes `bash` inside the container
3. If not running, shows an error with instructions to start it first

**Error case:**
```
✗ Devcontainer is not running
Start it first: .devcontainer/bin/ctl up
```

### `ctl status`

Shows the current status of devcontainer services.

```bash
.devcontainer/bin/ctl status
```

**Example output (running):**
```
Devcontainer services:

NAME                            IMAGE                                                     STATUS
laingville_devcontainer-1       ghcr.io/mrdavidlaing/laingville/laingville-devcontainer   Up 2 hours

✓ Devcontainer is running
  Workspace: /workspace
  Shell: .devcontainer/bin/ctl shell
```

**Example output (stopped):**
```
Devcontainer services:

NAME      IMAGE     COMMAND   SERVICE   CREATED   STATUS    PORTS

⚠ Devcontainer is not running
  Start: .devcontainer/bin/ctl up
```

### `ctl help`

Shows usage information.

```bash
.devcontainer/bin/ctl help
# or
.devcontainer/bin/ctl --help
# or
.devcontainer/bin/ctl -h
```

## GitHub Credential Forwarding

The `ctl` tool automatically forwards GitHub credentials to the container, enabling agents to interact with GitHub APIs.

### How It Works

1. **Token extraction**: When you run `ctl up`, the tool extracts your GitHub token from the `gh` CLI authentication
2. **Environment variable**: The token is passed to the container via the `GITHUB_TOKEN` environment variable
3. **Config sharing**: Your `~/.config/gh` directory is mounted read-only so the `gh` CLI works inside the container

### Prerequisites

Before using `ctl up`, ensure:

1. **GitHub CLI installed**: `brew install gh` (macOS) or your package manager
2. **Authenticated**: Run `gh auth login` and complete the authentication flow
3. **Verify scopes**: Run `gh auth status` to see your current token scopes

### SSH Agent Forwarding

The container also supports SSH agent forwarding for Git operations over SSH:

- **macOS (Colima/Docker Desktop)**: Uses `/run/host-services/ssh-auth.sock` by default
- **Linux**: Set `DEVCONTAINER_SSH_SOCK=$SSH_AUTH_SOCK` before running `ctl up`

The SSH agent socket is mounted at `/ssh-agent` inside the container with `SSH_AUTH_SOCK` environment variable set automatically.

### Security Considerations

The credential forwarding gives the container:
- Full access to your private repositories
- Ability to create PRs, issues, and gists
- Read access to organization membership
- Access to GitHub Package Registry

**Blast radius**: The container and GitHub API (via your token). The container itself has no restrictions on package installation, file access, or command execution within its boundaries.

## Docker Compose Integration

The `ctl` tool is a wrapper around `docker compose` commands, using:
- **Compose file**: `.devcontainer/docker-compose.yml`
- **Project name**: `{repo-name}_devcontainer` (e.g., `laingville_devcontainer`)

You can also use docker compose directly if needed:

```bash
cd .devcontainer
docker compose -p laingville_devcontainer up -d
docker compose -p laingville_devcontainer exec devcontainer bash
docker compose -p laingville_devcontainer down
```

### Volume Mounts

The docker-compose.yml configures these volumes:

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `..` (repo root) | `/workspace` | Agent's working directory |
| SSH agent socket | `/ssh-agent` | Git SSH operations |
| `~/.config/gh` | `/home/vscode/.config/gh` | GitHub CLI config (read-only) |

## Troubleshooting

### "GitHub CLI (gh) not found"

Install the GitHub CLI:
```bash
brew install gh          # macOS
apt install gh           # Debian/Ubuntu
dnf install gh           # Fedora
```

### "GitHub CLI not authenticated"

Authenticate with GitHub:
```bash
gh auth login
```

### "Devcontainer is not running"

Start the container first:
```bash
.devcontainer/bin/ctl up
```

### SSH operations failing

On Linux, ensure the SSH agent socket is available:
```bash
export DEVCONTAINER_SSH_SOCK=$SSH_AUTH_SOCK
.devcontainer/bin/ctl up
```

### Container not pulling latest image

Force a fresh pull:
```bash
cd .devcontainer
docker compose pull
.devcontainer/bin/ctl up
```
