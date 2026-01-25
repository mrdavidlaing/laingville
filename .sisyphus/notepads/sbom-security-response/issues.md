
# Claude Security Fix Workflow Failures - Investigation & Resolution

## Date: 2026-01-25

## Problem
The `.github/workflows/claude-security-fix.yml` workflow had 21+ consecutive failures since 2026-01-24 23:00:11Z. All runs showed `event: push` and `conclusion: failure` with 0 jobs created.

## Root Causes Identified

### Issue 1: Inconsistent YAML Indentation
- **Location**: Lines 45-106 (first 10 steps)
- **Problem**: Steps used 7-space indentation instead of 6-space
- **Error**: `yaml: line 37: did not find expected key`
- **Fix**: Changed indentation from 7 spaces to 6 spaces for consistency

### Issue 2: Invalid GitHub Actions Expression Syntax
- **Location**: Line 92
- **Problem**: Used double quotes inside `${{ }}` expression
- **Original**: `${{ inputs.model || "claude-sonnet-4-5-20250929" }}`
- **Error**: `Unexpected symbol: '"claude-sonnet-4-5-20250929"'`
- **Fix**: Changed to single quotes: `${{ inputs.model || 'claude-sonnet-4-5-20250929' }}`

## Why 0 Jobs Were Created
When GitHub Actions fails to parse a workflow YAML file, it:
1. Creates a workflow run record (shows in `gh run list`)
2. Marks it as `failure` immediately
3. Creates 0 jobs (no jobs can be created from invalid YAML)
4. Shows `event: push` because the workflow file was modified by a push

This is different from a job failure - it's a workflow parsing failure.

## Commits
1. `0c23a69` - fix(workflows): fix YAML indentation in claude-security-fix.yml
2. `6bf460f` - fix(workflows): fix GitHub Actions expression syntax in claude-security-fix.yml

## Verification
- Manually triggered workflow with `gh workflow run claude-security-fix.yml`
- Workflow started successfully (no parsing error)
- All setup steps completed: Set up job, Validate secrets, Checkout, Install Nix, Setup Nix cache, Configure git, Create feature branch
- Claude /security-fix step running

## Key Learnings

### Debugging GitHub Actions Workflow Failures
1. **0 jobs = YAML parsing failure** - Check workflow syntax
2. **Use `gh workflow run` to test** - It gives immediate parsing error feedback
3. **Local YAML validation isn't enough** - GitHub Actions has stricter expression parsing
4. **Expression syntax**: Use single quotes for string literals in `${{ }}`

### YAML Indentation in GitHub Actions
- Steps should use consistent indentation (typically 6 spaces under `steps:`)
- Mixed indentation causes parsing failures
- Use `yq eval '.' file.yml` to validate YAML locally

### GitHub Actions Expression Syntax
- String literals must use single quotes: `'value'`
- Double quotes are NOT valid in expressions
- Example: `${{ inputs.var || 'default' }}` ✓
- Example: `${{ inputs.var || "default" }}` ✗

---

## Session 2: 2026-01-25 (Continuation) - Additional Fixes & Verification

### Issue 3: Cosign Installer Version Not Available (FIXED)
- **Location**: `.github/workflows/build-containers.yml` lines 51, 160
- **Problem**: Workflow used `sigstore/cosign-installer@v4` which doesn't exist
- **Available Versions**: Latest is v3.10.1
- **Error**: `Unable to resolve action sigstore/cosign-installer@v4`
- **Fix**: Updated both occurrences to `sigstore/cosign-installer@v3`
- **Commit**: `d5f811a` - fix(workflows): update cosign-installer from v4 to v3

### Current Workflow Status (2026-01-25 12:34 UTC)

| Workflow | Run # | Status | Notes |
|----------|-------|--------|-------|
| Build Containers | 63 | Queued | Cosign v3 fix applied |
| Security Scan | 139 | Queued | Should pass (previous runs passing) |
| Claude Security Fix | 147 | Pending | YAML fixes applied, awaiting execution |
| Claude Security Fix | 145 | In Progress | Running with fixes |

### ⚠️ GitHub Advanced Security Configuration Issue

**Problem**: Cannot enable Advanced Security settings via GitHub API
- Endpoints return 404 Not Found
- Affected endpoints:
  - `/repos/{owner}/{repo}/vulnerability-alerts`
  - `/repos/{owner}/{repo}/automated-security-fixes`

**What Needs Manual Configuration**:
1. Go to GitHub Settings → Advanced Security
2. Enable "Code scanning" (if not already enabled)
3. Enable "Secret scanning" (if not already enabled)
4. Enable "Automatic dependency submission" (CRITICAL for SBOM system)
5. Enable "Dependabot alerts" (if not already enabled)

**Current Status**:
- Code scanning alerts: ✅ PRESENT (11 vulnerabilities detected)
- Dependabot alerts: ❌ EMPTY (no alerts yet)
- Dependabot configuration: ✅ EXISTS (.github/dependabot.yml)

**Why This Matters**:
- Container SBOMs are submitted to Dependency Graph via `dependency-snapshot: true`
- Dependabot monitors the Dependency Graph for vulnerabilities
- Without automatic dependency submission enabled, container packages won't appear in Dependency Graph
- Without Dependabot alerts enabled, vulnerabilities won't be detected

### Next Steps

1. **Monitor Workflow Runs** (Next 10 minutes)
   - Watch runs #63, #139, #147 for completion
   - Verify all pass successfully

2. **Enable Advanced Security** (Manual, GitHub UI)
   - Settings → Advanced Security
   - Enable "Automatic dependency submission"
   - Enable "Dependabot alerts"

3. **Verify End-to-End Pipeline** (After workflows complete)
   - Check if security-response workflow triggers
   - Verify Claude /security-fix creates PR for HIGH/CRITICAL alerts
   - Test with real vulnerability

4. **Monitor Dependabot** (After 24 hours)
   - Wait for GitHub to process configuration
   - Verify Dependabot alerts appear for container packages

---

## Session 3: 2026-01-25 12:40 UTC - Build Containers Workflow Fix

### Issue 4: syft CLI Not Installed (FIXED)

- **Location**: `.github/workflows/build-containers.yml` lines 86-93, 203-212
- **Problem**: Workflow called `syft` CLI directly but never installed it
- **Error**: `syft: command not found` (exit code 127)
- **Affected Runs**: #46-63 (all failed after SBOM feature was added)
- **Last Successful Run**: #45 (before SBOM feature was added)

### Root Cause Analysis

1. **Commit `b3d8bc7`** (2026-01-25) added SBOM generation using `syft` CLI
2. The commit assumed `syft` would be available on GitHub runners
3. GitHub runners do NOT have `syft` pre-installed
4. The `security-scan.yml` workflow works because it uses `anchore/sbom-action@v0` which includes syft

### Fix Applied

Replaced direct `syft` CLI calls with `anchore/sbom-action@v0`:

**Before (broken):**
```yaml
- name: Generate SBOM for arch-specific image
  run: |
    syft "$ARCH_TAG" -o spdx-json > sbom.spdx.json
```

**After (fixed):**
```yaml
- name: Generate SBOM for arch-specific image
  uses: anchore/sbom-action@v0
  with:
    image: '${{ env.REGISTRY }}/...'
    format: spdx-json
    output-file: 'sbom.spdx.json'
```

### Changes Made

1. **build-images job**: Replaced `syft` CLI with `anchore/sbom-action@v0`
2. **create-manifests job**: Added separate SBOM generation step using `anchore/sbom-action@v0`
3. **Attestation step**: Updated to use hardcoded filename instead of step output

### Commit

- `20423d1` - fix(workflows): use anchore/sbom-action instead of syft CLI

### Verification

- Workflow run #21332749508 triggered (queued)
- YAML syntax validated with Ruby YAML parser
- All tests pass (541 examples, 0 failures)

### Key Learnings

1. **Don't assume CLI tools are available** - GitHub runners have limited pre-installed tools
2. **Use GitHub Actions when available** - Actions handle installation and caching
3. **Check working workflows for patterns** - `security-scan.yml` already solved this problem
4. **Test locally is insufficient** - Need to verify tools exist in CI environment

