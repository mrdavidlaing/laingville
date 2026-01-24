# Plan: Add OpenCode + Claude to Nix Pensive-Assistant Feature

## Context

### Original Request
Update the Nix-based pensive-assistant feature to include the same 6 tools as the Ubuntu version, with NO runtime installation (true secure mode).

### What's ALREADY Implemented (No Changes Needed)

The Nix pensive-assistant feature infrastructure is **95% complete**:

1. **Build Infrastructure** ✅
   - `.devcontainer/features/pensive-assistant/flake.nix` - defines tool packages
   - `.devcontainer/features/pensive-assistant/build-delta-tarball.sh` - delta tarball builder
   - `.github/workflows/publish-pensive-assistant.yml` - CI/CD pipeline
   - `just pensive-assistant-build` - local build command
   - Multi-arch support (amd64 + arm64)
   - OCI registry publishing to `ghcr.io/mrdavidlaing/laingville/pensive-assistant-tarball`

2. **Installation Flow** ✅
   - `install.sh` with mode detection (`nix` vs `ubuntu`)
   - Tarball extraction to `/nix/store`
   - PATH setup via `/etc/profile.d/pensive-assistant.sh`
   - User symlinks to `~/.local/bin`
   - Security validation (only `/nix/store` paths allowed)

3. **Tools Already in Nix Tarball** ✅
   - `beads` (bd) - via flake input from `github:steveyegge/beads`
   - `zellij` - from nixpkgs
   - `lazygit` - from nixpkgs

4. **Tools in Base Image** ✅
   - `bun` - already in `infra/flake.nix` packageSets.nodeDev

### The Gap (What This Plan Addresses)

**Missing from Nix tarball:**
- ❌ `opencode` (OpenCode AI CLI) - currently NOT installed at all in Nix mode
- ❌ `claude` (Claude Code CLI) - installed via `bun install -g` at RUNTIME (violates secure mode)

**Current install.sh lines 124-132:**
```bash
# Install Claude Code via bun
echo "Installing Claude Code..."
if command -v bun > /dev/null 2>&1; then
  bun install -g @anthropic-ai/claude-code
  echo "Claude Code installed via bun"
else
  echo "Warning: bun not found, skipping Claude Code installation"
fi
```

This runtime installation:
- Requires network access during container startup
- Breaks the "secure mode" philosophy (no external fetches)
- Makes builds non-reproducible

---

## Work Objectives

### Core Objective
Add `opencode` and `claude` to the Nix pensive-assistant tarball so they're pre-built and extracted like the other tools (no runtime installation).

### Concrete Deliverables
1. Updated `.devcontainer/features/pensive-assistant/flake.nix` with opencode + claude derivations
2. Updated `install.sh` to remove runtime bun installation (tools come from tarball)
3. Updated test.sh to verify all 6 tools

### Definition of Done
- `just pensive-assistant-build` produces tarball containing 5 tools: `bd`, `zellij`, `lazygit`, `opencode`, `claude`
- `install.sh` extracts tarball with NO npm/bun install calls (oras pull from GHCR is acceptable)
- All 6 tools available in container:
  - From tarball: `bd`, `zellij`, `lazygit`, `opencode`, `claude`
  - From base image: `bun`

### Must Have
- Tools pinned via:
  - `flake.lock` for nixpkgs and flake inputs (beads)
  - `fetchurl` hashes in `flake.nix` for npm tarballs (opencode, claude)
- No runtime `bun install` or other network fetches (tarball contains all binaries)
- Works on both amd64 and arm64

### Must NOT Have (Guardrails)
- No changes to base devcontainer (`infra/flake.nix`)
- No changes to build-delta-tarball.sh (it already works)
- No Ubuntu mode changes (already complete)

**Note:** CI workflow changes ARE in scope (adding test step to publish-pensive-assistant.yml)

---

## Clarification: "Secure Mode" Network Behavior

**Current behavior in install.sh:**
1. If `dist/pensive-tools.tar.gz` exists locally → extract directly (NO network)
2. If tarball missing → download `oras` tool, then `oras pull` from GHCR (REQUIRES network)

**This is the expected design:**
- **CI builds** produce the tarball and publish to GHCR
- **Local dev** can pre-populate `dist/` via `just pensive-assistant-build` (no network at install time)
- **Fresh container pull** will fetch tarball from GHCR (one-time network, cached thereafter)

**What "secure mode" means here:**
- All tool BINARIES come from the pre-built tarball (reproducible, pinned)
- NO runtime compilation or `npm install` during container startup
- The tarball fetch from GHCR is acceptable (same as pulling a Docker image)

**What this plan eliminates:**
- The current `bun install -g @anthropic-ai/claude-code` runtime call (lines 124-132)
- This call happens EVERY container startup and fetches from npm registry
- After this plan: claude/opencode binaries are IN the tarball, no npm fetch needed

---

## Verification Strategy

### Test Infrastructure
- `.devcontainer/features/pensive-assistant/test.sh` - exists but NOT currently run by CI
- This plan adds CI integration (see TODO 4b)

### Manual Verification
```bash
# Build locally
just pensive-assistant-build

# Inspect tarball contents
tar -tzf .devcontainer/features/pensive-assistant/dist/pensive-tools.tar.gz | grep -E "opencode|claude"

# Test in container
just dev-up
just dev-shell
bd --version
zellij --version
lazygit --version
bun --version
opencode --version
claude --version
```

### CI Verification
- Currently: workflow does NOT run test.sh (gap identified)
- This plan: adds test step to workflow (TODO 4b)

---

## TODOs

### 1. Research: Package structure and Nix feasibility
**What to do:**

**Step 1a: Check nixpkgs availability**
```bash
nix search nixpkgs opencode
nix search nixpkgs claude-code
# Expected: not found (requires custom derivations)
```

**Step 1b: Analyze npm package structure**

**Environment:** Run these commands on HOST with Node.js/npm installed (or in laingville devcontainer)

```bash
# Download and inspect opencode-ai
npm pack opencode-ai@1.1.34
tar -tzf opencode-ai-1.1.34.tgz > /tmp/opencode-contents.txt

# Check for:
grep -E "package-lock|npm-shrinkwrap" /tmp/opencode-contents.txt  # Lockfile?
grep -E "binding\.gyp|\.node$" /tmp/opencode-contents.txt         # Native deps?
tar -xzf opencode-ai-1.1.34.tgz && grep "postinstall" package/package.json  # Postinstall scripts?

# Same for claude-code
npm pack @anthropic-ai/claude-code@2.1.19
tar -tzf anthropic-ai-claude-code-2.1.19.tgz > /tmp/claude-contents.txt
```

**Step 1c: Check bin field mappings**
```bash
npm view opencode-ai@1.1.34 bin
# Expected: { opencode: './bin/opencode.js' } or similar

npm view @anthropic-ai/claude-code@2.1.19 bin
# Expected: { claude: '...' }
```

**Known risks (from npm metadata analysis):**
1. **opencode-ai postinstall:** Has `postinstall = "bun ./postinstall.mjs || node ./postinstall.mjs"`
   - May try to download platform-specific binaries
   - Nix sandbox blocks network; may need `dontNpmInstall` or patch
2. **opencode-ai no lockfile:** `_hasShrinkwrap: false` suggests no package-lock.json
   - Will need `fetchNpmDeps` approach or generate lockfile
3. **claude-code optional deps:** Has `@img/sharp-*` optional dependencies (~71MB unpacked)
   - These are prebuilt native binaries for image processing
   - May need to exclude or handle specifically

**Parallelizable:** YES (independent research)

**Acceptance Criteria:**
- Document findings in plan or notepad:
  - Lockfile present in npm tarball? (yes/no)
  - Postinstall script behavior? (none/safe/network-required)
  - Native dependencies? (none/list)
  - Binary name and path from `bin` field
  - **If postinstall downloads binaries:**
    - URLs for x86_64-linux binary
    - URLs for aarch64-linux binary
    - Target path where CLI expects binary
    - SHA256 hashes for both binaries
- Make explicit decision: `buildNpmPackage` vs `stdenv.mkDerivation`
- If lockfile missing: Create `infra/overlays/{package}/` with generated lockfile
- Record decision in `flake.nix` comments (above each derivation)

**Decision tree (follow in order):**

**CRITICAL: Nix sandbox blocks network during build. ALL lockfile/deps must be pre-generated.**

1. **IF** `package-lock.json` exists in tarball **AND** no problematic postinstall:
   → Use `buildNpmPackage` with `sourceRoot = "package"` and `npmDepsHash`
   
2. **IF** lockfile missing (likely for opencode-ai):
   → **Generate lockfile OUTSIDE Nix, commit to repo**
   → Pattern: Create `infra/overlays/opencode-ai/` with:
     - `package.json` (copied from npm tarball, needed for fetchNpmDeps)
     - `package-lock.json` (generated via `npm install --package-lock-only` on host)
     - `package.nix` (derivation using `buildNpmPackage`)
   → Reference: See `infra/overlays/pyright-patched/` for existing pattern
   → In derivation: `src = fetchurl { npm tarball }; postPatch = copy lockfile;`
   → See detailed workflow below (step-by-step)
   
3. **IF** postinstall requires network (fails in sandbox):
   → Add `npmInstallFlags = [ "--ignore-scripts" ]`
   → **THEN** verify `opencode --version` works; if broken, see postinstall fallback below
   
4. **IF** optional deps (sharp) cause issues:
   → Add `npmInstallFlags = [ "--omit=optional" ]`
   → Verify core CLI functionality works without image processing

**CRITICAL: Use `npmInstallFlags` consistently:**
- `npmInstallFlags` = flags for `npm ci` / `npm install` during build (what we need)

**Attribute names for nixpkgs 24.05+ (verify in your pinned version):**
- `npmInstallFlags` - flags passed to `npm ci` / `npm install` during build
- Reference: `pkgs/build-support/node/build-npm-package/default.nix` in nixpkgs

**Note:** There is also `npmFlags` (for `npm pack`), but we don't use it in this plan.

**Postinstall fallback details (if needed for opencode-ai):**

Based on opencode-ai's postinstall behavior (downloads platform-specific language server binaries), if `--ignore-scripts` breaks functionality:

**Step 1: Identify what postinstall downloads (run on host, NOT in Nix):**
```bash
# Extract and run postinstall manually to capture URLs
npm pack opencode-ai@1.1.34
tar -xzf opencode-ai-1.1.34.tgz
cd package
node ./postinstall.mjs 2>&1 | tee /tmp/postinstall-output.txt

# Look for download URLs and target paths
grep -E "https?://" /tmp/postinstall-output.txt
ls -la .cache/ # or wherever binaries are placed
```

**Step 2: Document multi-arch binary URLs and hashes:**

Research must identify URLs for BOTH architectures:
- `x86_64-linux` (amd64)
- `aarch64-linux` (arm64)

Example findings to document:
```
opencode-lsp binaries:
- x86_64-linux: https://github.com/.../opencode-lsp-linux-x64 → sha256-XXXXX
- aarch64-linux: https://github.com/.../opencode-lsp-linux-arm64 → sha256-YYYYY
Target path: $out/lib/node_modules/opencode-ai/.cache/opencode-lsp
```

**Step 3: Pre-fetch binaries per-platform in derivation:**
```nix
opencodeAi = pkgs.buildNpmPackage {
  pname = "opencode-ai";
  version = "1.1.34";
  
  # CRITICAL: Use patched nodejs to avoid CVE scanner findings
  nodejs = pkgs.nodejs_22_patched;
  
  # Source is the REAL npm tarball (contains all package files)
  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/opencode-ai/-/opencode-ai-1.1.34.tgz";
    hash = "sha256-XXXXX";
  };
  
  sourceRoot = "package";
  
  # Platform-specific binary sources
  # Use stdenv.hostPlatform for correct platform detection
  opencodeLsp = pkgs.fetchurl (
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then {
      url = "https://github.com/.../opencode-lsp-linux-x64";
      hash = "sha256-XXXXX";
    } else if pkgs.stdenv.hostPlatform.system == "aarch64-linux" then {
      url = "https://github.com/.../opencode-lsp-linux-arm64";
      hash = "sha256-YYYYY";
    } else throw "Unsupported platform: ${pkgs.stdenv.hostPlatform.system}"
  );
  
  postPatch = ''
    # Copy in committed lockfile from overlay directory
    cp ${./package-lock.json} ./package-lock.json
  '';
  
  npmDepsHash = "sha256-ZZZZZZ";  # Get via fake hash, Nix will tell you real one
  
  npmInstallFlags = [ "--ignore-scripts" ];  # Skip postinstall (we handle it manually)
  
  postInstall = ''
    # Place pre-fetched binary where CLI expects it
    mkdir -p $out/lib/node_modules/opencode-ai/.cache
    cp $opencodeLsp $out/lib/node_modules/opencode-ai/.cache/opencode-lsp
    chmod +x $out/lib/node_modules/opencode-ai/.cache/opencode-lsp
  '';
};
```

**Key insight:** Use `buildNpmPackage` (not `stdenv.mkDerivation`) even for the postinstall fallback. It handles npm dependencies automatically via its hooks.

**Step 4: Verify binary paths match CLI expectations:**
```bash
# After build, verify the package structure
ls -la result/lib/node_modules/
# Expected: opencode-ai/ directory (name matches pname)

# Verify the binary was placed correctly
ls -la result/lib/node_modules/opencode-ai/.cache/
# Expected: opencode-lsp binary

# Test that CLI finds the binary
result/bin/opencode --version
# Should NOT try to download anything

# If opencode --version fails or tries to download:
# 1. Check where the CLI looks for the binary (read the source)
# 2. Adjust the postInstall path to match
# 3. May need to patch the CLI to use a different path
```

**CRITICAL: Research (TODO 1) must determine:**
1. Exact URLs for BOTH x86_64-linux AND aarch64-linux binaries
2. Exact target path where CLI expects the binary (verify by reading opencode source)
3. Whether CLI hardcodes the path or uses env vars (may need patching)
4. **Verification:** After placing binary, `opencode --version` must work without network

---

### 2. Add opencode + claude to flake.nix
**What to do:**
- If in nixpkgs: add `pkgs.opencode` and `pkgs.claude-code` to `pensiveTools` list
- If NOT in nixpkgs (likely): create custom derivations

**Upstream sources:**
- `opencode`: npm package `opencode-ai` → binary name `opencode`
- `claude`: npm package `@anthropic-ai/claude-code` → binary name `claude`

**Nix packaging approach:**

**AUTHORITATIVE IMPLEMENTATION:** Create overlays in `infra/overlays/` for BOTH packages, then import them in the feature flake.

This matches the existing `infra/overlays/pyright-patched/` pattern and keeps all custom derivations in one place.

**The feature flake will import these overlays** (see Step 6 below for the exact import code).

**Runtime node dependency and delta tarball behavior:**
- `buildNpmPackage` derivations reference a specific `nodejs` from nixpkgs
- **IMPORTANT:** This flake uses `nixpkgs.follows = "infra/nixpkgs"` for layer sharing
- If the base image already has the same nodejs derivation, it WON'T be in the delta tarball
- The `build-delta-tarball.sh` script computes: (closure paths) - (base image paths) = delta
- **Verification steps after build:**
  ```bash
  # Check what's actually in the delta tarball
  tar -tzf dist/pensive-tools.tar.gz | wc -l
  
  # Check if node is in delta
  tar -tzf dist/pensive-tools.tar.gz | grep -c "nodejs"
  # Acceptable outcomes:
  #   0 = nodejs shared with base image (ideal, smaller tarball)
  #   >0 = nodejs included in tarball (acceptable, self-contained)
  # NOT a failure condition either way
  
  # Verify the CLI runs after extraction (proves deps are satisfied)
  # This is what test.sh does
  ```

**Handling postinstall scripts:**
- If postinstall tries to fetch binaries, build will fail in Nix sandbox
- Options if this happens:
  1. `npmInstallFlags = [ "--ignore-scripts" ]` - skip postinstall entirely
  2. Patch postinstall.mjs to be a no-op
  3. Pre-fetch required binaries and patch paths
- **Decision point:** Run research (TODO 1) first to determine actual behavior

**Handling optional native dependencies (sharp):**
- claude-code has optional `@img/sharp-*` deps for image processing
- These are platform-specific prebuilt binaries
- Options:
  1. Let them install (increases tarball size but features work)
  2. Exclude with `npmInstallFlags = [ "--omit=optional" ]`
  3. Accept partial functionality if image features not needed
- **Decision point:** Determine if claude actually uses sharp at runtime

**Version Selection Policy:**
- Pin to the SAME versions currently installed by Ubuntu mode
- Ubuntu mode installs "latest" at build time; capture versions via `just ubuntu-test`
- **Current Ubuntu versions (captured 2026-01-24):** opencode 1.1.34, claude 2.1.19
- **Source of truth:** These versions are recorded in this plan AND in the flake.nix comments
- **Future updates workflow:**
  1. Run `just ubuntu-up && just ubuntu-install-feature && just ubuntu-test`
  2. Note the version numbers from output
  3. Update `flake.nix` with new versions and regenerate hashes
  4. Update this plan's "Current Ubuntu versions" line
  5. Commit with message including version bump info

**To obtain hashes (iterative process):**

**Environment:** Run these commands in the `.devcontainer/features/pensive-assistant/` directory, using `nix develop` or host with Nix installed

```bash
cd .devcontainer/features/pensive-assistant

# 1. Get src hash (SRI format for fetchurl)
# nix-prefetch-url outputs base32, but fetchurl expects SRI format (sha256-...)
# Use --type sha256 and convert, OR use nix hash to-sri:
nix-prefetch-url --type sha256 https://registry.npmjs.org/opencode-ai/-/opencode-ai-1.1.34.tgz
# Output example: 0abcdef123... (base32)
# Convert to SRI:
nix hash to-sri --type sha256 0abcdef123...
# Output: sha256-XXXXX (use this for `hash` attribute)

# OR simpler: use nix-prefetch with --print-hash flag:
nix-prefetch-url https://registry.npmjs.org/opencode-ai/-/opencode-ai-1.1.34.tgz 2>/dev/null
# Then manually prefix with "sha256-" and base64 encode if needed

# Simplest approach (matches repo patterns in infra/overlays/nodejs-patched):
# Start with fake hash, let Nix tell you the correct one:
# Use hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; (fake)
# Build will fail with: "got: sha256-REAL_HASH_HERE"

# 2. First build attempt with placeholder hashes
# In flake.nix, use fake hashes:
#   hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
#   npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
nix build .#default 2>&1 | grep -A1 "specified:"
# Error output will show:
#   specified: sha256-AAAAAA...
#   got:       sha256-REAL_HASH
# Copy the "got:" value and replace the fake hash

# 3. Repeat for npmDepsHash (second build attempt)
# First fix src hash, then run again to get npmDepsHash error

# 4. Final build with correct hashes
nix build .#default
# Should succeed

# 5. Verify binaries exist
ls -la result/bin/
# Expected: bd, zellij, lazygit, opencode, claude
```

**Reference:** See `infra/overlays/nodejs-patched/package.nix` for existing repo pattern with `fetchurl` and SRI hashes.

**Native dependencies - verification steps:**
```bash
# Download and inspect package contents BEFORE writing derivation
npm pack opencode-ai@1.1.34
tar -tzf opencode-ai-1.1.34.tgz | grep -E "binding\.gyp|\.node$"
# If no output → pure JS, safe to use buildNpmPackage

npm pack @anthropic-ai/claude-code@2.1.19
tar -tzf anthropic-ai-claude-code-2.1.19.tgz | grep -E "binding\.gyp|\.node$"
# If no output → pure JS
```

**If native deps ARE found:**
```nix
# Add to derivation:
nativeBuildInputs = [ pkgs.python3 pkgs.pkg-config ];
buildInputs = [ pkgs.nodejs ];
```

**Lockfile handling - verification and fallback:**
```bash
# Check if lockfile exists
tar -tzf opencode-ai-1.1.34.tgz | grep package-lock
# Expected: package/package-lock.json
```

**If lockfile is MISSING:**

**CRITICAL: Cannot generate lockfile inside Nix sandbox (network blocked).**

**Required approach: Pre-generate lockfile, commit to repo**

**This workflow applies to BOTH opencode-ai AND claude-code if they're missing lockfiles.**

**Step-by-step workflow (repeat for each package):**

1. **Create overlay directory structure:**
   ```bash
   # For opencode-ai:
   mkdir -p infra/overlays/opencode-ai
   cd infra/overlays/opencode-ai
   
   # For claude-code (if lockfile missing):
   mkdir -p infra/overlays/claude-code
   cd infra/overlays/claude-code
   ```

2. **Extract package.json from npm tarball:**
   ```bash
   # For opencode-ai:
   npm pack opencode-ai@1.1.34
   tar -xzf opencode-ai-1.1.34.tgz package/package.json
   mv package/package.json .
   rm -rf package opencode-ai-1.1.34.tgz
   
   # For claude-code:
   npm pack @anthropic-ai/claude-code@2.1.19
   tar -xzf anthropic-ai-claude-code-2.1.19.tgz package/package.json
   mv package/package.json .
   rm -rf package anthropic-ai-claude-code-2.1.19.tgz
   ```

3. **Generate lockfile (requires network, run on host):**
   ```bash
   npm install --package-lock-only
   # This creates package-lock.json
   ```

4. **Commit BOTH files to repo:**
   ```bash
   git add package.json package-lock.json
   git commit -m "chore: add {package-name} lockfile for Nix packaging"
   ```
   
   **Why commit package.json?**
   - `buildNpmPackage` internally uses `fetchNpmDeps` to pre-fetch dependencies
   - `fetchNpmDeps` requires BOTH `package.json` and `package-lock.json` to compute the hash
   - The derivation still uses the package.json from the npm tarball (via `src = fetchurl`)
   - The committed package.json is ONLY used by `fetchNpmDeps` during the build process
   - Reference: See how `infra/overlays/pyright-patched/` commits lockfiles alongside package.json

5. **Create package.nix derivation (template for BOTH packages):**
   ```nix
   { lib, buildNpmPackage, fetchurl, nodejs_22_patched }:
   
   buildNpmPackage {
     pname = "opencode-ai";  # or "claude-code"
     version = "1.1.34";     # or "2.1.19"
     
     # CRITICAL: Use patched nodejs to avoid CVE scanner findings
     # This repo uses nodejs_22_patched (see infra/overlays/nodejs-patched/)
     nodejs = nodejs_22_patched;
     
     # Source is the REAL npm tarball (contains all package files)
     src = fetchurl {
       url = "https://registry.npmjs.org/opencode-ai/-/opencode-ai-1.1.34.tgz";
       # For claude-code: "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-2.1.19.tgz"
       hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
     };
     
     # npm tarballs unpack to "package/" directory
     sourceRoot = "package";
     
     # Copy in the committed lockfile during postPatch
     postPatch = ''
       cp ${./package-lock.json} ./package-lock.json
     '';
     
     npmDepsHash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
     # ^ Use fake hash first, Nix will tell you the real one
     
     npmInstallFlags = [ "--ignore-scripts" ];
     # ^ Skip postinstall (handle separately if needed)
     
     # For claude-code, may also need:
     # npmInstallFlags = [ "--ignore-scripts" "--omit=optional" ];
     # ^ To skip sharp optional dependencies
     
     meta = {
       description = "OpenCode AI CLI";  # or "Claude Code CLI"
       homepage = "https://github.com/anthropics/opencode";  # or appropriate URL
       license = lib.licenses.mit;
     };
   }
   ```
   
   **Key insight:** `src` is the real package source (fetchurl), and we inject the committed lockfile via `postPatch`. This is the same pattern as `infra/overlays/pyright-patched/package.nix`.

6. **Update flake.nix to import the overlay packages:**
   
   The feature flake needs to import the overlay packages we created.
   
   **Step 6a:** Update the `outputs` function signature to include `infra`:
   ```nix
   outputs = { self, nixpkgs, beads, infra, ... }:
   ```
   
   **Step 6b:** Import nixpkgs WITH overlays and import the overlay packages:
   ```nix
   let
     # Import nixpkgs with infra overlays to get nodejs_22_patched
     pkgs = import nixpkgs {
       inherit system;
       overlays = [ (import "${infra}/overlays") ];
     };
     
     # Import overlay packages from infra (available in CI)
     opencodeAi = pkgs.callPackage "${infra}/overlays/opencode-ai/package.nix" { };
     claudeCode = pkgs.callPackage "${infra}/overlays/claude-code/package.nix" { };
     
     pensiveTools = [
       beads.packages.${system}.default
       pkgs.zellij
       pkgs.lazygit
       opencodeAi
       claudeCode
     ];
   ```
   
   **Why this is required:**
   - `nodejs_22_patched` is defined in `infra/overlays/cve-patches.nix`
   - Without overlays, `pkgs.nodejs_22_patched` will be missing
   - The overlay packages reference `nodejs_22_patched` in their derivations
   - This matches the pattern in `infra/overlays/pyright-patched/package.nix`
   
   **Why this works in CI:**
   - The `infra` input is a flake input, resolved by Nix
   - `"${infra}"` expands to the path of the infra flake source
   - This works in both local builds and CI (no relative path assumptions)

**Local testing before pushing:**

Since `infra.url` points to GitHub, local testing of uncommitted overlays requires overriding the input:

```bash
cd .devcontainer/features/pensive-assistant

# Test with local infra (uncommitted changes)
nix build .#default --override-input infra path:../../../infra

# After committing overlay to infra/, update flake.lock to use new revision
git add ../../../infra/overlays/opencode-ai/
git commit -m "chore: add opencode-ai overlay"

# CRITICAL: Update flake.lock to pick up the new infra commit
nix flake lock --update-input infra
# This updates .devcontainer/features/pensive-assistant/flake.lock

# Now build with the committed version
nix build .#default  # Uses infra revision from flake.lock
```

**Why flake.lock update is required:**
- Flake inputs are pinned by `flake.lock` (includes commit hash)
- Without updating the lock, builds use the OLD infra revision
- CI also uses `flake.lock`, so this ensures CI and local builds match

**Reference:** See `infra/overlays/pyright-patched/` for existing example of this pattern.

**Alternative if buildNpmPackage fails: Consult nixpkgs documentation**

**STRONGLY PREFER `buildNpmPackage`** - it handles npm dependencies automatically via hooks and is the standard approach in nixpkgs.

If `buildNpmPackage` fails for some reason (very rare), consult:
- `pkgs/build-support/node/build-npm-package/default.nix` in nixpkgs
- Existing examples in nixpkgs that use `stdenv.mkDerivation` for npm packages
- The nixpkgs manual section on Node.js packaging

**Why we don't document stdenv.mkDerivation here:**
- Requires manual wiring of `fetchNpmDeps` → writable npm cache (complex and error-prone)
- buildNpmPackage handles this automatically via hooks
- No known cases in this repo where buildNpmPackage is insufficient

**Decision:** Use `buildNpmPackage` for both opencode-ai and claude-code.

**Expected binary locations in tarball:**
- `nix/store/XXX-pensive-assistant-tools/bin/opencode`
- `nix/store/XXX-pensive-assistant-tools/bin/claude`

**References:**
- `.devcontainer/features/pensive-assistant/flake.nix:23-27` - existing pensiveTools list
- `infra/overlays/pyright-patched/package.nix` - LOCAL example of `buildNpmPackage` in this repo (shows npmDepsHash, src handling)
- [Nix buildNpmPackage docs](https://nixos.org/manual/nixpkgs/stable/#javascript-buildNpmPackage)

**Parallelizable:** NO (depends on TODO 1)

**Acceptance Criteria:**
- Overlays created for BOTH packages:
  - `infra/overlays/opencode-ai/package.nix` exists
  - `infra/overlays/opencode-ai/package-lock.json` exists (if lockfile was missing)
  - `infra/overlays/claude-code/package.nix` exists
  - `infra/overlays/claude-code/package-lock.json` exists (if lockfile was missing)
- Feature flake imports both overlays via `callPackage`
- `nix build .#default` succeeds in `.devcontainer/features/pensive-assistant/`
- `ls result/bin/` shows: `bd`, `zellij`, `lazygit`, `opencode`, `claude`

---

### 3. Remove runtime bun installation from install.sh
**What to do:**
- Delete lines 124-132 (the `bun install -g @anthropic-ai/claude-code` block)
- Add `opencode` and `claude` to the symlink loop (line 154)

**References:**
- `.devcontainer/features/pensive-assistant/install.sh:124-132` - code to remove
- `.devcontainer/features/pensive-assistant/install.sh:154-159` - symlink loop to update

**Before:**
```bash
for tool in bd zellij lazygit; do
```

**After:**
```bash
for tool in bd zellij lazygit opencode claude; do
```

**Note on bun:**
- `bun` is NOT symlinked here - it comes from the base image via `packageSets.nodeDev`
- `bun` is already in PATH from the base devcontainer
- We only symlink tools that come from the pensive-assistant tarball

**Parallelizable:** NO (depends on TODO 2)

**Acceptance Criteria:**
- No `bun install` calls in install.sh for Nix mode:
  ```bash
  grep -n "bun install -g" .devcontainer/features/pensive-assistant/install.sh
  # Expected: no matches (or only in Ubuntu mode section)
  ```
- 5 tools symlinked to ~/.local/bin: `bd`, `zellij`, `lazygit`, `opencode`, `claude`
  ```bash
  grep -A5 "for tool in" .devcontainer/features/pensive-assistant/install.sh
  # Expected: for tool in bd zellij lazygit opencode claude; do
  ```
- `bun` available via base image PATH (not symlinked)

---

### 4. Update test.sh to verify all 6 tools
**What to do:**
- Add version checks for `opencode` and `claude`
- Add check for `bun` (from base image)
- Ensure all checks use `--version` for consistency

**Current test.sh checks:**
- `bd --version` ✅
- `zellij --version` ✅
- `lazygit --version` ✅
- `command -v claude` (weak - only checks existence)

**Required test.sh checks after update:**
```bash
# Version checks (basic availability)
bd --version || exit 1
zellij --version || exit 1
lazygit --version || exit 1
bun --version || exit 1        # From base image
opencode --version || exit 1   # NEW - from tarball
claude --version || exit 1     # NEW - from tarball (upgrade from command -v)

# Functional smoke tests (beyond --version)
# These catch cases where --version works but runtime is broken
opencode --help > /dev/null || exit 1   # Verify help works without network
claude --help > /dev/null || exit 1     # Verify help works without network

# CRITICAL: Tarball provenance checks
# Verify tools are ACTUALLY from the extracted tarball, not just "in /nix/store"
# Being in /nix/store is necessary but not sufficient (could be from base image)

OPENCODE_PATH=$(command -v opencode)
CLAUDE_PATH=$(command -v claude)
echo "opencode path: $OPENCODE_PATH"
echo "claude path: $CLAUDE_PATH"

# Resolve symlinks to find actual binary location
OPENCODE_REAL=$(readlink -f "$OPENCODE_PATH" 2>/dev/null || echo "$OPENCODE_PATH")
CLAUDE_REAL=$(readlink -f "$CLAUDE_PATH" 2>/dev/null || echo "$CLAUDE_PATH")
echo "opencode real: $OPENCODE_REAL"
echo "claude real: $CLAUDE_REAL"

# Step 1: Assert NOT in home directory (catches bun install -g)
if [[ "$OPENCODE_REAL" == $HOME/* ]]; then
  echo "ERROR: opencode in home dir $OPENCODE_REAL (should be /nix/store)"
  exit 1
fi
if [[ "$CLAUDE_REAL" == $HOME/* ]]; then
  echo "ERROR: claude in home dir $CLAUDE_REAL (should be /nix/store)"
  exit 1
fi

# Step 2: Assert the resolved paths are in /nix/store
if [[ "$OPENCODE_REAL" != /nix/store/* ]]; then
  echo "ERROR: opencode resolves to $OPENCODE_REAL (expected /nix/store/...)"
  exit 1
fi
if [[ "$CLAUDE_REAL" != /nix/store/* ]]; then
  echo "ERROR: claude resolves to $CLAUDE_REAL (expected /nix/store/...)"
  exit 1
fi

# Step 3: Verify the store paths are PRESENT IN THE TARBALL
# This proves they came from the tarball, not from base image or other source

# Find tarball path (context-independent)
# In CI: /feature/dist/pensive-tools.tar.gz (mounted)
# In devcontainer: relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARBALL_PATH="${TARBALL_PATH:-${SCRIPT_DIR}/dist/pensive-tools.tar.gz}"

if [[ ! -f "$TARBALL_PATH" ]]; then
  echo "ERROR: Tarball not found at $TARBALL_PATH"
  echo "Set TARBALL_PATH env var or ensure dist/pensive-tools.tar.gz exists"
  exit 1
fi

TARBALL_CONTENTS=$(tar -tzf "$TARBALL_PATH")

# Extract store path prefix (e.g., /nix/store/abc123-opencode-ai-1.1.34)
OPENCODE_STORE_PATH=$(echo "$OPENCODE_REAL" | grep -oE '/nix/store/[^/]+')
CLAUDE_STORE_PATH=$(echo "$CLAUDE_REAL" | grep -oE '/nix/store/[^/]+')

echo "Checking tarball for: $OPENCODE_STORE_PATH"
if ! echo "$TARBALL_CONTENTS" | grep -q "^${OPENCODE_STORE_PATH#/}"; then
  echo "ERROR: opencode store path NOT in tarball"
  echo "Tarball contains:"
  echo "$TARBALL_CONTENTS" | grep "opencode" | head -5
  exit 1
fi

echo "Checking tarball for: $CLAUDE_STORE_PATH"
if ! echo "$TARBALL_CONTENTS" | grep -q "^${CLAUDE_STORE_PATH#/}"; then
  echo "ERROR: claude store path NOT in tarball"
  echo "Tarball contains:"
  echo "$TARBALL_CONTENTS" | grep "claude" | head -5
  exit 1
fi

echo "✓ Tools verified from tarball (store paths present in archive)"
```

**Note:** `claude --version` outputs to stderr and returns 0, so this works non-interactively.

**Why provenance checks with readlink + tarball verification?**
- install.sh creates symlinks in `~/.local/bin` pointing to `${ENV_PATH}/bin/*`
- `command -v` returns the symlink path, not the target
- `readlink -f` resolves to the actual `/nix/store/...` binary
- Being in `/nix/store` is necessary but NOT sufficient (could be from base image)
- **Tarball membership check** proves the store path came from the extracted tarball
- This catches:
  - Stale `bun install -g` versions in `~/.bun/bin`
  - Store paths from base image that weren't in the tarball
  - Accidental PATH ordering issues

**References:**
- `.devcontainer/features/pensive-assistant/test.sh` - existing test file

**Parallelizable:** YES (can be done alongside TODO 2-3)

**Acceptance Criteria:**
- test.sh checks all 6 tools with `--version`:
  ```bash
  grep -E "(bd|zellij|lazygit|bun|opencode|claude) --version" .devcontainer/features/pensive-assistant/test.sh
  # Expected: 6 matches (one for each tool)
  ```
- test.sh includes provenance checks (tarball membership):
  ```bash
  grep -A5 "TARBALL_CONTENTS" .devcontainer/features/pensive-assistant/test.sh
  # Expected: tar -tzf check + grep for store paths
  ```
- test.sh exits non-zero if any tool missing or fails

---

### 4b. Wire test.sh into CI workflow
**What to do:**
- Add a step to `.github/workflows/publish-pensive-assistant.yml` that runs test.sh after tarball build
- The test must run inside a container with the tarball extracted

**Current state:**
- `test.sh` exists but is NOT called by CI (verified by searching workflow file)

**Add to workflow (after build step):**
```yaml
- name: Test pensive-assistant tools
  run: |
    # Mount entire feature directory so test.sh is accessible
    # --user root: Required to extract to /nix/store (absolute paths)
    docker run --rm \
      --user root \
      -v ${{ github.workspace }}/.devcontainer/features/pensive-assistant:/feature \
      ghcr.io/mrdavidlaing/laingville/laingville-devcontainer:latest \
      bash -l -c "
        # Use login shell (-l) to source /etc/profile.d scripts
        # This ensures bun from base image is on PATH
        
        # Extract tarball to /nix/store (requires root)
        tar -xzf /feature/dist/pensive-tools.tar.gz -C /
        
        # Get the env path and prepend to PATH
        ENV_PATH=\$(cat /feature/dist/env-path)
        export PATH=\"\${ENV_PATH}/bin:\$PATH\"
        
        # Pre-flight check: verify tools are available and log their paths
        echo '=== Pre-flight checks ==='
        echo \"bun: \$(command -v bun)\"
        echo \"opencode: \$(command -v opencode)\"
        echo \"claude: \$(command -v claude)\"
        
        command -v bun || { echo 'ERROR: bun not found in PATH'; exit 1; }
        bun --version
        
        # Run tests (includes provenance checks)
        # Set TARBALL_PATH so test.sh can find it in CI context
        chmod +x /feature/test.sh
        TARBALL_PATH=/feature/dist/pensive-tools.tar.gz /feature/test.sh
      "
```

**Key details:**
- `bash -l` (login shell): Sources `/etc/profile.d/*.sh` from base image, ensuring bun is on PATH
- `--user root`: Required because tarball extracts to `/nix/store` (absolute paths)
- PATH setup: We only prepend `${ENV_PATH}/bin` for tarball tools; bun comes from login shell sourcing
- Pre-flight check: Explicitly verify bun is available BEFORE running test.sh

**CRITICAL: PATH ordering must match production:**
- Production (install.sh): `~/.local/bin` (symlinks to tarball) is prepended to user's PATH
- CI test: `${ENV_PATH}/bin` (tarball) is prepended to PATH
- Both should have tarball tools BEFORE any `~/.bun/bin` entries
- Test must verify this ordering catches regressions where `bun install -g` would shadow tarball tools

**Verification of PATH ordering:**
The test.sh provenance checks (Step 3 in test.sh) verify that resolved binaries are:
1. NOT in `$HOME` (catches `~/.bun/bin`)
2. IN `/nix/store` (correct source)
3. PRESENT in tarball (proves tarball origin, not base image)

This triple-check ensures PATH ordering is correct and tarball tools take precedence.

**Why not run `install.sh` in CI?**
- CI tests the TARBALL, not the full install flow
- `install.sh` would pull from OCI (we want to test the locally-built tarball)
- Faster: skip oras/network logic, just extract and verify

**Fallback if login shell doesn't work:**
If `/etc/profile.d` scripts aren't sourced properly, explicitly find and add bun:
```bash
# Alternative: find bun in Nix store and add to PATH
BUN_PATH=$(find /nix/store -maxdepth 2 -name 'bun' -type f -executable 2>/dev/null | head -1)
export PATH="$(dirname $BUN_PATH):$PATH"
```

**Key mount:** `-v .../pensive-assistant:/feature` mounts the ENTIRE feature directory, so:
- `/feature/dist/pensive-tools.tar.gz` - the tarball
- `/feature/dist/env-path` - the env path file
- `/feature/test.sh` - the test script

**Exact insertion point in workflow:**
- File: `.github/workflows/publish-pensive-assistant.yml`
- Job: `build-tarballs`
- Position: After the step named "Build feature tarball" and BEFORE "Push tarball to OCI registry"
- This ensures we test the tarball before publishing it

**References:**
- `.github/workflows/publish-pensive-assistant.yml` - CI workflow to update

**Parallelizable:** YES (can be done after TODO 4)

**Acceptance Criteria:**
- CI fails if any tool is missing or broken
- test.sh runs in an environment matching production usage

---

### 5. Build and verify tarball
**What to do:**
- Run `just pensive-assistant-build`
- Verify tarball contains opencode and claude binaries
- Check tarball size impact

**Verification commands:**
```bash
# Build
just pensive-assistant-build

# Extract and verify binaries exist
mkdir -p /tmp/tarball-check
tar -xzf .devcontainer/features/pensive-assistant/dist/pensive-tools.tar.gz -C /tmp/tarball-check

# Check the env-path file to find the buildEnv location
ENV_PATH=$(cat .devcontainer/features/pensive-assistant/dist/env-path)

# Verify all expected binaries
ls -la /tmp/tarball-check${ENV_PATH}/bin/
# Expected output: bd, claude, lazygit, opencode, zellij (5 binaries)

# Verify they're executable
/tmp/tarball-check${ENV_PATH}/bin/opencode --version
/tmp/tarball-check${ENV_PATH}/bin/claude --version

# Clean up
rm -rf /tmp/tarball-check
```

**Parallelizable:** NO (depends on TODO 2)

**Acceptance Criteria:**
- Tarball builds successfully
- `${ENV_PATH}/bin/` contains: `bd`, `zellij`, `lazygit`, `opencode`, `claude`
- Each binary runs `--version` successfully
- Document tarball size (current: ~64M compressed)

---

### 6. Update documentation and metadata
**What to do:**
- Update install.sh echo messages (line 168-172) to list all 6 tools
- Update devShell shellHook in flake.nix (line 64)
- Update `devcontainer-feature.json` description to include opencode

**Current devcontainer-feature.json description:**
```json
"description": "Pensive Assistant tools: beads, zellij, lazygit, claude code"
```

**Updated description:**
```json
"description": "Pensive Assistant tools: beads, zellij, lazygit, bun, opencode, claude"
```

**References:**
- `.devcontainer/features/pensive-assistant/install.sh:168-172`
- `.devcontainer/features/pensive-assistant/flake.nix:64`
- `.devcontainer/features/pensive-assistant/devcontainer-feature.json`

**Parallelizable:** YES

**Acceptance Criteria:**
- install.sh output lists all 6 tools with source labels:
  - `bd`, `zellij`, `lazygit`, `opencode`, `claude` - "(tarball)"
  - `bun` - "(base image)"
- flake.nix shellHook mentions all 5 tarball tools
- flake.nix has comments documenting version pins and packaging decisions from TODO 1
- devcontainer-feature.json description: "beads, zellij, lazygit, opencode, claude (bun from base image)"

---

## Commit Strategy

Single commit after all changes:
```
feat(pensive-assistant): add opencode + claude to Nix tarball

- Add opencode-ai and claude-code derivations to flake.nix
- Remove runtime bun installation from install.sh
- Update test.sh to verify all 6 tools
- Update documentation

This makes Nix secure mode truly network-free at container startup.
All tools are now pre-built in the tarball.
```

Files:
- `.devcontainer/features/pensive-assistant/flake.nix`
- `.devcontainer/features/pensive-assistant/install.sh`
- `.devcontainer/features/pensive-assistant/test.sh`
- `.devcontainer/features/pensive-assistant/devcontainer-feature.json`
- `.github/workflows/publish-pensive-assistant.yml`

---

## Success Criteria

**Verification Commands (in container):**
```bash
bd --version        # beads 0.49.0
zellij --version    # zellij 0.43.1
lazygit --version   # lazygit 0.58.1
bun --version       # 1.3.6 (from base image)
opencode --version  # 1.1.34
claude --version    # 2.1.19
```

**All tools present, no network calls during install, tarball-only extraction.**
