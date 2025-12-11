# Container Environment Testing

This document explains how container environment tests work in this repository.

## Overview

Container lifecycle (build, test, publish) is managed by a single consolidated workflow that adapts based on the trigger event:

- **`container-lifecycle.yml`** - Unified workflow that:
  - Validates containers on PRs (Option A implementation)
  - Builds, tests, and publishes containers on main branch

This consolidation eliminates ~70% code duplication between the previous separate workflows and ensures PRs test exactly what will be published.

## Container Lifecycle Workflow

### Purpose
Single workflow that validates containers before merge and publishes them after merge.

### When it runs

**On Pull Requests** (validation mode):
- Triggers when these paths change:
  - `infra/flake.nix`
  - `infra/flake.lock`
  - `infra/overlays/**`
  - `infra/tests/**`

**On Push to Main** (publish mode):
- Triggers when these paths change:
  - `infra/flake.nix`
  - `infra/flake.lock`
  - `infra/overlays/**`

**Manual Trigger**:
- Via workflow_dispatch for ad-hoc runs

### What it does

**Common steps (both PR and main)**:
1. **Builds** all container images using Nix
2. **Loads** images into Docker
3. **Runs** environment validation tests

**Additional steps on main branch only**:
4. **Tags** images with date, SHA, and 'latest'
5. **Publishes** to ghcr.io registry

### What it tests
- Node.js containers: npm/npx versions, glob CVE-2025-64756, ES modules, native compilation
- Python containers: Basic validation (tests TBD)
- Base containers: Shell availability

### Performance optimizations
- Uses Nix caching (magic-nix-cache-action) to speed up builds
- Runs container builds in parallel (matrix strategy)
- Only triggers on relevant file changes (path filtering)
- Single workflow reduces maintenance overhead

### Blocking behavior

**On PRs**:
- Failed tests mark PR checks as failed
- Summary comment added to PR
- Prevents merge (if branch protection requires passing checks)

**On main branch**:
- Failed tests prevent image publishing
- Build artifacts are not pushed to registry

## Test Scripts

### test-node-environment.sh
Validates Node.js/npm environment:
- Node.js version (22.x LTS)
- npm version (11.x with glob CVE fix)
- npm package installation
- ES Modules support
- Native module compilation (node-gyp)
- Security: glob version check for CVE-2025-64756

### test-python-environment.sh
Python environment tests (TODO - not yet implemented)

### run-container-tests.sh
Local test runner for manual validation:
```bash
# Test all containers
./infra/tests/run-container-tests.sh

# Test only Node.js containers
./infra/tests/run-container-tests.sh node

# Test only Python containers
./infra/tests/run-container-tests.sh python
```

## Related Issues

- Issue #15: Add container environment tests to PR workflow
- PR #14: Initial container environment tests implementation
- PR #17: Implements consolidated container-lifecycle workflow

## Benefits of Consolidated Workflow

✅ **Early feedback** - Catch issues during PR review, not after merge
✅ **DRY principle** - Single source of truth for build/test logic (~70% reduction in duplicate code)
✅ **Guaranteed consistency** - PRs test exactly what will be published to main
✅ **Easier maintenance** - Changes only need to be made in one place
✅ **Fast iteration** - Contributors can fix issues before merge
✅ **Prevent breakage** - Broken containers won't reach main branch
✅ **Reasonable CI time** - Nix caching keeps builds fast
✅ **Path filtering** - Only runs when container files change

## Trade-offs

⚠️ **CI resource usage** - Builds containers on every relevant PR
⚠️ **Build time** - First build may be slow (subsequent builds cached)
⚠️ **Matrix builds** - Tests all 5 containers in parallel
⚠️ **Slightly more complex conditionals** - Workflow uses `if: github.event_name == 'push'` checks
  - This is a minor trade-off that's well worth the consolidation benefits

## Monitoring

Check workflow status:
- PR checks show container test results
- Failed tests include detailed logs
- Summary comments posted to PRs automatically
