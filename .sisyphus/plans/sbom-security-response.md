# AI-Powered SBOM & Security Response System

## Context

### Original Request
Build an AI-powered security response system with SBOM evidence generation, integrated with GitHub-native security features. Two main goals:
1. **Compliance + Supply Chain Security**: Get container dependencies into GitHub Dependency Graph, attach SBOMs to OCI artifacts
2. **AI-Powered Advisory Response**: Event-driven triage, prioritization, and remediation with before/after evidence

### Interview Summary
**Key Discussions**:
- **Triggers**: User confirmed scheduled API polling (not webhooks) for GHSA, Dependabot alerts, SARIF results
- **AI Actions**: Triage & prioritize, generate fix PRs, create SBOM evidence
- **Evidence Storage**: Both PR artifacts AND OCI attestations (dual storage)
- **Timeline**: ~4 weeks for full solution
- **Constraints**: Keep simple, minimize Claude API costs
- **Test Strategy**: TDD for critical logic

**Research Findings**:
- Existing `security-scan.yml` is robust (Vulnix, Trivy, Grype, Syft, cdxgen, Gitleaks)
- `claude-security-fix.yml` already runs weekly with automated remediation
- `anchore/sbom-action` supports `dependency-snapshot: true` for Dependency Graph submission
- cosign can attach SBOMs as attestations to OCI images
- GitHub Security API provides programmatic access to alerts

### Metis Review
**Identified Gaps** (addressed in plan):
- Polling frequency not specified → Fixed: Run after security-scan completion OR hourly
- Nix → SPDX conversion strategy unclear → Fixed: Phase 1 = store paths + versions only
- Scanner deduplication not specified → Fixed: Use CVE ID as canonical identifier
- AI severity override rules unclear → Fixed: Use highest severity (conservative)
- Large SBOM handling → Fixed: Summarize in PR, full SBOM as artifact

---

## Work Objectives

### Core Objective
Build a multi-trigger, AI-powered security response system that detects vulnerabilities via GitHub-native sources, triages them intelligently, generates remediation PRs with SBOM evidence, and publishes attestations for compliance.

### Concrete Deliverables
1. Updated `security-scan.yml` with Dependency Submission API integration
2. Updated `build-containers.yml` with cosign SBOM attestations
3. New Nix closure SBOM generator script
4. New `security-response.yml` workflow for event-driven AI triage
5. Enhanced `/security-fix` playbook with triage logic and evidence generation
6. Comprehensive test suite for triage logic

### Definition of Done
- [x] Container dependencies visible in GitHub Dependency Graph
- [x] Dependabot alerts fire for known-vulnerable packages in containers
- [x] `cosign verify-attestation` succeeds for all published images
- [x] Security response workflow triggers on schedule and processes new alerts
- [x] PRs include before/after SBOM diff summaries
- [x] All tests pass, Claude API costs < $2/week

### Must Have
- Dependency Submission API integration (container deps in Dependency Graph)
- OCI SBOM attestations via cosign
- Scheduled API polling for GHSA/Dependabot/SARIF alerts
- AI triage with priority scoring (1-5)
- Before/after SBOM evidence in PRs
- TDD for triage logic

### Must NOT Have (Guardrails)
- Remove existing SARIF uploads (keep both SARIF AND Dependency Submission)
- Real-time webhooks (scheduled polling only per user decision)
- Custom compliance dashboard (use GitHub Security tab + PR artifacts)
- Slack/Teams/external notifications (out of scope)
- OSV/NVD external feeds (out of scope)
- Ubuntu development mode SBOMs (out of scope)
- Over-engineered Nix SBOM (Phase 1 = store paths + versions only)
- New scanners beyond existing Trivy/Grype/Vulnix/Syft/cdxgen
- Changes to weekly Claude security-fix schedule (ADD triggers, don't change existing)

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (shellspec for bash, existing test patterns)
- **User wants tests**: TDD
- **Framework**: shellspec for bash scripts, workflow_dispatch + assertions for workflows

### TDD Approach

Each TODO follows RED-GREEN-REFACTOR where applicable:

**For Bash Scripts (Nix SBOM generator, triage logic):**
1. **RED**: Write failing shellspec test first
2. **GREEN**: Implement minimum code to pass
3. **REFACTOR**: Clean up while keeping green

**For GitHub Workflows:**
- Manual verification via `workflow_dispatch` triggers
- Assertions on artifact contents and API responses
- Evidence captured in workflow logs

---

## Task Flow

```
Phase 1 (Week 1)           Phase 2 (Week 2)
┌──────────────────┐       ┌──────────────────┐
│ 1. Dep Submission│       │ 3. OCI Attests   │
│ 2. Verify Alerts │       │ 4. Nix SBOM Gen  │
└────────┬─────────┘       └────────┬─────────┘
         │                          │
         └──────────┬───────────────┘
                    ▼
           Phase 3 (Week 3)
           ┌──────────────────┐
           │ 5. Triage Logic  │
           │ 6. API Polling   │
           └────────┬─────────┘
                    │
                    ▼
           Phase 4 (Week 4)
           ┌──────────────────┐
           │ 7. Evidence Gen  │
           │ 8. Integration   │
           └──────────────────┘
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 3, 4 | OCI attestations and Nix SBOM are independent |
| B | 5, 6 | Triage logic and API polling can be developed in parallel |

| Task | Depends On | Reason |
|------|------------|--------|
| 2 | 1 | Verify alerts requires Dependency Submission to be working |
| 7 | 4, 5 | Evidence generation needs Nix SBOM and triage logic |
| 8 | All | Integration testing requires all components |

---

## TODOs

### Phase 1: Dependency Submission API Integration (Week 1)

- [x] 1. Add Dependency Submission to Syft SBOM Job

  **What to do**:
  - Edit `.github/workflows/security-scan.yml`
  - Add `dependency-snapshot: true` parameter to `anchore/sbom-action@v0` invocation
  - Verify action has required permissions: `contents: write` for Dependency Submission API
  - Test on a PR first before merging to main

  **Must NOT do**:
  - Remove existing SBOM artifact uploads
  - Change SARIF upload behavior
  - Create custom Dependency Submission API client

  **Parallelizable**: NO (foundation for subsequent tasks)

  **References**:

  **Pattern References**:
  - `.github/workflows/security-scan.yml:233-317` - Existing Syft SBOM job structure
  - `anchore/sbom-action` action.yml - Parameters including `dependency-snapshot`

  **API/Type References**:
  - GitHub Dependency Submission API: https://docs.github.com/en/rest/dependency-graph/dependency-submission

  **Test References**:
  - Verify via GitHub UI: Repository → Insights → Dependency graph
  - Check `gh api /repos/{owner}/{repo}/dependency-graph/sbom` returns container deps

  **Acceptance Criteria**:

  **TDD (shellspec not applicable - workflow change):**
  - N/A for workflow YAML changes

  **Manual Execution Verification:**
  - [ ] Trigger security-scan workflow via `workflow_dispatch`
  - [ ] Navigate to Repository → Insights → Dependency graph
  - [ ] Verify container image dependencies appear (e.g., glibc, openssl from Nix)
  - [ ] Screenshot dependency graph showing container packages

  **Evidence Required:**
  - [ ] Screenshot of Dependency Graph with container dependencies
  - [ ] Workflow log showing successful dependency submission

  **Commit**: YES
  - Message: `feat(security): add Dependency Submission API integration for container SBOMs`
  - Files: `.github/workflows/security-scan.yml`
  - Pre-commit: N/A (workflow syntax validated by GitHub)

---

- [x] 2. Verify Dependabot Alerts for Container Dependencies

  **What to do**:
  - Confirm Dependabot alerts appear for known-vulnerable packages in container SBOMs
  - Test with a known CVE (e.g., temporarily pin an old vulnerable package)
  - Document which alert types are now active

  **Must NOT do**:
  - Modify Dependabot configuration (should work automatically)
  - Add false vulnerabilities permanently

  **Parallelizable**: NO (depends on task 1)

  **References**:

  **Pattern References**:
  - `.github/dependabot.yml` (if exists) - Current Dependabot config
  - GitHub Security → Dependabot alerts tab

  **Documentation References**:
  - GitHub Dependabot alerts: https://docs.github.com/en/code-security/dependabot/dependabot-alerts

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Navigate to Repository → Security → Dependabot alerts
  - [ ] Verify alerts include container-related packages (not just package.json/requirements.txt)
  - [ ] If no alerts, temporarily add known-vulnerable package to test detection
  - [ ] Screenshot showing Dependabot alert for container package

  **Evidence Required:**
  - [ ] Screenshot of Dependabot alert referencing container SBOM
  - [ ] Or documentation that no vulnerable packages exist (verify via `gh api`)

  **Commit**: YES (documentation only)
  - Message: `docs(security): document Dependabot alert integration with container SBOMs`
  - Files: `.github/workflows/README.md`
  - Pre-commit: N/A

---

### Phase 2: OCI Attestations & Nix Closure SBOM (Week 2)

- [x] 3. Add cosign SBOM Attestations to Container Builds

  **What to do**:
  - Edit `.github/workflows/build-containers.yml`
  - Add cosign attestation step after image push
  - Attach SBOM (SPDX format) as attestation to each published image
  - Use existing SBOM artifacts from security-scan or generate inline

  **Must NOT do**:
  - Add SLSA provenance (out of scope for Phase 1)
  - Change existing image tagging strategy
  - Require sigstore keyless in environments without OIDC

  **Parallelizable**: YES (with task 4)

  **References**:

  **Pattern References**:
  - `.github/workflows/build-containers.yml:114-171` - Multi-arch manifest creation pattern
  - `sigstore/cosign-installer` action - cosign installation
  - `anchore/sbom-action` - SBOM generation

  **Documentation References**:
  - cosign attest: https://docs.sigstore.dev/cosign/attestation/
  - cosign SBOM attestation: https://docs.sigstore.dev/cosign/sbom/

  **Test References**:
  - `cosign verify-attestation --type spdxjson ghcr.io/mrdavidlaing/laingville/<image>:latest`
  - `cosign tree ghcr.io/mrdavidlaing/laingville/<image>:latest`

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Push to main branch to trigger build-containers workflow
  - [ ] Run: `cosign verify-attestation --type spdxjson ghcr.io/mrdavidlaing/laingville/laingville-devcontainer:latest`
  - [ ] Expected: Verification succeeds, attestation contains SBOM
  - [ ] Run: `cosign tree ghcr.io/mrdavidlaing/laingville/laingville-devcontainer:latest`
  - [ ] Expected: Shows attestation attached to image

  **Evidence Required:**
  - [ ] Command output from `cosign verify-attestation` showing success
  - [ ] Command output from `cosign tree` showing attestation

  **Commit**: YES
  - Message: `feat(security): add cosign SBOM attestations to container images`
  - Files: `.github/workflows/build-containers.yml`
  - Pre-commit: N/A

---

- [x] 4. Create Nix Closure SBOM Generator

  **What to do**:
  - Create `infra/scripts/nix-closure-sbom.sh` script
  - Input: Nix flake output (e.g., `.#laingville-devcontainer`)
  - Output: SPDX 2.3 JSON file
  - Use `nix path-info --json --recursive` to get closure
  - Extract package name and version from store paths
  - Generate minimal SPDX document (packages only, no relationships in Phase 1)

  **Must NOT do**:
  - Add license metadata (Phase 2)
  - Add supplier information (Phase 2)
  - Parse derivation files for more metadata (Phase 2)

  **Parallelizable**: YES (with task 3)

  **References**:

  **Pattern References**:
  - `infra/flake.nix` - Existing Nix flake structure
  - `.github/scripts/docker-load-image-ref.sh` - Existing script pattern

  **API/Type References**:
  - SPDX 2.3 spec: https://spdx.github.io/spdx-spec/v2.3/
  - `nix path-info --json` output format

  **Test References**:
  - Create `spec/nix-closure-sbom_spec.sh` with shellspec tests
  - Test: Parse known store path → extract name/version
  - Test: Generate valid SPDX JSON
  - Test: Validate against SPDX schema (if tool available)

  **Acceptance Criteria**:

  **TDD (shellspec):**
  - [ ] Test file created: `spec/nix-closure-sbom_spec.sh`
  - [ ] Test covers: Store path parsing (e.g., `/nix/store/abc123-python-3.12.0` → name=python, version=3.12.0)
  - [ ] Test covers: SPDX JSON structure generation
  - [ ] `shellspec spec/nix-closure-sbom_spec.sh` → PASS

  **Manual Execution Verification:**
  - [ ] Run: `./infra/scripts/nix-closure-sbom.sh .#laingville-devcontainer > sbom.json`
  - [ ] Validate: `jq '.spdxVersion' sbom.json` returns "SPDX-2.3"
  - [ ] Validate: `jq '.packages | length' sbom.json` returns > 0

  **Evidence Required:**
  - [ ] shellspec test output showing all tests pass
  - [ ] Sample SBOM JSON output (truncated)

  **Commit**: YES
  - Message: `feat(infra): add Nix closure SBOM generator script`
  - Files: `infra/scripts/nix-closure-sbom.sh`, `spec/nix-closure-sbom_spec.sh`
  - Pre-commit: `shellspec spec/nix-closure-sbom_spec.sh`

---

### Phase 3: AI Triage & API Polling (Week 3)

- [x] 5. Implement AI Triage Logic

  **What to do**:
  - Create `bin/security-triage` script (bash or python)
  - Input: List of alerts (JSON from GitHub API)
  - Output: Prioritized list with scores (1-5) and affected images
  - Scoring factors: CVSS score, exploit availability, affected image count, public exposure
  - Deduplicate alerts by CVE ID
  - Use highest severity when scanners disagree

  **Must NOT do**:
  - Build risk scoring or SLA tracking
  - Add machine learning (simple rule-based scoring)
  - Integrate with external threat intelligence

  **Parallelizable**: YES (with task 6)

  **References**:

  **Pattern References**:
  - `.claude/commands/security-fix.md` - Existing security-fix playbook
  - `bin/` directory for CLI tools

  **API/Type References**:
  - GitHub Code Scanning API: https://docs.github.com/en/rest/code-scanning/code-scanning
  - CVSS scoring: https://www.first.org/cvss/calculator/3.1

  **Test References**:
  - Create `spec/security-triage_spec.sh` with shellspec tests
  - Test: CVE deduplication (same CVE from multiple scanners → single entry)
  - Test: Priority scoring (CRITICAL CVE with exploit → score 1)
  - Test: Affected images extraction

  **Acceptance Criteria**:

  **TDD (shellspec):**
  - [ ] Test file created: `spec/security-triage_spec.sh`
  - [ ] Test covers: Deduplication by CVE ID
  - [ ] Test covers: Priority scoring algorithm
  - [ ] Test covers: Affected images extraction
  - [ ] `shellspec spec/security-triage_spec.sh` → PASS

  **Manual Execution Verification:**
  - [ ] Run: `gh api /repos/{owner}/{repo}/code-scanning/alerts?state=open | ./bin/security-triage`
  - [ ] Expected output: JSON with `priority`, `cve_id`, `affected_images` fields
  - [ ] Verify deduplication: Same CVE from Trivy+Grype → single entry

  **Evidence Required:**
  - [ ] shellspec test output
  - [ ] Sample triage output JSON

  **Commit**: YES
  - Message: `feat(security): add AI triage logic for vulnerability prioritization`
  - Files: `bin/security-triage`, `spec/security-triage_spec.sh`
  - Pre-commit: `shellspec spec/security-triage_spec.sh`

---

- [x] 6. Create Security Response Workflow with API Polling

  **What to do**:
  - Create `.github/workflows/security-response.yml`
  - Trigger: `workflow_run` (after security-scan) AND `schedule` (hourly backup)
  - Poll GitHub Security API for new alerts since last run
  - Pass alerts to triage script
  - For HIGH/CRITICAL: Invoke Claude `/security-fix` with context
  - Track last-processed alert ID to avoid duplicates

  **Must NOT do**:
  - Use webhooks (scheduled polling only)
  - Process LOW/MEDIUM alerts automatically (log only)
  - Run more frequently than hourly

  **Parallelizable**: YES (with task 5)

  **References**:

  **Pattern References**:
  - `.github/workflows/claude-security-fix.yml` - Existing Claude invocation pattern
  - `.github/workflows/security-scan.yml` - workflow_run trigger pattern

  **API/Type References**:
  - GitHub Code Scanning Alerts API: https://docs.github.com/en/rest/code-scanning/code-scanning#list-code-scanning-alerts-for-a-repository

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Trigger via `workflow_dispatch`
  - [ ] Check workflow logs: "Polling for new alerts..."
  - [ ] Check workflow logs: "Found N new alerts" (or "No new alerts")
  - [ ] If alerts found: Verify Claude invocation with context
  - [ ] Verify no duplicate processing on re-run

  **Evidence Required:**
  - [ ] Workflow run log showing successful poll
  - [ ] Workflow run log showing triage output

  **Commit**: YES
  - Message: `feat(security): add event-driven security response workflow`
  - Files: `.github/workflows/security-response.yml`
  - Pre-commit: N/A

---

### Phase 4: Evidence Generation & Integration (Week 4)

- [x] 7. Add Before/After SBOM Evidence to PRs

  **What to do**:
  - Enhance `/security-fix` playbook to capture before SBOM
  - After fix: Generate after SBOM
  - Compute diff (packages added/removed/updated)
  - Add diff summary to PR description
  - Attach full SBOMs as PR artifacts

  **Must NOT do**:
  - Generate PDF compliance reports
  - Add audit logging beyond PR artifacts
  - Over-format the diff (simple text table is fine)

  **Parallelizable**: NO (depends on tasks 4 and 5)

  **References**:

  **Pattern References**:
  - `.claude/commands/security-fix.md` - Existing playbook
  - `.github/workflows/claude-security-fix.yml` - PR creation pattern

  **Documentation References**:
  - GitHub PR artifact uploads: https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts

  **Test References**:
  - Create `spec/sbom-diff_spec.sh` for diff logic
  - Test: Identify added packages
  - Test: Identify removed packages (CVE fix)
  - Test: Identify version changes

  **Acceptance Criteria**:

  **TDD (shellspec for diff logic):**
  - [ ] Test file created: `spec/sbom-diff_spec.sh`
  - [ ] Test covers: Package addition detection
  - [ ] Test covers: Package removal detection
  - [ ] Test covers: Version change detection
  - [ ] `shellspec spec/sbom-diff_spec.sh` → PASS

  **Manual Execution Verification:**
  - [ ] Manually trigger security-fix with a known vulnerability
  - [ ] Check PR description includes SBOM diff summary
  - [ ] Check PR artifacts include before.spdx.json and after.spdx.json
  - [ ] Verify diff shows the vulnerable package was removed/updated

  **Evidence Required:**
  - [ ] Screenshot of PR description with SBOM diff
  - [ ] Screenshot of PR artifacts showing SBOM files

  **Commit**: YES
  - Message: `feat(security): add before/after SBOM evidence to security fix PRs`
  - Files: `.claude/commands/security-fix.md`, `bin/sbom-diff`, `spec/sbom-diff_spec.sh`
  - Pre-commit: `shellspec spec/sbom-diff_spec.sh`

---

- [x] 8. Integration Testing & Documentation

  **What to do**:
  - End-to-end test: Introduce known CVE → verify full pipeline
  - Update `.github/workflows/README.md` with new workflows
  - Update `docs/devcontainer.md` SBOM section with implementation status
  - Create runbook for responding to security advisories

  **Must NOT do**:
  - Leave test vulnerabilities in production
  - Write extensive tutorial documentation (keep concise)

  **Parallelizable**: NO (final task)

  **References**:

  **Pattern References**:
  - `.github/workflows/README.md` - Existing workflow documentation
  - `docs/devcontainer.md:496-509` - SBOM Integration section

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Temporarily pin old vulnerable package in `infra/flake.nix`
  - [ ] Trigger security-scan → verify alert appears
  - [ ] Trigger security-response → verify triage runs
  - [ ] Verify PR created with evidence
  - [ ] Merge PR → verify attestation attached to new image
  - [ ] Clean up: Remove test vulnerability

  **Evidence Required:**
  - [ ] Screenshot of full pipeline execution
  - [ ] Updated README.md showing new workflows
  - [ ] Link to example PR with SBOM evidence

  **Commit**: YES
  - Message: `docs(security): complete SBOM & security response documentation`
  - Files: `.github/workflows/README.md`, `docs/devcontainer.md`, `docs/runbooks/security-advisory-response.md`
  - Pre-commit: N/A

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(security): add Dependency Submission API integration` | security-scan.yml | Check Dependency Graph |
| 2 | `docs(security): document Dependabot integration` | README.md | N/A |
| 3 | `feat(security): add cosign SBOM attestations` | build-containers.yml | `cosign verify-attestation` |
| 4 | `feat(infra): add Nix closure SBOM generator` | scripts, spec | `shellspec` |
| 5 | `feat(security): add AI triage logic` | bin, spec | `shellspec` |
| 6 | `feat(security): add security response workflow` | security-response.yml | `workflow_dispatch` |
| 7 | `feat(security): add SBOM evidence to PRs` | playbook, bin, spec | `shellspec` |
| 8 | `docs(security): complete documentation` | docs | Review |

---

## Success Criteria

### Verification Commands
```bash
# Verify Dependency Graph has container deps
gh api /repos/mrdavidlaing/laingville/dependency-graph/sbom | jq '.sbom.packages | length'
# Expected: > 100 (container has many packages)

# Verify cosign attestation
cosign verify-attestation --type spdxjson ghcr.io/mrdavidlaing/laingville/laingville-devcontainer:latest
# Expected: Verification succeeded

# Verify Nix SBOM generation
./infra/scripts/nix-closure-sbom.sh .#laingville-devcontainer | jq '.spdxVersion'
# Expected: "SPDX-2.3"

# Verify triage logic
echo '[{"rule":{"security_severity_level":"critical"}}]' | ./bin/security-triage | jq '.priority'
# Expected: 1

# Run all tests
shellspec
# Expected: All tests pass
```

### Final Checklist
- [ ] Container dependencies visible in GitHub Dependency Graph
- [ ] Dependabot alerts fire for container packages
- [ ] cosign attestations attached to all published images
- [ ] Nix closure SBOM generator produces valid SPDX
- [ ] Security response workflow polls and triages alerts
- [ ] PRs include before/after SBOM diff summaries
- [ ] All shellspec tests pass
- [ ] Documentation updated
- [ ] Claude API costs < $2/week
