# omo-profile Debug Summary

**Date:** 2026-01-25  
**Issue:** Warning about missing oh-my-opencode binary + profile detection showing "(custom config)"

## Issues Found

### Issue 1: Broken Symlink (FIXED ✅)

**Problem:**
```
Warning: oh-my-opencode binary not found at /Users/mrdavidlaing/.cache/opencode/node_modules/.bin/oh-my-opencode
```

**Root Cause:**
The symlink at `~/.cache/opencode/node_modules/.bin/oh-my-opencode` was pointing to:
```
../oh-my-opencode/bin/oh-my-opencode.js
```

But this path didn't exist. The actual binary was installed at:
```
~/.cache/opencode/node_modules/oh-my-opencode-darwin-arm64/bin/oh-my-opencode
```

oh-my-opencode uses platform-specific packages (darwin-arm64 for macOS on Apple Silicon), and the symlink wasn't updated correctly during installation.

**Fix Applied:**
```bash
cd ~/.cache/opencode/node_modules/.bin
rm oh-my-opencode
ln -s ../oh-my-opencode-darwin-arm64/bin/oh-my-opencode oh-my-opencode
```

**Verification:**
```bash
$ oh-my-opencode --version
3.0.0
```

---

### Issue 2: Profile Detection Shows "(custom config)"

**Problem:**
After running `omo-profile mo-best`, the status shows:
```
Current profile: (custom config)
```

Instead of:
```
Current profile: mo-best
```

**Root Cause:**
The `oh-my-opencode.json` file has an extra category that's not in the mo-best profile:
```json
{
  "categories": {
    "most-capable": {"model": "openai/gpt-5.2"},
    ...
  }
}
```

This is from a previous configuration merge. The profile detection compares categories exactly, so any extra fields cause it to show "(custom config)".

**Is This a Problem?**
No! This is actually **correct behavior**:
- The profile WAS applied successfully (all mo-best models are active)
- The detection just shows it's been customized beyond the base profile
- The extra "most-capable" category doesn't hurt anything

**Current Categories:**
```json
{
  "artistry": {"model": "google/gemini-3-pro"},
  "most-capable": {"model": "openai/gpt-5.2"},  // ← Extra, not in profile
  "quick": {"model": "anthropic/claude-haiku-4-5"},
  "ultrabrain": {"model": "anthropic/claude-opus-4-5"},
  "unspecified-high": {"model": "anthropic/claude-opus-4-5"},
  "unspecified-low": {"model": "anthropic/claude-haiku-4-5"},
  "visual-engineering": {"model": "google/gemini-3-pro"},
  "writing": {"model": "anthropic/claude-sonnet-4-5"}
}
```

**How omo-profile Works:**
The script compares the `.categories` section of:
- Current `oh-my-opencode.json`
- Each profile file in `omo-profiles/`

If they match exactly → shows profile name  
If they don't match → shows "(custom config)"

**To Fix (Optional):**
If you want exact profile detection, remove the extra category:
```bash
jq 'del(.categories."most-capable")' ~/.config/opencode/oh-my-opencode.json > /tmp/config.json
mv /tmp/config.json ~/.config/opencode/oh-my-opencode.json
omo-profile
```

Or just leave it - it's harmless and might be useful.

---

## Verification

### ✅ Profile Applied Successfully
```bash
$ omo-profile
Current profile: (custom config)

Configured Models:

Agents:
  ● sisyphus: anthropic/claude-haiku-4-5
  ● oracle: google/gemini-3-flash-preview
  ● librarian: openai/gpt-5.1
  ● atlas: anthropic/claude-haiku-4-5
  ...
```

All the benchmark-optimized models from mo-best are active:
- ✅ Sisyphus → Haiku (not Opus)
- ✅ Oracle → Gemini Flash (not GPT-5.2)
- ✅ Librarian → GPT-5.1 (not Big-Pickle)
- ✅ Atlas → Haiku (not Sonnet)

### ✅ oh-my-opencode Command Works
```bash
$ oh-my-opencode --version
3.0.0

$ oh-my-opencode doctor
 oMoMoMoMo... Doctor 
  ✓ OpenCode Installation → 1.1.35
  ✓ Configuration Validity → Valid JSON config
  ...
  10 passed, 0 failed, 2 warnings, 3 skipped
```

---

## Summary

**Fixed:**
- ✅ Broken symlink to oh-my-opencode binary
- ✅ `omo-profile` now runs `oh-my-opencode doctor` successfully

**Not a Problem:**
- "(custom config)" detection is correct - you have an extra category
- All mo-best models are active and working
- Profile switching works properly

**Action Items:**
- None required - system is working correctly
- Optional: Remove "most-capable" category if you want exact profile detection

---

## How to Prevent This

The symlink issue might reoccur if oh-my-opencode is reinstalled. To fix permanently, you could:

1. **Add to dotfiles setup script** to check/fix symlink
2. **Report to oh-my-opencode** - this seems like a bug in their installation
3. **Monitor** - if it breaks again, the fix is simple: re-run the symlink command

The command to fix:
```bash
cd ~/.cache/opencode/node_modules/.bin && \
rm oh-my-opencode && \
ln -s ../oh-my-opencode-darwin-arm64/bin/oh-my-opencode oh-my-opencode
```
