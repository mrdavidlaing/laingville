## [2026-01-24T20:17] Task: TODO 1 - Research npm package structure

### opencode-ai@1.1.34

**Lockfile:** ❌ NO package-lock.json in tarball  
**Native dependencies:** ❌ NO binding.gyp or .node files  
**Postinstall script:** ✅ YES - `bun ./postinstall.mjs || node ./postinstall.mjs`

**Bin field:** `{ opencode: 'bin/opencode' }`

**Postinstall behavior:**
- Tries to find platform-specific binary package: `opencode-${platform}-${arch}`
- Uses `require.resolve()` to locate the binary package
- Creates symlink from `bin/opencode` to the platform binary
- On Windows: skips setup (uses packaged .exe)
- On Unix: verifies binary exists and creates wrapper

**Key insight:** The postinstall script expects OPTIONAL DEPENDENCIES:
- `opencode-darwin-x64`
- `opencode-darwin-arm64`
- `opencode-linux-x64`
- `opencode-linux-arm64`
- `opencode-windows-x64`

These are separate npm packages containing the actual binaries.

**Nix packaging decision:**
- ❌ Cannot use postinstall (requires network to install optional deps)
- ✅ Must use `npmInstallFlags = [ "--ignore-scripts" ]`
- ✅ Need to manually provide the platform binary (see postinstall fallback in plan)

---

### @anthropic-ai/claude-code@2.1.19

**Lockfile:** ❌ NO package-lock.json in tarball (has bun.lock but not npm)  
**Native dependencies:** ✅ YES - ripgrep.node files for multiple platforms  
**Postinstall script:** ❌ NO postinstall (only "prepare" script for publishing)

**Bin field:** `{ claude: 'cli.js' }`

**Package contents:**
- `cli.js` (11.6MB) - main CLI bundle
- `vendor/ripgrep/` - platform-specific ripgrep binaries and .node files
  - arm64-darwin/rg + ripgrep.node
  - arm64-linux/rg + ripgrep.node
  - x64-darwin/rg + ripgrep.node
  - x64-linux/rg + ripgrep.node
  - x64-win32/rg.exe + ripgrep.node
- `resvg.wasm` (2.5MB)
- `tree-sitter.wasm` + `tree-sitter-bash.wasm`

**Key insight:** All platform binaries are INCLUDED in the tarball (not optional deps).

**Nix packaging decision:**
- ✅ Can use standard `buildNpmPackage` approach
- ✅ No postinstall to worry about
- ⚠️ Large tarball size (71.5MB unpacked) due to multi-platform binaries
- ✅ May want `npmInstallFlags = [ "--ignore-scripts" ]` to skip "prepare" script

---

## Decision Summary

### opencode-ai
- **Approach:** Create overlay with generated lockfile
- **Flags:** `npmInstallFlags = [ "--ignore-scripts" ]`
- **Binary handling:** Need postinstall fallback (manual binary placement)
- **Binary source:** Must fetch from opencode-${platform}-${arch} npm packages OR find GitHub releases

### claude-code
- **Approach:** Create overlay with generated lockfile
- **Flags:** `npmInstallFlags = [ "--ignore-scripts" ]` (optional, to skip prepare)
- **Binary handling:** All binaries included in tarball, no special handling needed
- **Size:** Large (71.5MB unpacked) but acceptable

### Next Steps
1. Generate lockfiles for both packages (run `npm install --package-lock-only`)
2. Create overlay directories in `infra/overlays/`
3. For opencode-ai: Research where to get platform binaries (check npm registry for opencode-linux-x64, etc.)

---

## Platform Binary Packages for opencode-ai

✅ **FOUND:** Platform-specific binaries are published as separate npm packages

### x86_64-linux
- Package: `opencode-linux-x64@1.1.34`
- URL: https://registry.npmjs.org/opencode-linux-x64/-/opencode-linux-x64-1.1.34.tgz
- Size: 146.5 MB unpacked
- SHA512: sha512-+a4K3rs43U9z2h8x4g/VbUwr0seQfQwf1LI/Y3vgBK+Kh8euW9JgJ+YnJrnrue4rE+KucSO0ANo8jAbuduzrfw==

### aarch64-linux
- Package: `opencode-linux-arm64@1.1.34`
- URL: https://registry.npmjs.org/opencode-linux-arm64/-/opencode-linux-arm64-1.1.34.tgz
- Size: 139.5 MB unpacked
- SHA512: sha512-ca2upvf/yRcJkVo3H7jV5fb6OY8l8uX985qXve2YNv8KSRE8+qDnzEIFpx2K0JTVePAguw+i/CLPvl5jtXc6Xw==

### Nix Packaging Strategy for opencode-ai

**Option 1: Use platform binary packages (RECOMMENDED)**
- Fetch the appropriate `opencode-linux-{arch}` tarball based on `stdenv.hostPlatform.system`
- Extract the binary from the tarball
- Place it where the CLI expects it (based on postinstall.mjs logic)

**Option 2: Skip postinstall and use wrapper**
- Use `npmInstallFlags = [ "--ignore-scripts" ]`
- The `bin/opencode` wrapper script should handle finding the binary
- May need to patch the wrapper to work without the postinstall setup

**DECISION:** Use Option 1 - fetch platform binary packages and place them correctly.

This avoids patching and matches the intended package structure.

---

## TODO 1 Completion Checklist

✅ Checked nixpkgs availability (not found - need custom derivations)  
✅ Analyzed npm package structure for both packages  
✅ Checked for lockfiles (NONE - need to generate)  
✅ Checked for native deps (opencode: NO, claude: YES - ripgrep.node)  
✅ Checked postinstall scripts (opencode: YES - needs platform binaries, claude: NO)  
✅ Checked bin field mappings (opencode: bin/opencode, claude: cli.js)  
✅ Identified platform binary sources (opencode-linux-{arch} npm packages)  
✅ Documented findings in notepad  

**Next step:** TODO 2 - Create Nix derivations in infra/overlays/
