# Container Environment Testing

This document explains how container environment tests work in this repository.

## Overview

Container environment validation tests run in two workflows:

1. **`test-containers.yml`** - Runs on PRs (Option A implementation)
2. **`build-containers.yml`** - Runs on main branch after merge

## PR Testing Workflow (test-containers.yml)

### Purpose
Validates container environments **before** merge to catch issues early in the development cycle.

### When it runs
Triggers on pull requests when these paths change:
- `infra/flake.nix`
- `infra/flake.lock`
- `infra/overlays/**`
- `infra/tests/**`

### What it does
1. **Builds** all container images using Nix
2. **Loads** images into Docker
3. **Runs** environment validation tests
4. **Reports** results in PR comments

### What it tests
- Node.js containers: npm/npx versions, glob CVE-2025-64756, ES modules, native compilation
- Python containers: Basic validation (tests TBD)
- Base containers: Shell availability

### Performance optimizations
- Uses Nix caching (magic-nix-cache-action) to speed up builds
- Runs container builds in parallel (matrix strategy)
- Only triggers on relevant file changes (path filtering)

### Blocking behavior
Failed tests will:
- Mark the PR checks as failed
- Add a comment to the PR explaining the failure
- Prevent merge (if branch protection requires passing checks)

## Build Workflow (build-containers.yml)

### Purpose
Builds, tests, and **publishes** container images to the registry after merge to main.

### When it runs
- On push to main branch (for paths affecting containers)
- Manual trigger via workflow_dispatch

### What it does
1. **Builds** container images using Nix
2. **Runs** environment validation tests (gates publishing)
3. **Tags** images with date, SHA, and 'latest'
4. **Pushes** images to ghcr.io registry

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

## Benefits of Option A (PR Testing)

✅ **Early feedback** - Catch issues during PR review, not after merge
✅ **Fast iteration** - Contributors can fix issues before merge
✅ **Prevent breakage** - Broken containers won't reach main branch
✅ **Reasonable CI time** - Nix caching keeps builds fast
✅ **Path filtering** - Only runs when container files change

## Trade-offs

⚠️ **CI resource usage** - Builds containers on every relevant PR
⚠️ **Build time** - First build may be slow (subsequent builds cached)
⚠️ **Matrix builds** - Tests all 5 containers in parallel

## Monitoring

Check workflow status:
- PR checks show container test results
- Failed tests include detailed logs
- Summary comments posted to PRs automatically
