# Proposed Workflows

This directory contains workflow files that implement Option A from Issue #15.

## Why are these files here?

GitHub Apps (like the Claude Code bot) don't have permission to modify files in `.github/workflows/` directly. These files need to be manually moved by a repository maintainer.

## Installation Instructions

To activate the container testing workflow for PRs:

```bash
# Move the workflow file to the correct location
mv proposed-workflows/test-containers.yml .github/workflows/

# Move the documentation (optional but recommended)
mv proposed-workflows/CONTAINER_TESTING.md .github/workflows/

# Clean up this directory
rm -rf proposed-workflows/

# Commit the changes
git add .github/workflows/test-containers.yml .github/workflows/CONTAINER_TESTING.md
git commit -m "feat(ci): activate container environment tests for PRs"
git push
```

## What These Files Do

### test-containers.yml
A GitHub Actions workflow that:
- Triggers on PRs when container-related files change
- Builds all container images using Nix
- Runs environment validation tests
- Posts results to PR comments
- Blocks merge if tests fail

### CONTAINER_TESTING.md
Documentation explaining:
- How the PR testing workflow works
- What tests are run
- Performance optimizations
- Trade-offs and benefits

## Testing the Workflow

Once activated, the workflow will run automatically on PRs that modify:
- `infra/flake.nix`
- `infra/flake.lock`
- `infra/overlays/**`
- `infra/tests/**`

You can also test it manually by creating a PR with changes to any of these paths.

## Related

- Issue #15: Add container environment tests to PR workflow
- Branch: `claude/issue-15-20251210-1414`
