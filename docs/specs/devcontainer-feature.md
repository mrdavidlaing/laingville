# DevContainer Feature Interface Specification

**Purpose:** Define the contract between a Feature Extension and the DevContainer environment to ensure compatibility across both Secure (Nix) and Development (Ubuntu) modes.

---

## 1. Directory Structure

A feature MUST follow the standard DevContainer Feature structure:

```
features/my-feature/
├── devcontainer-feature.json   # Metadata and Options
├── install.sh                   # Installation Orchestrator
└── README.md                    # Documentation
```

---

## 2. Metadata (devcontainer-feature.json)

The metadata file MUST define:
- **id**: Unique identifier.
- **version**: Semantic version of the feature.
- **options**: Configuration parameters (e.g., version to install).
- **containerEnv**: Environment variables to inject (e.g., `PATH`).

```json
{
  "id": "pensive-assistant",
  "version": "1.0.0",
  "name": "Pensive Assistant",
  "options": {
    "version": {
      "type": "string",
      "proposals": ["latest", "stable"],
      "default": "latest"
    }
  },
  "containerEnv": {
    "PATH": "/usr/local/bin/pensive:${PATH}"
  }
}
```

---

## 3. The Installation Orchestrator (install.sh)

`install.sh` is the primary entry point. It MUST implement logic for both implementation modes.

### Mode Detection

The script SHOULD detect its environment to choose the appropriate installation path:

```bash
# Detect OS Foundation
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_ID=$ID
fi

# Detect Nix presence
HAS_NIX=$(command -v nix >/dev/null 2>&1 && echo "true" || echo "false")
```

### Path A: Secure Mode (Immutable Extraction)

When running in Secure Mode, the script SHOULD prefer extracting a pre-built closure.

- **Source**: Look for a local tarball in the feature's `dist/` directory.
- **Action**: Extract to `/`.
- **Integrity**: Validate checksums if provided.

### Path B: Development Mode (Mutable Installation)

When running in Development Mode, the script SHOULD fetch tools from upstream.

- **Source**: GitHub Releases, official installers, or `apt`.
- **Action**: Install to `/usr/local/bin` or a feature-specific prefix.
- **Freshness**: Respect the `VERSION` option, defaulting to `latest`.

---

## 4. Requirement Contract

To ensure a feature works in the Laingville ecosystem, it MUST:

1. **Be Idempotent**: Safe to run multiple times without side effects.
2. **Handle Architecture**: Support both `x86_64` (amd64) and `aarch64` (arm64).
3. **Minimize Bloat**: In Secure Mode, only package the **delta** (paths not in Bedrock).
4. **Clean Up**: Remove temporary files and build artifacts after installation.
5. **Set Permissions**: Ensure binaries are executable and owned by the correct user.

---

## 5. Environment Integration

Features SHOULD integrate with the environment via:

- **PATH**: Adding its bin directory to the system PATH.
- **Profile.d**: Adding a script to `/etc/profile.d/` for shell initialization.
- **Symlinks**: Creating symlinks in `~/.local/bin` for user-space access.

---

## 6. Testing

Every feature SHOULD provide a `test.sh` that verifies:
- All binaries are in PATH.
- `tool --version` returns expected output.
- Basic functionality works (e.g., `bd list` succeeds).
