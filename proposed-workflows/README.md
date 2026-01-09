# Proposed Workflows

This directory contains workflow files that implement Option A from Issue #15 with consolidated container lifecycle management.

## Why are these files here?

GitHub Apps (like the Claude Code bot) don't have permission to modify files in `.github/workflows/` directly. These files need to be manually moved by a repository maintainer.

## Installation Instructions

To activate the consolidated container lifecycle workflow:

```bash
# Move the workflow file to the correct location
mv proposed-workflows/container-lifecycle.yml .github/workflows/

# Move the documentation (optional but recommended)
mv proposed-workflows/CONTAINER_TESTING.md .github/workflows/

# Remove the old build-containers.yml (now superseded)
git rm .github/workflows/build-containers.yml

# Clean up this directory
rm -rf proposed-workflows/

# Commit the changes
git add .github/workflows/
git commit -m "feat(ci): consolidate container lifecycle into single workflow"
git push
```

## What These Files Do

### container-lifecycle.yml
A unified GitHub Actions workflow that:
- **On PRs**: Validates container environments before merge
  - Triggers when container-related files change
  - Builds all container images using Nix
  - Runs environment validation tests
  - Posts results to PR comments
  - Blocks merge if tests fail
- **On main branch**: Builds, tests, and publishes containers
  - Same build and test steps as PRs (guaranteed consistency)
  - Additionally tags images with date, SHA, and 'latest'
  - Publishes to ghcr.io registry

**Key benefits**:
- ~70% reduction in duplicate code vs. separate workflows
- PRs test exactly what will be published
- Single source of truth for build/test logic
- Easier maintenance

### CONTAINER_TESTING.md
Documentation explaining:
- How the consolidated workflow works
- What tests are run for each container type
- Performance optimizations
- Benefits and trade-offs

### Alternative: test-containers.yml (deprecated)
The original PR-only testing workflow is also included for reference, but `container-lifecycle.yml` is the recommended approach as it consolidates both testing and publishing into a single workflow.

## Testing the Workflow

Once activated, the workflow will run automatically:

**On PRs** that modify:
- `infra/flake.nix`
- `infra/flake.lock`
- `infra/overlays/**`
- `infra/tests/**`

**On pushes to main** that modify:
- `infra/flake.nix`
- `infra/flake.lock`
- `infra/overlays/**`

You can also test it manually via workflow_dispatch.

## Verification

After activation, verify the workflow is working:

1. **Check it appears in Actions tab**: Visit `https://github.com/mrdavidlaing/laingville/actions`
2. **Create a test PR**: Modify a file in `infra/overlays/` and create a PR
3. **Verify PR checks**: Should see "Container Lifecycle" check running
4. **Check for PR comment**: Summary comment should appear when complete
5. **Test on main**: Merge the PR and verify images are published to ghcr.io

## Migration Notes

The new `container-lifecycle.yml` workflow **replaces**:
- `build-containers.yml` (was: publish on main)
- `test-containers.yml` (was: test on PRs)

Both workflows' functionality is now consolidated into the single `container-lifecycle.yml` file with conditional steps.

## Related

- Issue #15: Add container environment tests to PR workflow
- PR #17: Implements consolidated container-lifecycle workflow
- Branch: `claude/issue-15-20251210-1414`
