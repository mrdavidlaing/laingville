# Migration: From Development to Secure Mode

This guide explains how to migrate a project from **Development Mode (Ubuntu)** to **Secure Mode (Nix)** once it reaches a level of maturity requiring strict reproducibility and security.

## The Evolutionary Path

Most projects follow a natural lifecycle:
1. **Sprouting (Dev Mode)**: Rapidly adding tools, experimenting with runtimes.
2. **Growing (Dev Mode)**: Stabilizing the toolset, defining project-specific scripts.
3. **Maturity (Secure Mode)**: Locking down versions for production and long-term maintenance.

## Migration Steps

### 1. Version Discovery
In your Ubuntu DevContainer, record the versions of all critical tools:
```bash
python3 --version
node --version
go version
bd --version
```

### 2. Update Infrastructure Flake
Open `infra/flake.nix` and ensure the `packageSets` include the tools and versions you identified.

### 3. Create Project Flake
Replace your `Dockerfile` with a `flake.nix`. 

**From (Ubuntu):**
```dockerfile
RUN apt-get install -y python3.12
```

**To (Nix):**
```nix
packages = sets.base ++ sets.python;
```

### 4. Switch DevContainer Configuration
Update `.devcontainer/devcontainer.json` to point to the new image and remove the `build` context.

### 5. Verify Bit-for-Bit
Run `nix build` and verify that the tools behave identically to the Ubuntu versions.

## Benefits of Migration

- **Image Size**: Nix images are often significantly smaller because they lack the `apt` cache and unnecessary system files.
- **Security**: You move from "hope-based security" (latest) to "audit-based security" (pinned + scanned).
- **Speed**: Pulling a pre-built Nix image is almost always faster than building a Dockerfile with many `RUN` commands.
