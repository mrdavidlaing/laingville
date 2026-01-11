# omo-profile Category-Based Design

**Date:** 2026-01-11
**Issue:** LV-w8e - Configure oh-my-opencode for omo-profile feature
**Status:** Design validated, ready for implementation

## Problem Statement

oh-my-opencode v3 introduced automatic config migration that converts model-based agent configs to category-based configs. The migration logic:

1. Converts `{"model": "anthropic/claude-haiku-4-5"}` → `{"category": "quick"}`
2. Deletes agents that match category defaults (assumes they're redundant)

This breaks omo-profile because:
- omo-profile writes explicit model configs
- opencode startup triggers migration
- Migration deletes Sisyphus and explore agents
- omo-profile detects and restores them
- Cycle repeats on every opencode execution

**Root cause files:**
- `src/plugin-config.ts:23` - Calls migration on every load
- `src/shared/migration.ts:120-134` - Destructive deletion logic

## Solution: Category-Based Profiles

Use oh-my-opencode v3's native `categories` feature to override category-to-model mappings per profile.

### Key Insight

oh-my-opencode v3 supports overriding category defaults in config:

```json
{
  "categories": {
    "quick": {"model": "anthropic/claude-haiku-4-5"},
    "most-capable": {"model": "anthropic/claude-opus-4-5"}
  }
}
```

This allows:
- **Static agent-to-category mapping** (in base config)
- **Dynamic category-to-model mapping** (per profile)
- **No migration conflicts** (no explicit models in agents section)

## Architecture

### Profile Structure

Profiles contain **only** category-to-model mappings:

**value.json:**
```json
{
  "categories": {
    "quick": {"model": "anthropic/claude-haiku-4-5"},
    "most-capable": {"model": "openai/gpt-5-nano"},
    "visual-engineering": {"model": "google/gemini-3-flash"},
    "writing": {"model": "google/gemini-3-flash"}
  }
}
```

**performance.json:**
```json
{
  "categories": {
    "quick": {"model": "anthropic/claude-sonnet-4-5"},
    "most-capable": {"model": "anthropic/claude-opus-4-5"},
    "visual-engineering": {"model": "google/gemini-3-pro"},
    "writing": {"model": "google/gemini-3-flash"}
  }
}
```

**free.json:**
```json
{
  "categories": {
    "quick": {"model": "opencode/glm-4.7-free"},
    "most-capable": {"model": "opencode/glm-4.7-free"},
    "visual-engineering": {"model": "opencode/glm-4.7-free"},
    "writing": {"model": "opencode/glm-4.7-free"}
  }
}
```

### Base Configuration

Base config (`~/.config/opencode/oh-my-opencode.json`) contains agent definitions:

```json
{
  "$schema": "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json",
  "google_auth": false,
  "agents": {
    "Sisyphus": {"category": "quick"},
    "oracle": {"category": "most-capable"},
    "librarian": {"category": "quick"},
    "explore": {"category": "quick"},
    "frontend-ui-ux-engineer": {"category": "visual-engineering"},
    "document-writer": {"category": "writing"},
    "multimodal-looker": {"category": "quick"}
  },
  "categories": {
    "quick": {"model": "anthropic/claude-haiku-4-5"}
  }
}
```

## omo-profile Behavior

### Current Behavior (Broken)
- Copies entire profile → `oh-my-opencode.json` (overwrites everything)
- Compares `.agents` section to detect profile
- Migration corrupts agents on next opencode run

### New Behavior (Fixed)
- Reads current `oh-my-opencode.json`
- **Merges** `categories` from profile into existing config
- Preserves `agents`, `google_auth`, and all other sections
- Compares `.categories` section to detect profile

### Example Flow

**Before:** `omo-profile value` (initial state)
```json
{
  "agents": {"Sisyphus": {"category": "quick"}},
  "google_auth": false,
  "categories": {
    "quick": {"model": "anthropic/claude-sonnet-4-5"}
  }
}
```

**Command:** `omo-profile performance`

**After:** Categories replaced, agents preserved
```json
{
  "agents": {"Sisyphus": {"category": "quick"}},
  "google_auth": false,
  "categories": {
    "quick": {"model": "anthropic/claude-opus-4-5"}
  }
}
```

## File Locations

### Repository Structure
```
dotfiles/shared/
├── .config/opencode/omo-profiles/
│   ├── free.json
│   ├── value.json
│   └── performance.json
└── .local/bin/omo-profile
```

### Installed Structure (via setup-user)
```
~/.config/opencode/
├── oh-my-opencode.json (base config)
└── omo-profiles/ → symlink to ~/laingville/dotfiles/shared/.config/opencode/omo-profiles/
    ├── free.json
    ├── value.json
    └── performance.json

~/.local/bin/
└── omo-profile → symlink to ~/laingville/dotfiles/shared/.local/bin/omo-profile
```

### omo-profile Script Paths
```bash
PROFILES_DIR="$HOME/.config/opencode/omo-profiles"
TARGET_FILE="$HOME/.config/opencode/oh-my-opencode.json"
```

## Implementation Steps

### 1. Create Base Config (One-Time Setup)
Create `~/.config/opencode/oh-my-opencode.json` with agent definitions:

```json
{
  "$schema": "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json",
  "google_auth": false,
  "agents": {
    "Sisyphus": {"category": "quick"},
    "oracle": {"category": "most-capable"},
    "librarian": {"category": "quick"},
    "explore": {"category": "quick"},
    "frontend-ui-ux-engineer": {"category": "visual-engineering"},
    "document-writer": {"category": "writing"},
    "multimodal-looker": {"category": "quick"}
  }
}
```

### 2. Rewrite Profile Files
Move existing profiles from `~/.config/opencode/profiles/` to repo:
- Location: `dotfiles/shared/.config/opencode/omo-profiles/`
- Remove `agents` section
- Remove `google_auth` and other settings
- Keep only `categories` with model mappings

### 3. Update omo-profile Script
Modify `~/.local/bin/omo-profile`:

**switch_profile() changes:**
```bash
# Old: Copy entire profile
cp "$profile_file" "$TARGET_FILE"

# New: Merge categories only
current_config=$(cat "$TARGET_FILE")
profile_categories=$(jq '.categories' "$profile_file")
merged_config=$(echo "$current_config" | jq --argjson cats "$profile_categories" '.categories = $cats')
echo "$merged_config" | jq '.' > "$TARGET_FILE"
```

**get_current_profile() changes:**
```bash
# Old: Compare .agents section
current_agents=$(jq -cS '.agents // {}' "$TARGET_FILE")

# New: Compare .categories section
current_categories=$(jq -cS '.categories // {}' "$TARGET_FILE")
```

### 4. Update setup-user
Add symlink creation for omo-profiles directory:

```bash
# In dotfiles/shared/.config/opencode/
omo-profiles/ → symlink to ~/.config/opencode/omo-profiles/
```

### 5. Testing
1. Run `omo-profile value`
2. Verify categories changed in oh-my-opencode.json
3. Verify agents section preserved
4. Run `opencode run "ping"`
5. Verify no agent configs deleted
6. Run `omo-profile value` again
7. Verify no "Changes from previous config" (stable state)

## Migration Benefits

**Before (broken):**
- omo-profile writes: `{"model": "anthropic/claude-haiku-4-5"}`
- Migration converts: `{"category": "quick"}`
- Migration deletes: (matches defaults)
- Infinite corruption cycle

**After (fixed):**
- omo-profile writes: `{"categories": {"quick": {"model": "..."}}}`
- Migration ignores: (no agents with explicit models)
- No deletion, no corruption
- Stable state achieved

## Future Extensions

This design supports future enhancements:

1. **Per-profile agent mappings** (if needed later):
   ```json
   {
     "agents": {"Sisyphus": {"category": "quick"}},
     "categories": {"quick": {"model": "..."}}
   }
   ```

2. **Project-specific profiles**:
   - Project `.opencode/oh-my-opencode.json` can override categories
   - omo-profile could support project-level profiles

3. **Custom categories**:
   - Add new categories beyond oh-my-opencode defaults
   - Map to specific models per profile

## References

- Issue: LV-w8e (Configure oh-my-opencode for omo-profile feature)
- Parent: LV-9dr (Configure oh-my-opencode)
- Epic: LV-8vv (Configure opencode)
- oh-my-opencode source: `/Users/mrdavidlaing/mo-inator-workspace/devcontainer-experiments/oh-my-opencode/`
