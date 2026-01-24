# DevContainer Architecture

**Purpose:** Define a composable, reproducible development environment architecture that supports both secure production workflows and rapid development iteration.

**Status:** Architectural Specification

---

## Design Philosophy

Development environments should be:
1. **Reproducible** - Same environment locally, in CI, and for AI agents
2. **Composable** - Base capabilities + project-specific extensions
3. **Secure** - Pinned versions, verified SBOMs, airgap-friendly
4. **Flexible** - Fast iteration for development, strict controls for production

These goals create tension. This architecture resolves it through **dual implementation modes** serving different use cases.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEVCONTAINER IMAGE                           │
├─────────────────────────────────────────────────────────────────┤
│  Layer 2: Project Features (optional)                           │
│  ├── Project-specific CLI tools (kubectl, terraform, etc.)      │
│  ├── Workflow tools (shellspec, k9s, etc.)                      │
│  └── Custom scripts and configurations                          │
├─────────────────────────────────────────────────────────────────┤
│  Layer 1: Feature Extensions (composable)                       │
│  ├── pensive-assistant (beads, zellij, lazygit, claude)         │
│  ├── language-specific tooling (gopls, rust-analyzer, etc.)     │
│  └── IDE extensions (LSPs, formatters, linters)                 │
├─────────────────────────────────────────────────────────────────┤
│  Layer 0: Base DevContainer Image (The Bedrock)                 │
│  ├── OS Foundation (Ubuntu LTS, Arch, or Nix)                   │
│  ├── Common dev tools (git, curl, jq, ripgrep, fd, fzf)         │
│  ├── Language runtimes (python, node, go, rust, etc.)           │
│  ├── Shell environment (bash, zsh, starship)                    │
│  └── Container user setup (vscode, sudo, direnv)                │
└─────────────────────────────────────────────────────────────────┘

**Key Insight:** Layer 0 is the "Standard Operating Environment" (SOE). It is physically built as a single image but logically serves as the foundation for all specialized work.
```

**Key Insight:** Layers 1-3 are **logically separate** but can be physically built either:
- **Pre-built** (secure mode) - Versioned container images in OCI registry
- **Runtime** (development mode) - Installed at container creation time

---

## Layer Definitions

### Layer 0: Base DevContainer Image (The Bedrock)

**Purpose:** A unified, standard operating environment providing both the OS foundation and a core set of development tools.

**Contents:**

| Category | Components |
|----------|------------|
| **OS Foundation** | Minimal distro (Ubuntu 24.04, Arch), core libraries, package manager |
| **Shell Environment** | bash, zsh, starship, direnv |
| **Version Control** | git, git-lfs, gh (GitHub CLI) |
| **Search & Navigation** | ripgrep, fd, fzf, bat, eza |
| **Network** | curl, wget, openssh, netcat |
| **Data Processing** | jq, yq, xmlstarlet |
| **Text Editing** | neovim, vim |
| **Language Runtimes** | python3, nodejs, go, rust |
| **Build Tools** | make, cmake, gcc, clang |
| **Container User** | vscode/coder (uid 1000, sudo) |

**Design Decisions:**
- **Unified Integrity** - By building OS and tools together, we ensure binary compatibility (e.g., Python built against the exact glibc in the image).
- **Global Caching** - Every project shares this exact layer, maximizing pull speed and disk efficiency.
- **AI Agent Baseline** - Provides a consistent, rich toolset that agents can rely on without guessing what's installed.
- **Polyglot Foundation** - Includes all major runtimes so cross-language "Implementing Agents" never lack a required compiler.

---

### Layer 1: Feature Extensions (Composable)

**Purpose:** Composable, reusable tool bundles for specific workflows or technologies.

**Examples:**

| Feature | Contains | Use Case |
|---------|----------|----------|
| **pensive-assistant** | beads, zellij, lazygit, claude | Issue tracking + AI workflows |
| **python-dev** | pip, uv, ruff, pyright, black | Python development |
| **node-dev** | npm, yarn, pnpm, bun, eslint | Node.js development |
| **go-dev** | gopls, golangci-lint, delve | Go development |
| **terraform** | terraform, terragrunt, tflint | Infrastructure as Code |
| **kubernetes** | kubectl, k9s, helm, kustomize | Kubernetes workflows |

**Feature Characteristics:**
- **Self-contained** - All dependencies bundled (no system package conflicts)
- **Composable** - Multiple features can be combined in one container
- **Versioned** - Explicit version pinning for reproducibility
- **Documented** - Clear purpose, contents, and usage

**Distribution Mechanism:**
- Secure mode: Pre-built tarballs in OCI registry
- Development mode: Install scripts that fetch latest versions
- Common interface: DevContainer Feature specification

**Why Features Exist:**
- Not all projects need all tools (avoid bloat)
- Different projects need different versions (golang 1.21 vs 1.22)
- Encapsulate domain expertise (correct tool combinations)
- Enable independent updates (update terraform without rebuilding base)

---

### Layer 2: Project Features

**Purpose:** Project-specific tools, scripts, and configurations.

**Examples:**
- Project CLI tools (`happy` for laingville)
- Custom build scripts
- Project-specific linters/formatters
- Database migration tools
- Mock services or test harnesses

**Implementation:**
- Defined in project's `.devcontainer/` directory
- Can use Feature Extension format for reusability
- Often installed via `postCreateCommand` in devcontainer.json

**Why Layer 3 Exists:**
- Every project has unique needs
- Keeps project-specific concerns out of shared infrastructure
- Enables project teams to self-serve

---

## Implementation Modes

The same logical architecture can be implemented in two fundamentally different ways:

### Mode 1: Secure / Airgap-Friendly (Production)

**Use Cases:**
- Production workloads
- CI/CD pipelines
- Regulated environments (SOC2, HIPAA, FedRAMP)
- Airgapped networks (no internet access)
- Security-critical development

**Characteristics:**

| Aspect | Implementation |
|--------|----------------|
| **Version Pinning** | Explicit version for every package |
| **Build Process** | Pre-built in CI, pushed to OCI registry |
| **Distribution** | Pull from ghcr.io or private registry |
| **SBOM** | Generated during build, published alongside image |
| **Updates** | Deliberate (weekly/monthly), tested before rollout |
| **Reproducibility** | Bit-for-bit identical builds |
| **Network** | Works offline after initial pull |

**Build Workflow:**

```
1. CI Trigger (weekly or on infra change)
   ↓
2. Build Base DevContainer
   - Pin all package versions (e.g., Nix flake.lock)
   - Generate SBOM (list all dependencies + licenses)
   - Build multi-arch images (amd64, arm64)
   ↓
3. Build Feature Extensions
   - Compute delta from base image (only new packages)
   - Create tarball with dependency closure
   - Generate per-feature SBOM
   ↓
4. Push to OCI Registry
   - ghcr.io/org/base-devcontainer:2025-01-24
   - ghcr.io/org/base-devcontainer:2025-01-24-abc1234
   - ghcr.io/org/pensive-assistant-tarball:latest-amd64
   ↓
5. Security Scan
   - OSV Scanner for CVEs
   - License compliance check
   - Fail build on Critical/High CVEs
   ↓
6. Publish SBOM
   - Attach to OCI artifact
   - Upload to compliance dashboard
```

**User Workflow:**

```json
// .devcontainer/devcontainer.json
{
  "name": "My Project",
  "image": "ghcr.io/org/base-devcontainer:2025-01-24",
  "features": {
    "ghcr.io/org/devcontainer-features/pensive-assistant:1.2.3": {}
  }
}
```

Result: Instant startup, no build, no network needed after pull.

**Implementation Technologies:**
- **Nix** - Hash-based reproducibility, precise dependency closure
- **Docker buildLayeredImage** - Layer caching, multi-arch support
- **ORAS** - OCI registry for non-image artifacts (feature tarballs)
- **OSV Scanner** - Vulnerability detection

---

### Mode 2: Development / Rapid Iteration (Modernized Ubuntu)

**Use Cases:**
- Local development
- Prototyping new features
- High AI agent compatibility
- Fast feedback loops

**Characteristics:**

| Aspect | Implementation |
|--------|----------------|
| **OS Base** | Ubuntu 24.04 LTS |
| **Version Pinning** | Loose (latest, ^1.2.0) |
| **Build Process** | Runtime install via Dockerfile/scripts |
| **Tool Acquisition** | Upstream binaries (curl, uv, gh) |
| **Agent Profile** | High (standard Ubuntu paths/tools) |

**Build Workflow:**

```
1. Developer opens project
   ↓
2. Bedrock Image build: Dockerfile executes
   - apt-get install (system deps)
   - curl/uv/gh (latest dev tools)
   ↓
3. Feature Extensions: install.sh executes
   - Detects Ubuntu base
   - Fetches latest binaries
   ↓
4. Container ready
```

**User Workflow:**

```dockerfile
# .devcontainer/Dockerfile
FROM ubuntu:24.04

# Base tools
RUN apt-get update && apt-get install -y \
    git curl jq ripgrep fd-find fzf bat \
    python3 python3-pip nodejs npm golang \
    && rm -rf /var/lib/apt/lists/*

# Feature extensions (runtime install)
COPY features/pensive-assistant/install.sh /tmp/
RUN bash /tmp/install.sh
```

Result: Fresh packages, latest versions, longer build time.

**Implementation Technologies:**
- **apt/pacman** - System package managers
- **GitHub Releases** - Download latest binaries
- **Language package managers** - pip, npm, cargo install
- **Dev-mode Nix** - `nix-shell` for project-specific envs

---

## Mode Comparison

| Dimension | Secure Mode | Development Mode |
|-----------|-------------|------------------|
| **Startup Time** | Instant (pull pre-built) | 2-5 min (build at creation) |
| **Version Control** | Explicit pins | Latest at build time |
| **Reproducibility** | Exact (hash-based) | Approximate (date-based) |
| **Security** | Audited, SBOM, CVE-free | Best effort |
| **Offline Support** | Full (after initial pull) | None (needs network) |
| **Flexibility** | Change = rebuild in CI | Change = instant rebuild |
| **SBOM** | Required, auditable | Optional |
| **Compliance** | SOC2/HIPAA ready | Not suitable |
| **Best For** | Production, CI, regulated | Prototyping, learning |

---

## Implementation Strategy

### Shared Architecture, Dual Backends

Both modes share the same **logical architecture** (Bedrock + Features + Project) but implement it differently:

```
┌─────────────────────────────────────────────────────────────┐
│         Logical Architecture (same for both modes)          │
│                                                             │
│      Bedrock Image + Feature Extensions + Project Config    │
└─────────────────────────────────────────────────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         ▼                                   ▼
┌─────────────────────┐          ┌──────────────────────┐
│   Secure Backend    │          │  Development Backend │
│                     │          │                      │
│ • Nix flakes        │          │ • Dockerfile         │
│ • buildLayeredImage │          │ • apt/pacman         │
│ • OCI registry      │          │ • Runtime install    │
│ • Pre-built images  │          │ • Latest versions    │
└─────────────────────┘          └──────────────────────┘
```
```

### Migration Path

Projects can start in **Development Mode** and graduate to **Secure Mode**:

**Stage 1: Prototype** (Development Mode)
- Dockerfile with `apt-get install`
- Iterate quickly, no version pinning
- Learn what tools you actually need

**Stage 2: Stabilize** (Development Mode + Pinning)
- Pin major versions (python3.12, node22)
- Document tool choices
- Add basic tests

**Stage 3: Harden** (Hybrid)
- Base image from secure mode (pre-built)
- Features still runtime-installed
- Balance between speed and security

**Stage 4: Production** (Secure Mode)
- Everything pre-built
- SBOM required
- CVE scanning in CI
- Offline-capable

---

## Feature Extension Specification

Both modes must implement the same **Feature Extension Interface**:

### Required Files

```
features/my-feature/
├── devcontainer-feature.json   # Metadata
└── install.sh                   # Installation logic
```

### devcontainer-feature.json

```json
{
  "id": "my-feature",
  "version": "1.0.0",
  "name": "My Feature",
  "description": "Tools for X workflow",
  "options": {
    "version": {
      "type": "string",
      "default": "latest",
      "description": "Version to install"
    }
  }
}
```

### install.sh Interface

```bash
#!/bin/bash
# Input: Environment variables from options
# Output: Tools installed and in PATH
# Requirements:
#   - Must work with or without network (if tarball pre-downloaded)
#   - Must be idempotent (safe to run multiple times)
#   - Must verify installation success

set -e

# Secure mode: Use pre-built tarball
if [ -f "$FEATURE_DIR/dist/tarball.tar.gz" ]; then
  tar -xzf "$FEATURE_DIR/dist/tarball.tar.gz" -C /

# Development mode: Install latest
else
  apt-get update && apt-get install -y <packages>
fi

# Configure environment
cat > /etc/profile.d/my-feature.sh << 'EOF'
export PATH="/opt/my-feature/bin:$PATH"
EOF
```

---

## Directory Structure

```
laingville/
├── docs/
│   ├── devcontainer.md                    # THIS FILE (architecture)
│   ├── specs/
│   │   └── devcontainer-feature.md        # Feature extension spec
│   └── implementations/
│       ├── nix/                            # Secure mode implementation
│       │   ├── README.md                   # How to use Nix backend
│       │   └── pensive-assistant.md        # Example walkthrough
│       └── ubuntu/                         # Development mode implementation
│           ├── README.md                   # How to use Ubuntu backend
│           └── migration.md                # Port from Nix to Ubuntu
│
├── infra/
│   ├── flake.nix                          # Secure mode: Nix definitions
│   ├── overlays/                          # Secure mode: CVE patches
│   └── templates/                         # Example devcontainer.json
│
└── .devcontainer/
    ├── devcontainer.json                  # Current: Secure mode
    ├── docker-compose.yml                 # Multi-container setup
    └── features/
        └── pensive-assistant/             # Example feature
            ├── devcontainer-feature.json
            ├── install.sh                  # Works in both modes!
            ├── flake.nix                   # Secure mode build
            └── build-delta-tarball.sh      # Secure mode CI
```

---

## Security Considerations

### Secure Mode Guarantees

✅ **Reproducible builds** - Same input hash = same output
✅ **Offline operation** - No network after initial pull
✅ **SBOM tracking** - Every dependency documented
✅ **CVE scanning** - Automated security checks
✅ **Audit trail** - Git history of all version changes
✅ **Rollback** - Immutable tags (never overwrite published versions)

### Development Mode Risks

⚠️ **Non-reproducible** - Build tomorrow ≠ build today
⚠️ **Network required** - Can't build offline
⚠️ **No SBOM** - Unknown dependencies
⚠️ **CVE exposure** - No automated scanning
⚠️ **Supply chain** - Direct downloads from internet

**Mitigation:** Use development mode only for non-production workloads.

---

## Decision Matrix

**Choose Secure Mode if:**
- Running in production
- Subject to compliance requirements (SOC2, HIPAA, etc.)
- Airgapped or restricted network environment
- Need audit trail of all dependencies
- Multi-team coordination (pinned versions prevent breakage)

**Choose Development Mode if:**
- Local development only
- Prototyping or learning
- Need latest tool versions
- Fast iteration more important than reproducibility
- Small team with informal security posture

**Hybrid Approach:**
- Base image from secure mode (stable foundation)
- Features installed at runtime (flexibility)
- Balance between speed and security

---

## Future Enhancements

### Multi-Registry Support
- **Public**: ghcr.io/mrdavidlaing/laingville
- **Private**: registry.company.com/devcontainers
- **Airgap**: Harbor registry on-premises

### SBOM Integration
- Attach SBOM to OCI artifacts (SPDX, CycloneDX formats)
- Automated compliance reporting
- License violation detection

### Multi-Architecture Builds
- Native ARM64 for Apple Silicon
- Cross-compilation in CI
- Platform-specific optimizations

### Feature Marketplace
- Discover community-maintained features
- Automated security scanning
- Version compatibility matrix

---

## References

- [DevContainer Specification](https://containers.dev/)
- [DevContainer Features](https://containers.dev/implementors/features/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [OCI Artifacts](https://github.com/opencontainers/artifacts)
- [ORAS (OCI Registry As Storage)](https://oras.land/)
- [OSV Scanner](https://github.com/google/osv-scanner)
- [SBOM Standards](https://www.cisa.gov/sbom)

---

## Implementation Status

| Component | Secure Mode | Development Mode |
|-----------|-------------|------------------|
| Bedrock Image | ✅ Nix-based | 🚧 Ubuntu planned |
| Feature: pensive-assistant | ✅ Nix + OCI | 🚧 apt planned |
| OCI Distribution | ✅ ghcr.io | N/A |
| SBOM Generation | 🚧 Planned | N/A |
| Multi-arch | ✅ amd64, arm64 | TBD |
| Documentation | 📝 In progress | 📝 In progress |

**Legend:** ✅ Complete | 🚧 In Progress | 📝 Planned
