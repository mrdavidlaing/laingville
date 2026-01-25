
# Claude Security Fix Workflow Failures - Investigation & Resolution

## Date: 2026-01-25

## Problem
The `.github/workflows/claude-security-fix.yml` workflow had 21+ consecutive failures since 2026-01-24 23:00:11Z. All runs showed `event: push` and `conclusion: failure` with 0 jobs created.

## Root Causes Identified

### Issue 1: Inconsistent YAML Indentation
- **Location**: Lines 45-106 (first 10 steps)
- **Problem**: Steps used 7-space indentation instead of 6-space
- **Error**: `yaml: line 37: did not find expected key`
- **Fix**: Changed indentation from 7 spaces to 6 spaces for consistency

### Issue 2: Invalid GitHub Actions Expression Syntax
- **Location**: Line 92
- **Problem**: Used double quotes inside `${{ }}` expression
- **Original**: `${{ inputs.model || "claude-sonnet-4-5-20250929" }}`
- **Error**: `Unexpected symbol: '"claude-sonnet-4-5-20250929"'`
- **Fix**: Changed to single quotes: `${{ inputs.model || 'claude-sonnet-4-5-20250929' }}`

## Why 0 Jobs Were Created
When GitHub Actions fails to parse a workflow YAML file, it:
1. Creates a workflow run record (shows in `gh run list`)
2. Marks it as `failure` immediately
3. Creates 0 jobs (no jobs can be created from invalid YAML)
4. Shows `event: push` because the workflow file was modified by a push

This is different from a job failure - it's a workflow parsing failure.

## Commits
1. `0c23a69` - fix(workflows): fix YAML indentation in claude-security-fix.yml
2. `6bf460f` - fix(workflows): fix GitHub Actions expression syntax in claude-security-fix.yml

## Verification
- Manually triggered workflow with `gh workflow run claude-security-fix.yml`
- Workflow started successfully (no parsing error)
- All setup steps completed: Set up job, Validate secrets, Checkout, Install Nix, Setup Nix cache, Configure git, Create feature branch
- Claude /security-fix step running

## Key Learnings

### Debugging GitHub Actions Workflow Failures
1. **0 jobs = YAML parsing failure** - Check workflow syntax
2. **Use `gh workflow run` to test** - It gives immediate parsing error feedback
3. **Local YAML validation isn't enough** - GitHub Actions has stricter expression parsing
4. **Expression syntax**: Use single quotes for string literals in `${{ }}`

### YAML Indentation in GitHub Actions
- Steps should use consistent indentation (typically 6 spaces under `steps:`)
- Mixed indentation causes parsing failures
- Use `yq eval '.' file.yml` to validate YAML locally

### GitHub Actions Expression Syntax
- String literals must use single quotes: `'value'`
- Double quotes are NOT valid in expressions
- Example: `${{ inputs.var || 'default' }}` ✓
- Example: `${{ inputs.var || "default" }}` ✗
