# Proposal: Update DevContainer Documentation to Match Implementation

## Problem Statement

The devcontainer documentation in `docs/` was written as an architectural specification when the project was initially designed. Since then, significant implementation work has occurred, but the documentation has not been updated to reflect the current state.

The documentation currently describes a "planned" Ubuntu implementation that has been completed, references non-existent patterns (e.g., Leash policy enforcement that was never implemented), and has an inaccurate implementation status table. Users reading the docs get a misleading picture of what actually exists versus what was only planned.

This proposal aims to synchronize the documentation with the actual `.devcontainer/` implementation, making it accurate and actionable for developers wanting to use the devcontainer setup.

## Research Findings

### Existing Patterns

#### Documentation Structure

The current documentation follows a hierarchical pattern:
- `docs/README.md:1-40` - Index file listing all documentation
- `docs/devcontainer.md` - Main architecture document (536 lines)
- `docs/devcontainer-multi-arch-setup.md` - Multi-arch setup guide (214 lines)
- `docs/specs/devcontainer-feature.md` - Feature interface specification (113 lines)
- `docs/implementations/nix/README.md` - Nix backend documentation
- `docs/implementations/ubuntu/README.md` - Ubuntu backend documentation

#### Implementation Structure

The actual implementation in `.devcontainer/`:
- `.devcontainer/devcontainer.json:1-54` - Main "Yolo Agent" config using pre-built image
- `.devcontainer/docker-compose.yml:1-43` - Docker compose with SSH and GH token forwarding
- `.devcontainer/bin/ctl:1-171` - CLI tool for devcontainer lifecycle management
- `.devcontainer/ubuntu/devcontainer.json:1-47` - Ubuntu development mode config
- `.devcontainer/ubuntu/docker-compose.yml:1-20` - Ubuntu compose using Dockerfile
- `.devcontainer/ubuntu.Dockerfile:1-206` - Full Ubuntu 24.04 base image with all runtimes
- `.devcontainer/features/pensive-assistant/` - Custom feature with dual-mode install

### Files to Modify/Create

| File | Action | Changes Needed |
|------|--------|----------------|
| `docs/devcontainer.md:524-536` | **MODIFY** | Update Implementation Status table to reflect current state |
| `docs/devcontainer.md:218-276` | **MODIFY** | Update Development Mode section to describe actual Ubuntu Dockerfile |
| `docs/devcontainer.md:408-438` | **MODIFY** | Update Directory Structure to match actual layout |
| `docs/implementations/ubuntu/README.md:1-94` | **MODIFY** | Update to reflect actual `ubuntu.Dockerfile` implementation |
| `docs/README.md:29-32` | **MODIFY** | Update Ubuntu implementation description |
| `docs/devcontainer.md:2-6` | **MODIFY** | Change status from "Architectural Specification" to "Implementation Guide" |
| `docs/ctl-usage.md` | **CREATE** | Document the `.devcontainer/bin/ctl` tool |
| `docs/devcontainer-quickstart.md` | **CREATE** | Add a quickstart guide for new users |

### Technical Constraints

1. **Dual Mode Reality**: The documentation describes Secure (Nix) and Development (Ubuntu) modes, but in practice:
   - The main `.devcontainer/devcontainer.json` uses a pre-built Nix image from ghcr.io
   - The `.devcontainer/ubuntu/` directory provides local-build Ubuntu alternative
   - Both modes are functional, not "planned"

2. **Feature Extension Implementation**: The `pensive-assistant` feature supports both modes:
   - `install.sh:9-12` - Mode detection (ubuntu vs nix)
   - `install-ubuntu.sh:1-212` - Full Ubuntu implementation
   - `install.sh:14-145` - Nix tarball extraction

3. **CTL Tool**: The `.devcontainer/bin/ctl` script provides lifecycle management not documented anywhere:
   - `ctl up` - Starts container with GitHub credential forwarding
   - `ctl down` - Stops container
   - `ctl shell` - Opens interactive shell
   - `ctl status` - Shows service health

4. **Agent Sandbox Design**: The `docs/plans/2025-12-20-devcontainer-agent-sandbox-design.md` describes Leash integration that was never implemented. This should either be:
   - Moved to a "future/proposed" section, or
   - Removed from the implementation docs

### Gaps Between Documentation and Implementation

| Documentation Says | Reality |
|--------------------|---------|
| Ubuntu mode is "planned" (`devcontainer.md:529`) | Ubuntu mode is fully implemented (`ubuntu.Dockerfile`) |
| Feature pensive-assistant "apt planned" (`devcontainer.md:530`) | Feature has full Ubuntu install script (`install-ubuntu.sh`) |
| No ctl tool mentioned | `bin/ctl` exists and is the primary interface |
| Leash policy enforcement | Never implemented, only design doc exists |
| Directory shows `infra/templates/` | Does not exist in this structure |
| Multi-arch mentions "Cachix integration" | Cachix integration exists but not documented as implemented |

## Implementation Plan

### Approach

The documentation update will proceed in three phases:

1. **Accuracy Pass**: Update all incorrect status indicators and descriptions to match the actual implementation. This includes the Implementation Status table and mode descriptions.

2. **New Documentation**: Create missing documentation for implemented features (ctl tool, quickstart guide).

3. **Cleanup Pass**: Remove or relocate documentation for features that were never implemented (Leash agent sandbox) to prevent confusion.

### Steps

1. **Update `docs/devcontainer.md` Implementation Status table** (lines 524-536)
   - Change "Bedrock Image: Ubuntu" from "planned" to "Complete"
   - Change "Feature: pensive-assistant (apt)" from "planned" to "Complete"
   - Add entry for `bin/ctl` tool
   - Rationale: This is the most visible inaccuracy that confuses readers

2. **Update `docs/devcontainer.md` Development Mode section** (lines 218-276)
   - Replace example Dockerfile with actual `ubuntu.Dockerfile` summary
   - Document actual tools installed (uv, fnm, starship, direnv)
   - Update workflow to reflect `ctl` tool usage
   - Rationale: The current example is hypothetical; the real implementation is richer

3. **Update `docs/devcontainer.md` Directory Structure** (lines 408-438)
   - Add `bin/ctl` to structure
   - Add `ubuntu/` subdirectory
   - Remove non-existent `infra/templates/`
   - Rationale: Directory structure should be copy-pasteable accurate

4. **Update `docs/implementations/ubuntu/README.md`**
   - Replace example Dockerfile snippets with actual implementations
   - Document actual tools: uv (Python), fnm (Node), rustup (Rust), go binary release
   - Add section on the pensive-assistant feature's Ubuntu mode
   - Rationale: This is the Ubuntu implementation guide; it should reflect reality

5. **Create `docs/ctl-usage.md`**
   - Document all ctl commands (up, down, shell, status, help)
   - Document GitHub credential forwarding mechanism
   - Include usage examples
   - Rationale: The ctl tool is the primary interface but has no documentation

6. **Create `docs/devcontainer-quickstart.md`**
   - Simple "open in VS Code" instructions
   - Alternative "ctl up && ctl shell" workflow
   - Troubleshooting common issues
   - Rationale: Current docs assume deep architecture knowledge; quickstart enables immediate use

7. **Update `docs/README.md` index**
   - Add entries for new documentation files
   - Update descriptions for modified files
   - Rationale: Index should be complete

8. **Relocate agent sandbox design**
   - Move `docs/plans/2025-12-20-devcontainer-agent-sandbox-design.md` reference out of main docs
   - Or add clear "NOT IMPLEMENTED - Future Enhancement" header
   - Rationale: Prevents confusion between implemented and proposed features

### Testing Strategy

Documentation changes don't require code tests, but should be verified:

1. **Accuracy Verification**:
   - All file paths mentioned must exist (`ls` check)
   - All line number references must be valid (`head -n` check)
   - All command examples must work (`ctl status`, `docker compose ps`)

2. **Link Verification**:
   - All internal markdown links resolve correctly
   - Cross-references between docs are valid

3. **User Testing**:
   - Fresh user should be able to follow quickstart guide to working devcontainer
   - Ubuntu mode should be usable following the updated ubuntu/README.md

## Risks and Mitigations

- **Risk:** Documentation changes may introduce new inaccuracies
  - **Mitigation:** Each file path and line number cited in docs must be verified before commit

- **Risk:** Relocating agent sandbox design may confuse users who remember it
  - **Mitigation:** Add clear redirect note in old location pointing to new location

- **Risk:** Quickstart may oversimplify and miss edge cases
  - **Mitigation:** Include "Troubleshooting" section with common issues (Docker not running, permissions, etc.)

## Acceptance Criteria

- [ ] Implementation Status table in `docs/devcontainer.md` accurately reflects what is implemented
- [ ] Directory Structure in `docs/devcontainer.md` matches actual `.devcontainer/` layout
- [ ] `docs/implementations/ubuntu/README.md` describes actual `ubuntu.Dockerfile` contents
- [ ] New `docs/ctl-usage.md` documents all ctl commands with examples
- [ ] New `docs/devcontainer-quickstart.md` enables 5-minute setup for new users
- [ ] `docs/README.md` index includes all documentation files
- [ ] Agent sandbox design is clearly marked as "future/proposed" not "implemented"
- [ ] All file paths cited in documentation are verified to exist

---

## Review: APPROVED

**Reviewer:** Proposal Reviewer (worker-2)

### Review Summary

| Area | Status | Notes |
|------|--------|-------|
| Research accuracy | ✅ Pass | File paths verified, patterns correctly identified |
| Implementation feasibility | ✅ Pass | 8 clear steps with defined scope |
| Testing coverage | ✅ Pass | Accuracy, link, and user testing defined |
| Gaps | ⚠️ Minor | One factual error (see below) |

### Corrections Required Before Implementation

**Error in Gaps Table (line 79):**
The proposal states `infra/templates/` "Does not exist in this structure" - this is **incorrect**.

`infra/templates/` **does exist** and contains:
- `infra/templates/python-project/` - devcontainer, envrc, CI workflow, flake
- `infra/templates/ubuntu-devcontainer/` - Dockerfile, README, devcontainer.json

**Action:** Update Step 3 (lines 108-112) to keep `infra/templates/` in the Directory Structure, but verify it reflects actual contents.

### Verification Details

| Claim | Verified |
|-------|----------|
| `docs/devcontainer.md:524-536` status table | ✅ Lines 524-535 show "planned" Ubuntu status |
| `docs/devcontainer.md:218-276` Development Mode | ✅ Shows hypothetical Dockerfile |
| `docs/devcontainer.md:408-438` Directory Structure | ✅ Shows outdated structure |
| `.devcontainer/bin/ctl` undocumented | ✅ 171-line tool exists |
| `install.sh:9-12` mode detection | ✅ Lines 9-12 check MODE variable |
| `install-ubuntu.sh` exists | ✅ 211 lines of Ubuntu implementation |
| Leash policy not implemented | ✅ Only design doc exists |
| Line counts close to claimed | ✅ Off by 1 (minor doc edits) |

### Strengths
- Comprehensive gap analysis between docs and implementation
- Clear implementation steps with line numbers
- Well-structured testing strategy
- Risks identified with practical mitigations

**Ready for task breakdown.**

---

## Task Review: APPROVED

**Reviewer:** Task Reviewer (worker-4)

**Epic:** LV-4nh
**Tasks:** 8 tasks

### Review Summary

| Criterion | Status | Notes |
|-----------|--------|-------|
| Task clarity | ✅ Pass | All tasks have specific file targets with line numbers |
| Verification included | ✅ Pass | Each task includes concrete verification commands (ls, grep, find) |
| Acceptance criteria | ✅ Pass | Each task has explicit, testable acceptance criteria |
| Dependencies | ✅ Pass | Parent-child structure appropriate; tasks are largely independent |
| Proposal alignment | ✅ Pass | All 8 proposal steps mapped to corresponding tasks |

### Task-by-Task Assessment

| Task ID | Title | Verdict |
|---------|-------|---------|
| LV-4nh.1 | Update Implementation Status table | ✅ Clear scope, verification, acceptance criteria |
| LV-4nh.2 | Update Development Mode section | ✅ Clear scope, verification, acceptance criteria |
| LV-4nh.3 | Update Directory Structure | ✅ Incorporates reviewer correction about infra/templates/ |
| LV-4nh.4 | Update Ubuntu README | ✅ Clear scope, verification, acceptance criteria |
| LV-4nh.5 | Create ctl-usage.md | ✅ Documents all commands with verification |
| LV-4nh.6 | Create devcontainer-quickstart.md | ✅ Both workflows + troubleshooting |
| LV-4nh.7 | Update docs/README.md index | ✅ Clear scope, verification |
| LV-4nh.8 | Mark agent sandbox as NOT IMPLEMENTED | ✅ Clear scope, grep verification |

### Notes

- Task 7 (README index) implicitly depends on Tasks 5-6 (new docs must exist before indexing), but task description makes this clear
- All verification steps are concrete and executable (not deferred)
- No vague or hypothetical language in task descriptions

**Ready for implementation.**

---

## Quick Plan Complete

**Proposal:** [docs/proposals/2026-01-25-devcontainer-docs-proposal.md](./2026-01-25-devcontainer-docs-proposal.md)

**Epic:** `LV-4nh` - Update devcontainer documentation

### Tasks

| Task ID | Title | Status |
|---------|-------|--------|
| LV-4nh.1 | Update Implementation Status table in docs/devcontainer.md | Open |
| LV-4nh.2 | Update Development Mode section in docs/devcontainer.md | Open |
| LV-4nh.3 | Update Directory Structure in docs/devcontainer.md | Open |
| LV-4nh.4 | Update docs/implementations/ubuntu/README.md | Open |
| LV-4nh.5 | Create docs/ctl-usage.md | Open |
| LV-4nh.6 | Create docs/devcontainer-quickstart.md | Open |
| LV-4nh.7 | Update docs/README.md index | Open |
| LV-4nh.8 | Mark agent sandbox design as NOT IMPLEMENTED | Open |

### Dependency Diagram

```
LV-4nh (Epic: Update devcontainer documentation)
├── LV-4nh.1  Update Implementation Status table
├── LV-4nh.2  Update Development Mode section
├── LV-4nh.3  Update Directory Structure
├── LV-4nh.4  Update Ubuntu README
├── LV-4nh.5  Create ctl-usage.md
├── LV-4nh.6  Create devcontainer-quickstart.md
├── LV-4nh.7  Update docs/README.md index ──────┐
│                                               │ (depends on 5, 6 existing)
└── LV-4nh.8  Mark agent sandbox NOT IMPLEMENTED
```

Tasks 1-6 and 8 can be executed in parallel. Task 7 should be done after Tasks 5-6 (new docs must exist before indexing).

### Next Steps

1. **Assign tasks** - Use `bd update LV-4nh.X --status=in_progress` to claim work
2. **Execute independently** - Tasks 1-6 and 8 have no dependencies
3. **Complete Task 7 last** - After new docs (5, 6) are created
4. **Verify each task** - Use the verification commands in each task description
5. **Close epic** - When all 8 tasks complete, close with `bd close LV-4nh`

### Workflow Summary

| Phase | Worker | Action | Result |
|-------|--------|--------|--------|
| 1 | worker-1 (Researcher) | Research & write proposal | Proposal created |
| 2 | worker-2 (Reviewer) | Review proposal | APPROVED (minor correction) |
| 3 | worker-3 (Planner) | Create epic & tasks | LV-4nh with 8 tasks |
| 4 | worker-4 (Reviewer) | Review tasks | APPROVED |
| 5 | worker-1 (Researcher) | Final summary | Complete |

**Planning complete. Ready for implementation.**
