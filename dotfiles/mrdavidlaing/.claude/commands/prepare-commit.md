---
allowed-tools: Bash(git:*), Read, Write, Edit, Grep, Glob
argument-hint: [instructions for what to commit]
description: Intelligently prepare git commit based on instructions
---

## Prepare Commit Message

User instructions: $ARGUMENTS

### Instructions:

1. **Interpret user's intent** from: $ARGUMENTS
   Examples:
   - "everything related to the lazygit change just made"
   - "only the authentication files"
   - "the bug fix we just discussed but not the refactoring"
   - "all changes except tests"
   - "the performance improvements to the API"

2. **Determine what to stage** based on:
   - Current git status: !`git status --porcelain`
   - Recent conversation context
   - File patterns mentioned in instructions
   - Logical grouping of related changes

3. **Stage the appropriate files**:
   - Use `git add` for specific files matching the intent
   - Use `git reset` to unstage files that don't match
   - Report what was staged vs left unstaged

4. **Check/Create .git/gitmessage**:
   - If NOT exists: analyze last 5 commits for patterns
   - If exists: parse AGENT instructions
   
5. **Generate commit message** following **Conventional Commits** format:
   - Format: `type(scope): description`
   - Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build
   - Keep description under 72 characters
   - Add body if needed for context
   - **Do NOT include "🤖 Generated with [Claude Code]" signature**
   - Based on:
     - What was actually staged
     - The work context from our conversation
     - Repo conventions from .git/gitmessage
     - User's instructions about the commit focus

6. **Update .git/gitmessage** with generated message and preserved metadata

7. **Configure git to use the template**:
   - Run `git config commit.template .git/gitmessage` to set repo-specific template
   - This ensures `git commit -v` will automatically use the prepared message

8. **Report with proposed commit message**:
   ```
   Staged X files:
   - path/to/file1
   - path/to/file2
   
   Left unstaged (if any):
   - path/to/file3
   
   Proposed commit message:
   ----------------------------------------
   feat(auth): implement OAuth2 refresh token flow
   
   [sc-4521]
   
   Co-Authored-By: David Laing <david@laing.xyz>
   Co-Authored-By: Claude <noreply@anthropic.com>
   ----------------------------------------
   
   Commit message prepared in .git/gitmessage
   Run 'git commit -v' to review, edit, and finalize
   ```
   
   **Always recommend: `git commit -v`** (shows diff in editor for context)

### Conventional Commit Rules:

- **feat**: New feature
- **fix**: Bug fix  
- **docs**: Documentation only
- **style**: Formatting, missing semicolons, etc (no code change)
- **refactor**: Code change that neither fixes bug nor adds feature
- **test**: Adding missing tests
- **chore**: Maintain (deps update, build process, etc)
- **perf**: Performance improvement
- **ci**: CI/CD changes
- **build**: Build system or dependencies

### Smart Staging Examples:

If user says: "only the config changes"
- Stage: *.config, *.yaml, *.json, .env files
- Message: "chore(config): update configuration files"

If user says: "the refactoring we just did"
- Use conversation context to identify refactored files
- Message: "refactor(auth): extract validation logic to middleware"

### AGENT Instructions Template for .git/gitmessage:

When creating new .git/gitmessage, include these AGENT instruction comments:

```
# AGENT: === Commit Style ===
# AGENT: format: conventional
# AGENT: types: [feat, fix, docs, style, refactor, test, chore, perf, ci, build]
# AGENT: scope_required: false
# AGENT: max_line_length: 72
# AGENT: 
# AGENT: === Story Tracking ===
# AGENT: story_format: [detected from git history]
# AGENT: story_current: [latest story ID found]
# AGENT: 
# AGENT: === Team ===
# AGENT: default_coauthors: David Laing <david@laing.xyz>, Claude <noreply@anthropic.com>
# AGENT: common_coauthors: [detected from git history]
# AGENT: 
# AGENT: === Repo Patterns ===
# AGENT: [any other patterns discovered from analyzing git log]
```

### Implementation Steps:

1. Run `git status --porcelain` to see all changes
2. Interpret user instructions to determine which files to stage
3. Stage appropriate files with `git add [files]`
4. If .git/gitmessage doesn't exist:
   - Run `git log -5 --pretty=format:"%B%n---"` to analyze patterns
   - Create .git/gitmessage with discovered patterns and AGENT instructions
5. If .git/gitmessage exists:
   - Read and parse existing AGENT instructions
   - Preserve story IDs and co-author information
6. Generate conventional commit message based on staged changes and user intent
7. Write message to .git/gitmessage preserving AGENT instructions
8. Configure git to use template: `git config commit.template .git/gitmessage`
9. Report staged files, proposed message, and recommend `git commit -v`