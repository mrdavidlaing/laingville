# GitHub Actions Workflows

This directory contains automated CI/CD workflows for the Laingville repository.

## Workflows Overview

### Security & Scanning

#### `security-scan.yml` - Security Vulnerability Scanning
Comprehensive security scanning of container images and repository code.

**Triggers:**
- Daily at 6am UTC (schedule)
- After `Build Containers` completes on main
- Pull requests touching `infra/` files
- Manual trigger

**Scanners:**
- **Vulnix**: Nix-specific CVE scanner for devShells
- **Trivy**: Container vulnerability scanner (SARIF → GitHub Security)
- **Grype**: Anchore container scanner (SARIF → GitHub Security)
- **Syft**: SBOM generation (SPDX, CycloneDX)
- **cdxgen**: Repository SBOM generation
- **Gitleaks**: Secret detection in git history

**Outputs:**
- SARIF results uploaded to GitHub Security tab
- SBOM artifacts available in workflow artifacts
- Table output in job logs for CRITICAL/HIGH findings

**Dependabot Integration:**
- Container SBOMs (SPDX, CycloneDX) are automatically submitted to GitHub's Dependency Graph via the Dependency Submission API
- Dependabot monitors all dependencies in the graph against the GitHub Advisory Database
- When vulnerabilities are found, alerts appear in **Repository → Security → Dependabot alerts**
- Package types covered: OS packages (glibc, openssl, etc.), language packages (npm, pip), and container base images
- Configuration: `.github/dependabot.yml` enables monitoring for npm, pip, GitHub Actions, and Docker dependencies

#### `claude-security-fix.yml` - Automated Security Remediation
Uses the Claude Code Action to automatically identify and fix security vulnerabilities.

**Triggers:**
- Weekly on Mondays at 9am UTC (schedule)
- After `Security Scan` completes on main
- Manual trigger

**What it does:**
1. Runs the `/security-fix` slash command via the official Claude Code Action
2. Analyzes GitHub security code-scanning alerts
3. Applies fixes following the security-fix playbook:
   - First attempts nixpkgs upstream update
   - If needed, adds targeted Nix overlays/patches
4. Creates a PR with the proposed fixes

**Requirements:**
- `CLAUDE_CODE_OAUTH_TOKEN` secret must be configured in repository settings
- See [Setup Guide](#setting-up-claude-code-automation) below

**Branch naming:** `claude/security-fix-<timestamp>`

**PR labels:** `security`, `automated`

#### `security-response.yml` - Automated Security Alert Triage
Continuously monitors GitHub Security API for new vulnerabilities and automatically invokes Claude for HIGH/CRITICAL alerts.

**Triggers:**
- After `Security Scan` completes on main (workflow_run)
- Hourly polling at :00 UTC (schedule)
- Manual trigger with optional deduplication override

**What it does:**
1. Polls GitHub Code Scanning API for open security alerts
2. Filters to new alerts using deduplication state (`.github/.security-response-state`)
3. Runs `bin/security-triage` to categorize alerts by severity
4. Automatically invokes `claude-security-fix` workflow for HIGH/CRITICAL alerts
5. Tracks processed alert numbers to prevent duplicate processing

**Deduplication:**
- Maintains state file (`.github/.security-response-state`) with last processed alert number
- Prevents duplicate PRs for same alerts across multiple runs
- Can be overridden with `force_process_all` flag for manual re-processing

**How to view results:**
- **Workflow logs**: GitHub Actions → Security Response workflow
- **Security alerts**: Repository → Security → Code scanning alerts
- **Triggered fixes**: Check `claude-security-fix` workflow runs (triggered automatically)
- **State tracking**: `.github/.security-response-state` file in repository

**Concurrency:**
- Only one run at a time (prevents duplicate processing)
- Queued runs execute sequentially

### Build & Deployment

#### `build-containers.yml` - Container Image Building
Builds and publishes container images to GitHub Container Registry.

**Triggers:**
- Push to main branch
- Pull requests (build only, no publish)
- Manual trigger

**Images built:**
- `laingville-devcontainer` - Main development container
- `example-python-devcontainer` - Python dev environment
- `example-python-runtime` - Python production runtime
- `example-node-devcontainer` - Node.js dev environment
- `example-node-runtime` - Node.js production runtime

**Registry:** `ghcr.io/mrdavidlaing/laingville/`

**Tagging strategy:**
- Main branch: `latest` + `sha-<commit>`
- Pull requests: `pr-<number>` (not published)

### Testing

#### `test.yml` - Automated Testing
Runs test suites for Bash and PowerShell scripts.

**Triggers:**
- Pull requests to main
- Push to main branch

**Test frameworks:**
- **ShellSpec**: BDD testing for Bash scripts
- **Pester v5**: BDD testing for PowerShell scripts

**Coverage:**
- User and server setup scripts
- Security validation functions
- YAML parsing functions
- Cross-platform compatibility

### Maintenance

#### `update-nixpkgs.yml` - Automated Dependency Updates
Automatically updates the nixpkgs flake input.

**Triggers:**
- Weekly schedule (configurable)
- Manual trigger

**What it does:**
- Updates `infra/flake.lock`
- Creates PR with changelog
- Triggers security scans on the PR

### Code Review

#### `claude-code-review.yml` - AI Code Review
Uses Claude to review pull requests.

**Triggers:**
- Pull request opened/updated
- Manual trigger

#### `claude.yml` - Claude Integration
General Claude Code integration for various automated tasks.

## Setting Up Claude Code Automation

To use the `claude-security-fix.yml` workflow, you need to configure authentication:

### 1. Get a Claude Code OAuth Token

1. Install the Claude CLI locally: `npm install -g @anthropic/claude-cli`
2. Run `claude login` and follow the instructions
3. Once logged in, you can find your token in the Claude configuration file (usually `~/.claude/config.json`) or by running `claude auth token` (if available).
4. Alternatively, if the repository has the Claude Code GitHub App installed, follow the app-specific instructions for obtaining a token.

### 2. Add Secret to GitHub Repository

1. Go to your repository on GitHub
2. Navigate to: **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `CLAUDE_CODE_OAUTH_TOKEN`
5. Value: Paste your Claude Code OAuth token
6. Click **Add secret**

### 3. Test the Workflow

**Option 1: Manual trigger**
1. Go to **Actions** tab
2. Select **Claude Security Fix** workflow
3. Click **Run workflow**
4. Monitor the run for any issues

**Option 2: Wait for scheduled run**
- The workflow runs automatically every Monday at 9am UTC
- Check the **Actions** tab for results

### 4. Review Generated PRs

When Claude finds security issues to fix:
1. A PR will be automatically created
2. Review the changes carefully
3. Verify tests pass
4. Merge if changes look good
5. Security scans will re-run on main after merge

### 5. Cost Estimation

The Claude Security Fix workflow uses the Anthropic API, which incurs costs:

**Per-run cost estimate:** $0.15 - $0.50
- Simple nixpkgs bump: ~$0.15
- Complex overlay patches: ~$0.30-$0.50
- Depends on: number of security alerts, conversation length, model used

**Monthly cost estimate (default schedule):**
- Weekly runs: 4 runs/month
- Estimated: $0.60 - $2.00/month
- Plus on-demand manual triggers

**Cost optimization tips:**
1. Use `claude-sonnet` (default) for routine fixes
2. Use `claude-opus` only for complex security issues
3. Monitor workflow runs to avoid unnecessary triggers
4. Set concurrency limits (already configured)
5. Review API usage in Anthropic Console

**Model pricing (as of 2025):**
- Claude Sonnet: ~$3/MTok input, ~$15/MTok output
- Claude Opus: ~$15/MTok input, ~$75/MTok output
- Typical /security-fix run: 50-150k tokens total

**To monitor costs:**
- Check Anthropic Console: https://console.anthropic.com/settings/usage
- Review workflow artifacts for token usage
- Set up budget alerts in Anthropic Console

## Workflow Dependencies

```
Build Containers (main)
    ↓
Security Scan
    ↓
Claude Security Fix
    ↓
    Creates PR
    ↓
Test (on PR)
    ↓
Security Scan (on PR)
```

## Local Development

### Running Security Scans Locally

```bash
# Install Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate-systems.com/nix | sh -s -- install

# Build a container image
cd infra
nix build .#laingville-devcontainer

# Scan with Trivy
docker load < result
trivy image <image-name>:latest
```

### Running Claude /security-fix Locally

```bash
# Install Claude CLI
npm install -g @anthropic/claude-cli

# Set API key
export ANTHROPIC_API_KEY="your-key-here"

# Run the command
claude -p "/security-fix"
```

### Running Tests Locally

```bash
# Bash tests
shellspec

# PowerShell tests (Windows)
Invoke-Pester

# PowerShell tests (WSL)
pwsh.exe -NoProfile -Command "Invoke-Pester -Path ./spec/powershell"
```

## Troubleshooting

### Claude Security Fix Issues

**Problem:** Workflow fails at "Validate secrets" step
- **Cause:** `CLAUDE_CODE_OAUTH_TOKEN` not configured
- **Solution:** Follow [setup guide](#setting-up-claude-code-automation)

**Problem:** Claude makes no changes
- **Possible reasons:**
  - No actionable security issues found
  - Existing patches are sufficient
  - Issues require manual intervention
- **Action:** Check workflow logs for Claude's analysis

**Problem:** PR creation fails
- **Cause:** Insufficient permissions
- **Solution:** Verify workflow has `contents: write` and `pull-requests: write`

### Security Scan Issues

**Problem:** SARIF upload fails
- **Cause:** Missing `security-events: write` permission
- **Solution:** Already configured in workflow

**Problem:** Image not found in registry
- **Cause:** `Build Containers` hasn't run yet or failed
- **Solution:** Check previous workflow runs

## Best Practices

1. **Review automated PRs carefully** - Don't blindly merge Claude's changes
2. **Test locally when possible** - Especially for complex security fixes
3. **Keep workflows updated** - GitHub Actions versions, scanner tools
4. **Monitor API usage** - Claude API calls count toward your usage
5. **Use branch protection** - Require reviews even for automated PRs
6. **Check security tab regularly** - Don't rely solely on automation

## Related Documentation

- [Security Fix Playbook](../.claude/commands/security-fix.md)
- [Container Infrastructure](../infra/README.md)
- [Testing Guide](../CLAUDE.md#testing)
- [Claude CLI Docs](https://code.claude.com/docs)
