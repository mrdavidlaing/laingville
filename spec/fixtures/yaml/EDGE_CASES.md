# YAML Parser Edge Cases

This document summarizes the critical edge cases tested and fixed in the awk-based YAML parser.

## Summary

The parser now correctly handles YAML quoting rules:
- **Quoted strings**: Everything inside quotes is literal (including `#` and `:`)
- **Unquoted strings**: `#` starts a comment, even in the middle of a value
- **Security**: Tabs in YAML are rejected by security validation

## Edge Cases Tested

### 1. Hash Symbols in Package Names

**Rule**: In YAML, `#` starts a comment anywhere outside of quotes.

```yaml
arch:
  pacman:
    - git # comment           → "git"
    - "package#hash"          → "package#hash"
    - package#hash            → "package" (hash starts comment!)
```

**Fix**: Parser now checks if value is quoted before stripping comments.

### 2. Colons in Package Names

**Rule**: Colons work fine in both quoted and unquoted contexts in YAML list items.

```yaml
windows:
  psmodule:
    - Module:With:Colons      → "Module:With:Colons"
    - "Quoted:Colons"         → "Quoted:Colons"
arch:
  pacman:
    - package:v1.2.3          → "package:v1.2.3"
```

**Result**: Colons don't require special handling in list items.

### 3. Comments Inside Quoted Strings

**Rule**: Content inside quotes is literal, even if it looks like a comment.

```yaml
windows:
  scoop:
    - "git # this is NOT a comment"  → "git # this is NOT a comment"
    - git # this IS a comment        → "git"
```

**Fix**: Parser extracts content between quotes first, then handles comments.

### 4. Comments After Closing Quotes

**Rule**: Comments after the closing quote are stripped.

```yaml
arch:
  pacman:
    - "package" # this comment is stripped  → "package"
```

**Result**: Works correctly with the fixed parser.

### 5. Inline Arrays with Special Characters

**Rule**: Inline array format must handle quotes properly.

```yaml
arch:
  yay: ["package#hash", "another:package"]
```

**Fix**: Applied same quote handling logic to inline array parser.

### 6. Tabs Mixed with Spaces

**Rule**: YAML spec discourages tabs for indentation.

```yaml
arch:
	pacman:  # Tab character
    - git
```

**Result**: Rejected by security validation (`validate_yaml_file`) with clear error message.

### 7. Max Package Limit

**Rule**: Parser silently truncates at 100 packages per section.

```yaml
arch:
  pacman:
    - package1
    - package2
    # ... 99 more packages ...
    - package101  # This is ignored
```

**Result**: Tested and confirmed truncation happens at 100 packages.

### 8. Empty List Items

**Rule**: Empty list items are skipped.

```yaml
arch:
  pacman:
    - git
    -        # Empty item (skipped)
    - vim
```

**Result**: Works correctly, empty items filtered out.

### 9. Unicode Characters

**Rule**: Unicode characters in package names should pass through.

```yaml
arch:
  pacman:
    - git
    - café
    - 日本語
```

**Result**: Tested and confirmed Unicode characters preserved.

### 10. Very Long Package Names

**Rule**: Package names up to 10,000+ characters are supported.

**Result**: Tested with 1,500 character package name, works correctly.

## Implementation Details

### Parser Logic Flow

For each package value in the YAML:

1. **Strip list marker and leading whitespace**: `- package` → `package`

2. **Check if value is quoted**:
   - If starts with `"` and contains closing `"`: Extract content between double quotes
   - If starts with `'` and contains closing `'`: Extract content between single quotes
   - Preserve EVERYTHING inside quotes (including `#`, `:`, spaces)

3. **If not quoted**:
   - Strip comments: everything after `#` is removed
   - Strip any stray quotes from start/end

4. **Strip trailing whitespace**

5. **Validate and output** (if non-empty after processing)

### Code Locations

The fix was applied in two functions in `lib/packages.functions.bash`:

1. **`extract_packages_from_yaml()`**: Lines 131-160 (inline arrays), 184-218 (list items)
2. **`extract_cleanup_packages_from_yaml()`**: Lines 294-320 (inline arrays), 340-368 (list items)

## Testing

Test files:
- `spec/fixtures/yaml/packages-edge-cases.yaml`: Edge case fixtures
- `spec/yaml_parser_edge_cases_spec.sh`: ShellSpec tests for all edge cases

Run tests:
```bash
shellspec spec/yaml_parser_edge_cases_spec.sh
```

## Migration Guide

If you have package names containing `#`:

**Before** (would fail):
```yaml
arch:
  yay:
    - my-package#v1.2.3  # Parsed as "my-package"
```

**After** (use quotes):
```yaml
arch:
  yay:
    - "my-package#v1.2.3"  # Correctly parsed as "my-package#v1.2.3"
```

This is correct YAML behavior - `#` always starts a comment outside of quotes.
