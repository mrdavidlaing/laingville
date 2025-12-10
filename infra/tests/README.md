# Container Environment Tests

This directory contains test scripts for validating container environments built from the Nix flakes.

## Test Scripts

### Individual Environment Tests

- **`test-node-environment.sh`** - Tests Node.js/npm environment
  - Verifies Node.js and npm are installed
  - Checks version numbers
  - Tests npm package installation
  - Validates npx availability

- **`test-python-environment.sh`** - Tests Python/pip environment
  - Verifies Python and pip are installed
  - Checks version numbers
  - Tests pip package installation
  - Validates Python execution

### Test Runner

- **`run-container-tests.sh`** - Orchestrates tests across multiple containers
  - Pulls container images from registry
  - Mounts test scripts into containers
  - Executes appropriate tests for each container
  - Generates summary report

## Usage

### Testing a Single Container Locally

```bash
# Build container with Nix
nix build ./infra#example-node-devcontainer

# Load into Docker
docker load < result

# Run tests
docker run --rm -v $(pwd)/infra/tests/test-node-environment.sh:/tmp/test.sh:ro \
  example-node-devcontainer:latest bash /tmp/test.sh
```

### Testing Multiple Containers

```bash
# Test all Node.js containers from registry
./infra/tests/run-container-tests.sh \
  example-node-devcontainer \
  example-node-runtime

# Test locally built images
./infra/tests/run-container-tests.sh -l example-node-devcontainer

# Test with specific tag
./infra/tests/run-container-tests.sh -t 2025-12-10 example-node-devcontainer
```

## CI Integration

### PR Workflow (Option A)

The test scripts are designed to run in GitHub Actions on pull requests that modify container-related files:

```yaml
on:
  pull_request:
    paths:
      - 'infra/flake.nix'
      - 'infra/flake.lock'
      - 'infra/overlays/**'
      - 'infra/tests/**'
```

This provides fast feedback during PR review before changes are merged to main.

### Build Workflow

Tests also run in the `build-containers.yml` workflow after building but before pushing images:

1. Build container with Nix
2. Load into Docker
3. Run environment tests
4. Push to registry (only if tests pass)

This gates the publishing of broken container images.

## Adding New Tests

To add tests for a new environment:

1. Create a test script (e.g., `test-rust-environment.sh`)
2. Follow the pattern from existing scripts:
   - Use colored output for readability
   - Track test counts (run/passed/failed)
   - Provide detailed failure messages
   - Exit with non-zero on failure
3. Update `run-container-tests.sh` to map image names to test scripts
4. Add the new script to `.github/workflows/test-containers-pr.yml` and `build-containers.yml`

## Test Philosophy

- **Fast feedback** - Tests should complete quickly (< 1 minute per container)
- **Comprehensive** - Cover critical functionality (installation, execution, package management)
- **Actionable** - Clear failure messages that guide fixes
- **Maintainable** - Simple bash scripts without heavy dependencies
