## [2026-01-24T20:30] Created claude-code package.nix

**File:** `infra/overlays/claude-code/package.nix`

**Key decisions:**
- Used `buildNpmPackage` with `nodejs_22_patched` (CVE-2025-64756 fix)
- Set `npmInstallFlags = [ "--ignore-scripts" ]` to skip prepare script
- Set `dontNpmBuild = true` (no build step needed)
- Used placeholder hashes (will be updated in next task):
  - src hash: `sha256-AAAA...`
  - npmDepsHash: `sha256-BBBB...`
- No postinstall handling needed - all platform binaries included in tarball
- License: unfree (proprietary Anthropic software)
- mainProgram: "claude" (bin field maps to cli.js)

**Pattern followed:**
- Based on `infra/overlays/pyright-patched/package.nix`
- Uses `fetchurl` for npm registry tarball
- Uses `postPatch` to copy lockfile from overlay directory
- Simple derivation (no multi-stage build like pyright)

**Next step:** Update placeholder hashes using `nix build` error messages

---

## [2026-01-24T20:30] Created opencode-ai/package.nix

**File:** `infra/overlays/opencode-ai/package.nix`

**Key decisions:**
1. Used `buildNpmPackage` with `nodejs_22_patched` (CVE mitigation)
2. Platform-specific binary handling via conditional `fetchurl`:
   - x86_64-linux → opencode-linux-x64@1.1.34
   - aarch64-linux → opencode-linux-arm64@1.1.34
3. Binary placement strategy:
   - Extract platform package tarball to `$out/lib/node_modules/opencode-linux-{arch}/`
   - This allows `require.resolve('opencode-linux-x64/package.json')` to work
   - Create symlink from `bin/opencode` to platform binary (mimics postinstall.mjs)
4. Used placeholder hashes (A, B, C, D) - will be replaced in next task
5. Set `npmInstallFlags = [ "--ignore-scripts" ]` to skip postinstall
6. Set `dontNpmBuild = true` (no build step needed)

**Pattern learned:** For npm packages with optional platform dependencies:
- Fetch platform-specific packages separately
- Place them in node_modules where require.resolve() can find them
- Replicate the postinstall script's behavior manually

**Next step:** Update hashes using fake hash technique (TODO 3)
