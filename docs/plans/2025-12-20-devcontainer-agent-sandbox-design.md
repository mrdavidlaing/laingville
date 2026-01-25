# Devcontainer + Leash Agent Sandbox Design

> **⚠️ NOT IMPLEMENTED - Future Enhancement**
>
> This document describes a **proposed design** that has not been implemented.
> The Leash policy enforcement, agent sandbox profiles, and related tooling
> described below do not exist in the current devcontainer setup. This design
> is preserved for future reference and potential implementation.

**Date:** 2025-12-20
**Author:** mrdavidlaing
**Status:** Proposed (Not Implemented)

## Problem

Running LLM agents (Claude Code, Cursor Agent, Aider) in "YOLO mode" (auto-approve all actions) poses security risks:

1. **Destructive operations** - Agents can `rm -rf /`, modify wrong files, or corrupt data
2. **Network abuse** - Agents can exfiltrate data, make unwanted API calls, or download malware
3. **Credential theft** - Agents can read SSH keys, API tokens, and cloud credentials
4. **Persistence** - Agents can install backdoors or modify shell configs
5. **Resource exhaustion** - Runaway processes can consume all CPU/memory

Current devcontainer setup provides basic isolation but lacks:
- Fine-grained network policy control
- Audit trail of agent actions
- Dynamic policy updates without rebuild
- Granular file access control within the container

## Solution

Layer **StrongDM Leash** policy enforcement inside devcontainers to create a comprehensive agent sandbox:

```
┌─────────────────────────────────────────────────────────────────┐
│                         AI Agent CLI                            │
│              (cursor-agent, claude, aider)                      │
├─────────────────────────────────────────────────────────────────┤
│  LEASH - Policy Enforcement Layer                               │
│  ├── Network: Allow/deny specific hosts                         │
│  ├── Filesystem: Allow/deny specific paths                      │
│  ├── Exec: Allow/deny specific commands                         │
│  └── Audit: Log all actions with policy decisions               │
├─────────────────────────────────────────────────────────────────┤
│  DEVCONTAINER - Isolation Layer                                 │
│  ├── Filesystem: Only /workspace mounted                        │
│  ├── Network: Container network namespace                       │
│  ├── Resources: Memory/CPU/PID limits                           │
│  └── Capabilities: Dropped dangerous caps                       │
├─────────────────────────────────────────────────────────────────┤
│  Docker / OCI Runtime                                           │
└─────────────────────────────────────────────────────────────────┘
```

**Key insight:** Running agent CLIs (cursor-agent, claude, aider) *inside* the container means ALL their activity—including API calls—passes through Leash for monitoring and control.

## Architecture

### Agent Execution Comparison

| Agent Setup | API Calls From | Leash Visibility |
|-------------|----------------|------------------|
| Cursor GUI + devcontainer | Host machine | Commands only ⚠️ |
| cursor-agent CLI in container | Container | Full ✅ |
| Claude Code CLI in container | Container | Full ✅ |
| Aider in container | Container | Full ✅ |

### Defense in Depth

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 4: Leash Policy                                          │
│  "Can this process call api.openai.com?" → Check policy         │
│  "Can this process write to ~/.ssh?" → DENY                     │
├─────────────────────────────────────────────────────────────────┤
│  Layer 3: Devcontainer Mounts                                   │
│  Only /workspace visible, no ~/.ssh, ~/.aws mounted             │
├─────────────────────────────────────────────────────────────────┤
│  Layer 2: Container Capabilities                                │
│  --cap-drop=ALL, --security-opt=no-new-privileges               │
├─────────────────────────────────────────────────────────────────┤
│  Layer 1: Resource Limits                                       │
│  --memory=8g, --cpus=4, --pids-limit=512                        │
└─────────────────────────────────────────────────────────────────┘
```

Each layer catches what previous layers might miss.

## Components

### 1. Base Devcontainer Configuration

Extend existing `laingville-devcontainer` with agent sandbox capabilities:

```json
{
  "name": "Agent Sandbox",
  "image": "ghcr.io/mrdavidlaing/laingville/laingville-devcontainer:latest",
  
  "postCreateCommand": "bash .devcontainer/setup-sandbox.sh",
  
  "containerEnv": {
    "ANTHROPIC_API_KEY": "${localEnv:ANTHROPIC_API_KEY}",
    "CURSOR_API_KEY": "${localEnv:CURSOR_API_KEY}",
    "OPENAI_API_KEY": "${localEnv:OPENAI_API_KEY}",
    "SANDBOX_MODE": "true"
  },
  
  "runArgs": [
    "--cap-drop=ALL",
    "--memory=8g",
    "--cpus=4",
    "--pids-limit=512",
    "--security-opt=no-new-privileges:true"
  ],
  
  "mounts": []
}
```

### 2. Leash Policy Configuration

Standard policy for agent sandboxes:

```yaml
# .leash/agent-sandbox.yaml
name: agent-sandbox
version: "1.0"

network:
  allow:
    # AI Provider APIs
    - "api.anthropic.com:443"
    - "api.openai.com:443"
    - "*.cursor.com:443"
    
    # Package Registries
    - "registry.npmjs.org:443"
    - "pypi.org:443"
    - "files.pythonhosted.org:443"
    - "crates.io:443"
    - "cache.nixos.org:443"
    
    # Git Operations
    - "github.com:443"
    - "github.com:22"
    - "gitlab.com:443"
    
  deny:
    - "*"  # Block everything else

filesystem:
  allow:
    - "/workspace/**"
    - "/tmp/**"
    - "/home/vscode/.cache/**"
    - "/home/vscode/.local/**"
    - "/home/vscode/.npm/**"
    - "/home/vscode/.cargo/**"
    
  deny:
    - "/home/vscode/.ssh/**"
    - "/home/vscode/.aws/**"
    - "/home/vscode/.azure/**"
    - "/home/vscode/.config/gcloud/**"
    - "/home/vscode/.gnupg/**"
    - "/etc/passwd"
    - "/etc/shadow"
    - "/etc/sudoers"

exec:
  allow:
    - "npm", "yarn", "pnpm", "bun"
    - "pip", "python", "python3"
    - "cargo", "rustc"
    - "go"
    - "nix", "nix-shell", "nix-build"
    - "git"
    - "node", "npx"
    - "make", "cmake"
    - "bash", "sh", "zsh"
    - "cat", "ls", "find", "grep", "sed", "awk"
    - "cursor-agent", "claude", "aider"
    
  deny:
    - "sudo", "su", "doas"
    - "docker", "podman", "nerdctl"
    - "mount", "umount"
    - "chmod", "chown"  # Restrict permission changes
    - "curl", "wget"     # Force package managers for downloads

audit:
  level: "all"
  output: "/workspace/.leash/audit.log"
  include_args: true
  include_env: false  # Don't log API keys
```

### 3. Tiered Sandbox Profiles

Different isolation levels for different use cases:

| Profile | Network | Filesystem | Use Case |
|---------|---------|------------|----------|
| **paranoid** | None | Read-only + tmpfs | Untrusted code review |
| **strict** | AI APIs + registries | Write to /workspace | YOLO coding tasks |
| **standard** | Full | Write to /workspace | Normal development |
| **trusted** | Full | Full mounts | Regular devcontainer |

```yaml
# .leash/profiles/paranoid.yaml
name: paranoid
inherits: agent-sandbox
network:
  allow: []  # Override: no network at all
filesystem:
  readonly: true
  allow:
    - "/tmp/**"  # tmpfs only
```

```yaml
# .leash/profiles/strict.yaml  
name: strict
inherits: agent-sandbox
# Uses base agent-sandbox policy as-is
```

### 4. Agent CLI Installation

Setup script to install agent CLIs:

```bash
#!/bin/bash
# .devcontainer/setup-sandbox.sh

set -e

echo "🔧 Setting up Agent Sandbox..."

# Install Cursor Agent CLI
if ! command -v cursor-agent &> /dev/null; then
    echo "📦 Installing Cursor Agent CLI..."
    curl https://cursor.com/install -fsS | bash
    export PATH="$HOME/.local/bin:$PATH"
fi

# Install Claude Code CLI
if ! command -v claude &> /dev/null; then
    echo "📦 Installing Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code
fi

# Install Aider
if ! command -v aider &> /dev/null; then
    echo "📦 Installing Aider..."
    pip install aider-chat
fi

# Install Leash
if ! command -v leash &> /dev/null; then
    echo "📦 Installing Leash..."
    curl -sSL https://get.leash.dev | bash
fi

# Create Leash directories
mkdir -p /workspace/.leash

# Verify installations
echo "✅ Installed tools:"
cursor-agent --version 2>/dev/null || echo "  cursor-agent: not installed"
claude --version 2>/dev/null || echo "  claude: not installed"  
aider --version 2>/dev/null || echo "  aider: not installed"
leash --version 2>/dev/null || echo "  leash: not installed"

echo "🎉 Agent Sandbox ready!"
```

### 5. Parallel Agent Execution

For running multiple agents in isolation:

```bash
#!/bin/bash
# scripts/spawn-agent-sandbox.sh

AGENT_ID="${1:-$(date +%s)}"
TASK="${2:-}"
BRANCH="${3:-main}"

WORKTREE_DIR="../sandbox-${AGENT_ID}"

# Create isolated worktree
git worktree add "$WORKTREE_DIR" -b "agent-${AGENT_ID}" "$BRANCH" 2>/dev/null || \
    git worktree add "$WORKTREE_DIR" "$BRANCH"

# Generate unique devcontainer config
mkdir -p "${WORKTREE_DIR}/.devcontainer"
cat > "${WORKTREE_DIR}/.devcontainer/devcontainer.json" << EOF
{
  "name": "Agent Sandbox ${AGENT_ID}",
  "image": "ghcr.io/mrdavidlaing/laingville/laingville-devcontainer:latest",
  "runArgs": [
    "--name=agent-sandbox-${AGENT_ID}",
    "--memory=4g",
    "--cpus=2",
    "--cap-drop=ALL"
  ],
  "containerEnv": {
    "AGENT_ID": "${AGENT_ID}",
    "SANDBOX_MODE": "true",
    "ANTHROPIC_API_KEY": "\${localEnv:ANTHROPIC_API_KEY}"
  },
  "postStartCommand": "leash --policy /workspace/.leash/strict.yaml &"
}
EOF

# Copy Leash policies
cp -r .leash "${WORKTREE_DIR}/"

echo "Created sandbox at: ${WORKTREE_DIR}"
echo ""
echo "To run agent:"
echo "  cd ${WORKTREE_DIR}"
echo "  cursor-agent -p --force \"${TASK}\""
echo ""
echo "To open in Cursor:"
echo "  cursor ${WORKTREE_DIR}"
```

### 6. Docker Compose for Orchestrated Agents

For batch/CI agent execution:

```yaml
# docker-compose.agents.yml
version: '3.8'

services:
  agent-coordinator:
    image: ghcr.io/mrdavidlaing/laingville/laingville-devcontainer:latest
    volumes:
      - ./:/workspace
      - agent-results:/results
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
    command: |
      bash -c "
        leash --policy /workspace/.leash/strict.yaml &
        claude --dangerously-skip-permissions 'Review PRs and merge if tests pass'
      "
    networks:
      - agent-network
    cap_drop:
      - ALL
    mem_limit: 4g

  agent-feature-1:
    image: ghcr.io/mrdavidlaing/laingville/laingville-devcontainer:latest
    volumes:
      - ./worktree-1:/workspace
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - AGENT_TASK=implement-auth
    command: |
      bash -c "
        leash --policy /workspace/.leash/strict.yaml &
        claude --dangerously-skip-permissions 'Implement user authentication'
      "
    networks:
      - agent-network
    cap_drop:
      - ALL
    mem_limit: 4g

  agent-feature-2:
    image: ghcr.io/mrdavidlaing/laingville/laingville-devcontainer:latest
    volumes:
      - ./worktree-2:/workspace
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - AGENT_TASK=implement-api
    command: |
      bash -c "
        leash --policy /workspace/.leash/strict.yaml &
        claude --dangerously-skip-permissions 'Implement REST API endpoints'
      "
    networks:
      - agent-network
    cap_drop:
      - ALL
    mem_limit: 4g

networks:
  agent-network:
    internal: true  # No internet except through Leash policy

volumes:
  agent-results:
```

## Directory Structure

```
infra/
├── flake.nix                    # Add agent sandbox package set
└── agent-sandbox/
    ├── devcontainer.json        # Template sandbox config
    ├── setup-sandbox.sh         # Agent CLI installation
    └── leash/
        ├── agent-sandbox.yaml   # Base policy
        └── profiles/
            ├── paranoid.yaml
            ├── strict.yaml
            └── standard.yaml

dotfiles/shared/
└── agent-sandbox/
    └── spawn-sandbox.sh         # Script to create isolated sandboxes

docs/
└── agent-sandbox-usage.md       # User documentation
```

## Integration with Existing Setup

### Nix Package Sets

Add agent tools to `infra/flake.nix`:

```nix
packageSets = {
  # ... existing sets ...
  
  agentTools = with pkgs; [
    # Agent CLIs installed via their own installers
    # But we include dependencies
    nodejs_22        # For claude-code
    python312        # For aider
    git
    curl
    jq
  ];
  
  agentSandbox = with pkgs; [
    # Leash and monitoring tools
    # (Leash installed via curl script until Nix package available)
  ];
};
```

### Devcontainer Image Variants

```nix
packages = {
  # ... existing containers ...
  
  # Agent sandbox variant
  agent-sandbox-devcontainer = mkDevContainer {
    name = "ghcr.io/mrdavidlaing/laingville/agent-sandbox-devcontainer";
    packages = packageSets.base ++ packageSets.vscodeCompat ++ packageSets.nixTools
            ++ packageSets.devTools ++ packageSets.agentTools;
  };
};
```

## Security Considerations

### What Leash Catches

- ✅ Unauthorized network connections (data exfiltration)
- ✅ Attempts to read sensitive files (credential theft)
- ✅ Privilege escalation attempts (sudo, docker)
- ✅ Suspicious command patterns (rm -rf, chmod 777)

### What Devcontainer Catches

- ✅ Access to unmounted paths (host filesystem)
- ✅ Resource exhaustion (memory, CPU, PIDs)
- ✅ Capability abuse (raw sockets, kernel modules)
- ✅ Container escape attempts

### Audit Trail

All agent actions logged to `/workspace/.leash/audit.log`:

```log
2025-01-20T10:15:32Z ALLOW network claude → api.anthropic.com:443 [policy: ai-providers]
2025-01-20T10:15:35Z ALLOW exec claude → npm install express [policy: package-managers]
2025-01-20T10:15:40Z ALLOW filesystem claude → WRITE /workspace/src/app.ts [policy: workspace]
2025-01-20T10:15:41Z DENY network curl → pastebin.com:443 [policy: deny-all]
2025-01-20T10:15:42Z DENY exec claude → sudo apt install [policy: no-privilege-escalation]
```

### Git Safety

Prevent agents from pushing directly:

```bash
# In setup-sandbox.sh
git config receive.denyCurrentBranch ignore
git remote set-url --push origin no-push-in-sandbox

# Agent can commit locally, but push requires human review
```

## Usage Workflows

### Interactive YOLO Mode

```bash
# Open project in Cursor with devcontainer
cursor .

# In container terminal, start Leash and run agent
leash --policy .leash/strict.yaml &
cursor-agent -p --force "Refactor the authentication module"
```

### Batch Agent Execution

```bash
# Prepare worktrees
git worktree add worktree-1 main
git worktree add worktree-2 main

# Run agents in parallel
docker compose -f docker-compose.agents.yml up

# Review and merge results
cd worktree-1 && git log --oneline -5
cd ../worktree-2 && git log --oneline -5
```

### CI Pipeline

```yaml
# .github/workflows/agent-tasks.yml
name: Agent Tasks

on:
  workflow_dispatch:
    inputs:
      task:
        description: 'Task for agent to complete'
        required: true

jobs:
  run-agent:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/mrdavidlaing/laingville/agent-sandbox-devcontainer:latest
      options: --cap-drop=ALL --memory=8g
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Agent with Leash
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          leash --policy .leash/strict.yaml &
          claude --dangerously-skip-permissions "${{ inputs.task }}"
      
      - name: Create PR with changes
        uses: peter-evans/create-pull-request@v5
        with:
          title: "Agent: ${{ inputs.task }}"
          branch: agent/${{ github.run_id }}
```

## Implementation Tasks

### Phase 1: Foundation

1. [ ] Create `infra/agent-sandbox/` directory structure
2. [ ] Create base Leash policy configuration
3. [ ] Create sandbox setup script with agent CLI installers
4. [ ] Add agent tools to Nix package sets
5. [ ] Create `agent-sandbox-devcontainer` image variant

### Phase 2: Tooling

6. [ ] Create `spawn-sandbox.sh` script for parallel agents
7. [ ] Create Docker Compose template for batch execution
8. [ ] Create tiered policy profiles (paranoid, strict, standard)
9. [ ] Add audit log viewer/analyzer script

### Phase 3: Integration

10. [ ] Integrate with existing dotfiles setup-user for API key injection
11. [ ] Create GitHub Actions workflow for CI agent execution
12. [ ] Add documentation for agent sandbox usage
13. [ ] Test with cursor-agent, claude, and aider

### Phase 4: Refinement

14. [ ] Monitor and tune Leash policies based on real usage
15. [ ] Add metrics/alerting for policy violations
16. [ ] Create policy templates for different project types
17. [ ] Document security best practices

## Alternatives Considered

### gVisor Runtime

**Pros:** Stronger isolation via user-space kernel
**Cons:** Performance overhead, complex setup, limited macOS support (Colima)

**Decision:** Keep as optional enhancement for paranoid mode

### Firecracker MicroVMs

**Pros:** VM-level isolation, fast boot
**Cons:** Requires KVM, not compatible with Docker Desktop/Colima

**Decision:** Not suitable for developer workstations

### E2B Cloud Sandboxes

**Pros:** Zero setup, fully managed
**Cons:** External dependency, cost, latency

**Decision:** Consider for CI/production, not local dev

## References

- [StrongDM Leash](https://github.com/strongdm/leash)
- [Dev Containers Specification](https://containers.dev/)
- [Cursor Agent CLI](https://docs.cursor.com/cli/agent)
- [Claude Code](https://docs.anthropic.com/claude-code)
- [gVisor](https://gvisor.dev/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)

