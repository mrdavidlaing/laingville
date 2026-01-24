# Ubuntu DevContainer Template

A minimal Ubuntu-based devcontainer template for rapid development mode.

## Quick Start

1. Copy these files to your project's `.devcontainer/` directory:
   ```bash
   cp -r infra/templates/ubuntu-devcontainer/* your-project/.devcontainer/
   ```

2. Open your project in VS Code and select "Reopen in Container"

3. The container will build with:
   - Ubuntu 24.04 LTS base
   - Python 3.12 (via uv)
   - Node.js LTS (via fnm)
   - Go (latest stable)
   - Rust (latest stable)
   - Common dev tools (git, ripgrep, fd, fzf, bat, eza, jq, etc.)
   - pensive-assistant feature tools (optional)

## Customization

### Add More Tools

Edit `Dockerfile` and add RUN commands:
```dockerfile
RUN apt-get update && apt-get install -y \
    your-package-here \
    && rm -rf /var/lib/apt/lists/*
```

### Add VS Code Extensions

Edit `devcontainer.json` and add to the extensions array:
```json
"extensions": [
  "your.extension-id"
]
```

### Install Features

Reference local or remote features:
```json
"features": {
  "ghcr.io/devcontainers/features/docker-in-docker:2": {}
}
```

## Architecture

This template follows the **Development Mode** architecture:
- **Layer 0 (Bedrock)**: OS + language runtimes + dev tools
- **Layer 1 (Features)**: Optional composable tool bundles
- **Layer 2 (Project)**: Project-specific tools and scripts

See `docs/devcontainer.md` for full architecture details.

## Migration to Secure Mode

When your project matures and needs reproducibility:

1. Capture versions from your running container:
   ```bash
   python3 --version
   node --version
   go version
   ```

2. Follow the migration guide at `docs/implementations/ubuntu/migration.md`

3. Switch to the Nix-based secure mode for production use

## Troubleshooting

### Build is slow
- First build downloads all tools (~5-10 minutes)
- Subsequent builds use Docker layer cache (~1-2 minutes)

### Tool not found
- Check that tool is installed in Dockerfile
- Verify PATH includes `/usr/local/bin` and `~/.local/bin`
- Restart VS Code terminal after container rebuild

### Permission errors
- Ensure user is `vscode` (default)
- Check that directories are owned by `vscode:vscode`
